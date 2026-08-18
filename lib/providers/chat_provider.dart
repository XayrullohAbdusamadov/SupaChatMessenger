import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/services/sound_service.dart';
import '../core/services/supabase_service.dart';
import '../data/models/chat_conversation.dart';
import '../data/models/chat_message.dart';
import '../data/models/user_profile.dart';
import '../data/models/user_story.dart';

class ChatProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Uuid _uuid = const Uuid();

  List<ChatConversation> _conversations = [];
  final List<UserProfile> _contacts = [];
  List<ChatMessage> _currentMessages = [];
  final List<UserStory> _stories = [];
  List<UserProfile> _recentSearches = [];
  List<UserProfile> _sqlSearchResults = [];
  bool _isSearchingUsers = false;

  final Set<String> _blockedUserIds = {};
  final Set<String> _viewedStoryIds = {};
  ChatConversation? _activeChat;
  ChatMessage? _replyingToMessage;
  ChatMessage? _editingMessage;
  String _searchQuery = '';
  final bool _isLoading = false;
  RealtimeChannel? _realtimeSubscription;
  Timer? _periodicSyncTimer;

  // Audio voice note player
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingVoiceMsgId;
  bool _isVoicePlaying = false;
  double _voiceProgress = 0.0;

  int get totalUnreadCount => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  List<ChatConversation> get conversations {
    if (_searchQuery.isEmpty) {
      return _conversations;
    }
    return _conversations.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // Active contacts derived from actual conversation participants
  List<UserProfile> get contacts {
    final Map<String, UserProfile> userMap = {};
    for (final conv in _conversations) {
      for (final p in conv.participants) {
        userMap[p.id] = p;
      }
    }
    for (final c in _contacts) {
      userMap[c.id] = c;
    }
    final list = userMap.values.toList();
    if (_searchQuery.isEmpty) {
      return list;
    }
    final q = _searchQuery.toLowerCase().replaceAll('@', '');
    return list.where((u) =>
        u.fullName.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q) ||
        (u.role != null && u.role!.toLowerCase().contains(q))).toList();
  }

  List<ChatMessage> get currentMessages => _currentMessages;
  List<UserStory> get stories => _stories;
  List<UserProfile> get recentSearches => _recentSearches;
  List<UserProfile> get sqlSearchResults => _sqlSearchResults;
  bool get isSearchingUsers => _isSearchingUsers;

  Set<String> get blockedUserIds => _blockedUserIds;
  Set<String> get viewedStoryIds => _viewedStoryIds;
  ChatConversation? get activeChat => _activeChat;
  ChatMessage? get replyingToMessage => _replyingToMessage;
  ChatMessage? get editingMessage => _editingMessage;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get currentlyPlayingVoiceMsgId => _currentlyPlayingVoiceMsgId;
  bool get isVoicePlaying => _isVoicePlaying;
  double get voiceProgress => _voiceProgress;

  String? _currentActiveUserId;
  String? _currentActiveUsername;

  ChatProvider() {
    _initAudioPlayer();
  }

  Future<void> loadUserData(String userId, {String? username}) async {
    if (userId.isEmpty) return;
    _currentActiveUserId = userId;

    final prefs = await SharedPreferences.getInstance();
    _currentActiveUsername = username ?? prefs.getString('local_username');

    await _loadSavedConversations(userId);
    await _loadRecentSearches(userId);

    final savedBlocked = prefs.getStringList('blocked_user_ids_$userId') ?? [];
    _blockedUserIds.clear();
    _blockedUserIds.addAll(savedBlocked);

    final savedViewed = prefs.getStringList('viewed_story_ids_$userId') ?? [];
    _viewedStoryIds.clear();
    _viewedStoryIds.addAll(savedViewed);

    initGlobalRealtime(userId);
    _startPeriodicSync();
    notifyListeners();

    // Sync from Supabase in background (non-blocking)
    syncConversationsFromSupabase();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _syncBackgroundMessages();
    });
  }

  Future<void> _syncBackgroundMessages() async {
    if (!_supabaseService.isInitialized || _currentActiveUserId == null) return;
    try {
      if (_activeChat != null) {
        final fetched = await _supabaseService.fetchMessages(_activeChat!.id);
        if (fetched.isNotEmpty && (fetched.length != _currentMessages.length || fetched.last.id != _currentMessages.lastOrNull?.id)) {
          _currentMessages = fetched;
          _updateLastMessage(fetched.last);
          _saveMessagesToLocalCache(_activeChat!.id);
          notifyListeners();
        }
      }

      // Sync recent messages across all chats to auto-discover new chats / incoming messages
      final recentMsgs = await _supabaseService.fetchRecentGlobalMessages();
      for (final msg in recentMsgs.reversed) {
        await processIncomingMessage(msg, isPeriodicSync: true);
      }

      // Also sync conversation list from Supabase to pick up new chats
      await syncConversationsFromSupabase();
    } catch (_) {}
  }

  void clearUserData() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _currentActiveUserId = null;
    _currentActiveUsername = null;
    _conversations = [];
    _currentMessages = [];
    _activeChat = null;
    _replyingToMessage = null;
    _editingMessage = null;
    _recentSearches = [];
    _globalRealtimeSubscription?.unsubscribe();
    _globalRealtimeSubscription = null;
    _realtimeSubscription?.unsubscribe();
    _realtimeSubscription = null;
    _audioPlayer?.stop();
    SoundService.instance.stopVoicePlayback();
    _isVoicePlaying = false;
    _currentlyPlayingVoiceMsgId = null;
    notifyListeners();
  }

  Future<void> _loadSavedConversations(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('saved_user_conversations_$userId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        _conversations = decoded.map((j) => ChatConversation.fromJson(j)).toList();
      } else {
        _conversations = [];
      }
    } catch (e) {
      debugPrint('Error loading saved conversations for user $userId: $e');
      _conversations = [];
    }
  }

  Future<void> _saveConversations() async {
    if (_currentActiveUserId == null || _currentActiveUserId!.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_conversations.map((c) => c.toJson()).toList());
      await prefs.setString('saved_user_conversations_$_currentActiveUserId', encoded);
    } catch (e) {
      debugPrint('Error saving conversations: $e');
    }
  }

  // SEARCH & RECENT SEARCH HISTORY SYSTEM
  Future<void> _loadRecentSearches(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('recent_searches_history_$userId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        _recentSearches = decoded.map((j) => UserProfile.fromJson(j)).toList();
      } else {
        _recentSearches = [];
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
      _recentSearches = [];
    }
  }

  Future<void> saveRecentSearch(UserProfile user) async {
    if (_currentActiveUserId == null || _currentActiveUserId!.isEmpty) return;
    _recentSearches.removeWhere((u) => u.id == user.id || u.username.toLowerCase() == user.username.toLowerCase());
    _recentSearches.insert(0, user);
    if (_recentSearches.length > 25) {
      _recentSearches = _recentSearches.sublist(0, 25);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_recentSearches.map((u) => u.toJson()).toList());
      await prefs.setString('recent_searches_history_$_currentActiveUserId', encoded);
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  Future<void> deleteRecentSearch(String userId) async {
    if (_currentActiveUserId == null || _currentActiveUserId!.isEmpty) return;
    _recentSearches.removeWhere((u) => u.id == userId);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_recentSearches.map((u) => u.toJson()).toList());
      await prefs.setString('recent_searches_history_$_currentActiveUserId', encoded);
    } catch (e) {
      debugPrint('Error deleting recent search: $e');
    }
  }

  Future<void> clearRecentSearches() async {
    if (_currentActiveUserId == null || _currentActiveUserId!.isEmpty) return;
    _recentSearches.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches_history_$_currentActiveUserId');
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> searchUsers(String query, {String? currentUsername}) async {
    final cleanQuery = query.trim().replaceAll('@', '').toLowerCase();
    if (cleanQuery.isEmpty) {
      _sqlSearchResults = [];
      _isSearchingUsers = false;
      notifyListeners();
      return;
    }

    _isSearchingUsers = true;
    notifyListeners();

    final Map<String, UserProfile> matchedMap = {};

    // 1. Check for "saqlangan" search keyword
    if (cleanQuery.contains('saqlan') || cleanQuery.contains('saved') || cleanQuery.contains('eslatma')) {
      matchedMap['saved_messages_self'] = UserProfile(
        id: 'saved_messages_self',
        username: 'saved_messages',
        fullName: 'Saqlangan xabarlar 📌',
        about: 'O\'zingizga xabarlar va eslatmalar joyi',
      );
    }

    // 2. Search Supabase database
    if (_supabaseService.isInitialized) {
      try {
        final supaResults = await _supabaseService.searchUsers(cleanQuery);
        for (final u in supaResults) {
          matchedMap[u.username.toLowerCase()] = u;
        }

        final exactUser = await _supabaseService.fetchProfileByUsername(cleanQuery);
        if (exactUser != null) {
          matchedMap[exactUser.username.toLowerCase()] = exactUser;
        }
      } catch (e) {
        debugPrint('Error querying Supabase in searchUsers: $e');
      }
    }

    // 3. Search locally registered users in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final dbJson = prefs.getString('registered_users_db') ?? '{}';
      final Map<String, dynamic> db = jsonDecode(dbJson);

      for (final username in db.keys) {
        final uLower = username.toLowerCase();
        final name = prefs.getString('user_${uLower}_full_name') ?? prefs.getString('user_${username}_full_name') ?? username;
        final about = prefs.getString('user_${uLower}_about') ?? prefs.getString('user_${username}_about') ?? 'Hey there! I am using SupaChat.';
        final avatar = prefs.getString('user_${uLower}_avatar_url') ?? prefs.getString('user_${username}_avatar_url');

        if (uLower.contains(cleanQuery) || name.toLowerCase().contains(cleanQuery) || about.toLowerCase().contains(cleanQuery)) {
          if (!matchedMap.containsKey(uLower)) {
            matchedMap[uLower] = UserProfile(
              id: 'user-$uLower',
              username: uLower,
              fullName: name,
              about: about,
              avatarUrl: avatar,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching local users database: $e');
    }

    // 4. Search existing conversation participants
    for (final conv in _conversations) {
      for (final p in conv.participants) {
        final uLower = p.username.toLowerCase();
        if (uLower.contains(cleanQuery) || p.fullName.toLowerCase().contains(cleanQuery)) {
          if (!matchedMap.containsKey(uLower)) {
            matchedMap[uLower] = p;
          }
        }
      }
    }

    // 5. Search recent searches history
    for (final r in _recentSearches) {
      final uLower = r.username.toLowerCase();
      if (uLower.contains(cleanQuery) || r.fullName.toLowerCase().contains(cleanQuery)) {
        if (!matchedMap.containsKey(uLower)) {
          matchedMap[uLower] = r;
        }
      }
    }

    // Convert map to results list
    List<UserProfile> results = matchedMap.values.toList();

    // Filter out current user's own account from username search results
    if (currentUsername != null && currentUsername.isNotEmpty) {
      results.removeWhere((r) => r.username.toLowerCase() == currentUsername.toLowerCase() && r.id != 'saved_messages_self');
    }

    _sqlSearchResults = results;
    _isSearchingUsers = false;
    notifyListeners();
  }

  // SAVED MESSAGES (Self-messaging / Note to Self)
  ChatConversation startSavedMessagesChat(UserProfile currentUser) {
    final savedId = 'saved_messages_${currentUser.id}';
    final existingIdx = _conversations.indexWhere((c) => c.id == savedId || c.id == 'saved_messages_self');

    if (existingIdx != -1) {
      return _conversations[existingIdx];
    }

    final newChat = ChatConversation(
      id: savedId,
      isGroup: false,
      name: 'Saqlangan xabarlar 📌',
      avatarUrl: currentUser.avatarUrl,
      participants: [currentUser],
      lastMessageText: 'Eslatmalar va fayllar joyi',
      lastMessageType: MessageType.text,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    _conversations.insert(0, newChat);
    _saveConversations();
    notifyListeners();
    return newChat;
  }

  // BLOCKING SYSTEM
  bool isUserBlocked(String userId) => _blockedUserIds.contains(userId);

  Future<void> toggleBlockUser(String userId) async {
    if (_blockedUserIds.contains(userId)) {
      _blockedUserIds.remove(userId);
    } else {
      _blockedUserIds.add(userId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
    notifyListeners();
  }

  // STORIES SYSTEM
  void addStory(UserStory story) {
    _stories.insert(0, story);
    notifyListeners();
  }

  void deleteStory(String storyId) {
    _stories.removeWhere((s) => s.id == storyId);
    notifyListeners();
  }

  List<UserStory> getStoriesForUser(String userId) {
    return _stories.where((s) => s.userId == userId).toList();
  }

  bool isStoryViewed(String storyId) => _viewedStoryIds.contains(storyId);

  Future<void> markStoryAsViewed(String storyId) async {
    if (!_viewedStoryIds.contains(storyId)) {
      _viewedStoryIds.add(storyId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('viewed_story_ids', _viewedStoryIds.toList());
      notifyListeners();
    }
  }

  // REPLY TO STORY INTO DIRECT CHAT
  Future<void> replyToStory({
    required UserStory story,
    required String replyText,
    required String currentUserId,
  }) async {
    final contact = UserProfile(
      id: story.userId,
      username: story.userName.toLowerCase().replaceAll(' ', '_'),
      fullName: story.userName,
      avatarUrl: story.userAvatar,
    );

    final chat = startDirectChat(contact);
    openChat(chat, currentUserId);

    await sendMessage(
      senderId: currentUserId,
      content: '📸 Storyga javob: $replyText',
      type: MessageType.text,
    );
  }

  // AUDIO PLAYER
  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();

    _audioPlayer!.onPositionChanged.listen((pos) {
      if (_currentlyPlayingVoiceMsgId != null) {
        final msg = _currentMessages.firstWhere(
          (m) => m.id == _currentlyPlayingVoiceMsgId,
          orElse: () => _currentMessages.first,
        );
        final durSeconds = msg.voiceDuration ?? 10;
        if (durSeconds > 0) {
          _voiceProgress = (pos.inMilliseconds / (durSeconds * 1000)).clamp(0.0, 1.0);
          notifyListeners();
        }
      }
    });

    _audioPlayer!.onPlayerComplete.listen((_) {
      _isVoicePlaying = false;
      _voiceProgress = 0.0;
      _currentlyPlayingVoiceMsgId = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void setSearchQuery(String query, {String? currentUsername}) {
    _searchQuery = query;
    searchUsers(query, currentUsername: currentUsername);
    notifyListeners();
  }

  void setReplyingTo(ChatMessage? message) {
    _replyingToMessage = message;
    _editingMessage = null;
    notifyListeners();
  }

  void setEditingMessage(ChatMessage? message) {
    _editingMessage = message;
    _replyingToMessage = null;
    notifyListeners();
  }

  void cancelReplyOrEdit() {
    _replyingToMessage = null;
    _editingMessage = null;
    notifyListeners();
  }

  // Open Chat Screen
  void openChat(ChatConversation conversation, String currentUserId) async {
    _activeChat = conversation;
    _replyingToMessage = null;
    _editingMessage = null;

    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1 && _conversations[index].unreadCount > 0) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
      _saveConversations();
    }

    await _loadMessagesFromLocalCache(conversation.id);
    notifyListeners();

    if (_supabaseService.isInitialized) {
      _supabaseService.createOrEnsureChat(
        chatId: conversation.id,
        isGroup: conversation.isGroup,
        groupName: conversation.name,
        groupAvatar: conversation.avatarUrl,
        createdBy: currentUserId,
        participantIds: [currentUserId, ...conversation.participants.map((p) => p.id)],
      );

      final fetched = await _supabaseService.fetchMessages(conversation.id);
      if (fetched.isNotEmpty) {
        _currentMessages = fetched;
        await _saveMessagesToLocalCache(conversation.id);
        notifyListeners();
      }
      _subscribeToRealtime(conversation.id);
    }
  }

  Future<void> _loadMessagesFromLocalCache(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = chatId.startsWith('saved_messages')
          ? 'chat_messages_saved_messages_${_currentActiveUserId ?? "self"}'
          : 'chat_messages_$chatId';
      final jsonStr = prefs.getString(cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        _currentMessages = decoded.map((j) => ChatMessage.fromJson(j)).toList();
      } else {
        _currentMessages = [];
      }
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
      _currentMessages = [];
    }
  }

  Future<void> _saveMessagesToLocalCache(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = chatId.startsWith('saved_messages')
          ? 'chat_messages_saved_messages_${_currentActiveUserId ?? "self"}'
          : 'chat_messages_$chatId';
      final encoded = jsonEncode(_currentMessages.map((m) => m.toJson()).toList());
      await prefs.setString(cacheKey, encoded);
    } catch (e) {
      debugPrint('Error saving cached messages: $e');
    }
  }

  Function(ChatMessage message, ChatConversation conversation)? onIncomingNotification;

  void triggerNotification(ChatMessage message, ChatConversation conversation) {
    SoundService.instance.playTiqSound();

    if (_activeChat == null || _activeChat!.id != message.chatId) {
      onIncomingNotification?.call(message, conversation);
    }
  }

  String? get currentActiveUserId => _currentActiveUserId;

  RealtimeChannel? _globalRealtimeSubscription;
  String? _currentListeningUserId;

  Future<void> processIncomingMessage(ChatMessage newMsg, {bool isPeriodicSync = false}) async {
    final currentUserId = _currentActiveUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    // If message was sent by ourselves, ignore (check both userId and username)
    final myUsername = _currentActiveUsername?.trim().toLowerCase() ?? '';
    final senderClean = newMsg.senderId.replaceAll('user-', '').trim().toLowerCase();
    if (newMsg.senderId == currentUserId || (myUsername.isNotEmpty && senderClean == myUsername)) {
      return;
    }

    // Fetch or resolve sender's profile
    UserProfile? senderProfile;
    if (_supabaseService.isInitialized) {
      senderProfile = await _supabaseService.fetchProfile(newMsg.senderId);
    }
    final senderUsername = senderProfile?.username ?? senderClean;
    senderProfile ??= UserProfile(
      id: newMsg.senderId,
      username: senderUsername,
      fullName: senderUsername,
    );

    // Strictly verify that this message is meant for currentUserId
    bool isMyChat = false;

    // 1. Check if message is in an existing known conversation (any type)
    final existingConvIdx = _conversations.indexWhere((c) => c.id == newMsg.chatId);
    if (existingConvIdx != -1) {
      isMyChat = true;
    }

    // 2. If username is available, compute expected direct chat ID from usernames
    if (!isMyChat && myUsername.isNotEmpty) {
      final senderUser = senderUsername.trim().toLowerCase();
      final sorted = [myUsername, senderUser]..sort();
      final expectedDirectChatId = _uuid.v5(Namespace.url.value, 'supachat:direct:${sorted.join(':')}');
      if (newMsg.chatId == expectedDirectChatId) {
        isMyChat = true;
      }
    }

    // 3. Fallback: check Supabase chat_participants table
    if (!isMyChat && _supabaseService.isInitialized) {
      final isParticipant = await _supabaseService.isUserParticipant(newMsg.chatId, currentUserId);
      if (isParticipant) {
        isMyChat = true;
      }
      // Also try by username-based user ID
      if (!isParticipant && myUsername.isNotEmpty) {
        final usernameBasedId = 'user-$myUsername';
        if (usernameBasedId != currentUserId) {
          final isParticipant2 = await _supabaseService.isUserParticipant(newMsg.chatId, usernameBasedId);
          if (isParticipant2) isMyChat = true;
        }
      }
    }

    // If this message does not belong to the current user, ignore completely!
    if (!isMyChat) return;

    final convIdx = _conversations.indexWhere((c) => c.id == newMsg.chatId);

    // Check if we already have this message cached
    final cached = await _loadCachedMessagesForChat(newMsg.chatId);
    final alreadyExists = cached.any((m) => m.id == newMsg.id) || _currentMessages.any((m) => m.id == newMsg.id);

    // If this chat is currently open and active
    if (_activeChat != null && _activeChat!.id == newMsg.chatId) {
      if (!_currentMessages.any((m) => m.id == newMsg.id)) {
        _currentMessages.add(newMsg);
        _updateLastMessage(newMsg);
        _saveMessagesToLocalCache(newMsg.chatId);
        if (!alreadyExists) {
          SoundService.instance.playTiqSound();
        }
        notifyListeners();
      }
      return;
    }

    if (alreadyExists && convIdx != -1) {
      return;
    }

    // Chat is NOT currently open: update or add conversation in list and show floating notification banner
    ChatConversation? conv;

    if (convIdx != -1) {
      final existing = _conversations[convIdx];
      final updatedParticipants = List<UserProfile>.from(existing.participants);
      final s = senderProfile;
      if (!updatedParticipants.any((p) => p.id == s.id || p.username.toLowerCase() == s.username.toLowerCase())) {
        updatedParticipants.add(s);
      }

      final updated = existing.copyWith(
        name: senderProfile.fullName.isNotEmpty ? senderProfile.fullName : existing.name,
        avatarUrl: senderProfile.avatarUrl ?? existing.avatarUrl,
        participants: updatedParticipants,
        lastMessageText: newMsg.content.isNotEmpty ? newMsg.content : 'Media xabar',
        lastMessageType: newMsg.messageType,
        lastMessageAt: newMsg.createdAt,
        unreadCount: alreadyExists ? existing.unreadCount : (existing.unreadCount + 1),
      );
      _conversations.removeAt(convIdx);
      _conversations.insert(0, updated);
      conv = updated;
    } else {
      // NEW CONVERSATION FROM SENDER -> ADD ACCOUNT TO CHATS LIST
      final newConv = ChatConversation(
        id: newMsg.chatId,
        isGroup: false,
        name: senderProfile.fullName.isNotEmpty ? senderProfile.fullName : senderProfile.username,
        avatarUrl: senderProfile.avatarUrl,
        participants: [senderProfile],
        lastMessageText: newMsg.content.isNotEmpty ? newMsg.content : 'Media xabar',
        lastMessageType: newMsg.messageType,
        lastMessageAt: newMsg.createdAt,
        unreadCount: 1,
      );
      _conversations.insert(0, newConv);
      conv = newConv;
    }

    // Save updated messages and conversation list to cache
    await _saveConversations();
    await _appendMessageToLocalCache(newMsg.chatId, newMsg);
    notifyListeners();

    // Trigger in-app notification banner and sound
    if (!alreadyExists) {
      triggerNotification(newMsg, conv);
    }
  }

  void initGlobalRealtime(String currentUserId) {
    if (_currentListeningUserId == currentUserId && _globalRealtimeSubscription != null) {
      return;
    }
    _currentListeningUserId = currentUserId;
    _globalRealtimeSubscription?.unsubscribe();
    _globalRealtimeSubscription = _supabaseService.subscribeToAllMessages(
      onMessageReceived: (newMsg) async {
        await processIncomingMessage(newMsg);
      },
      onMessageUpdated: (updatedMsg) async {
        // Update reaction or edited message in active messages list
        final idx = _currentMessages.indexWhere((m) => m.id == updatedMsg.id);
        if (idx != -1) {
          _currentMessages[idx] = updatedMsg;
          if (_activeChat != null) {
            _saveMessagesToLocalCache(_activeChat!.id);
          }
          notifyListeners();
        }
      },
    );
  }

  Future<List<ChatMessage>> _loadCachedMessagesForChat(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('chat_messages_$chatId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((j) => ChatMessage.fromJson(j)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _appendMessageToLocalCache(String chatId, ChatMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('chat_messages_$chatId');
      List<ChatMessage> list = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        list = decoded.map((j) => ChatMessage.fromJson(j)).toList();
      }
      if (!list.any((m) => m.id == message.id)) {
        list.add(message);
        final encoded = jsonEncode(list.map((m) => m.toJson()).toList());
        await prefs.setString('chat_messages_$chatId', encoded);
      }
    } catch (e) {
      debugPrint('Error appending message to local cache: $e');
    }
  }

  void _subscribeToRealtime(String chatId) {
    _realtimeSubscription?.unsubscribe();
    _realtimeSubscription = _supabaseService.subscribeToChatMessages(
      chatId,
      onMessageReceived: (newMsg) {
        if (!_currentMessages.any((m) => m.id == newMsg.id)) {
          _currentMessages.add(newMsg);
          _updateLastMessage(newMsg);
          _saveMessagesToLocalCache(newMsg.chatId);
          notifyListeners();

          final conv = _conversations.firstWhere(
            (c) => c.id == newMsg.chatId,
            orElse: () => _activeChat ?? ChatConversation(
              id: newMsg.chatId,
              name: 'SupaChat User',
              participants: [],
            ),
          );
          triggerNotification(newMsg, conv);
        }
      },
    );
  }

  void closeChat() {
    _realtimeSubscription?.unsubscribe();
    _realtimeSubscription = null;
    _activeChat = null;
    _currentMessages = [];
    _replyingToMessage = null;
    _editingMessage = null;
    _audioPlayer?.stop();
    _isVoicePlaying = false;
    _currentlyPlayingVoiceMsgId = null;
    notifyListeners();
  }

  // CLEAR CHAT HISTORY
  void clearChatHistory(String chatId) {
    _currentMessages = [];
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(
        lastMessageText: 'Tarix tozalandi',
        lastMessageType: MessageType.text,
        lastMessageAt: DateTime.now(),
        unreadCount: 0,
      );
      _saveConversations();
    }
    _saveMessagesToLocalCache(chatId);
    notifyListeners();
  }

  // DELETE MESSAGE
  void deleteMessage(String messageId) {
    _currentMessages.removeWhere((m) => m.id == messageId);
    if (_activeChat != null) {
      _saveMessagesToLocalCache(_activeChat!.id);
      if (_currentMessages.isNotEmpty) {
        _updateLastMessage(_currentMessages.last);
      }
    }
    notifyListeners();
  }

  // TOGGLE REACTION ON MESSAGE (Telegram-style per-user reaction)
  void toggleReaction({
    required String messageId,
    required String emoji,
    String? userId,
  }) {
    final idx = _currentMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final msg = _currentMessages[idx];
      final currentList = List<String>.from(msg.reactions);
      final uid = userId ?? _currentActiveUserId ?? '';
      final userReactionToken = uid.isNotEmpty ? '$emoji:$uid' : emoji;

      if (currentList.contains(userReactionToken) || currentList.contains(emoji)) {
        currentList.remove(userReactionToken);
        currentList.remove(emoji);
      } else {
        // Remove other reactions by this user if any (Telegram allows 1 reaction per user)
        if (uid.isNotEmpty) {
          currentList.removeWhere((r) => r.endsWith(':$uid'));
        }
        currentList.add(userReactionToken);
      }

      final updatedMsg = msg.copyWith(reactions: currentList);
      _currentMessages[idx] = updatedMsg;

      if (_activeChat != null) {
        _saveMessagesToLocalCache(_activeChat!.id);
      }
      notifyListeners();

      if (_supabaseService.isInitialized) {
        _supabaseService.updateMessageReactions(messageId, currentList);
      }
    }
  }

  // DELETE CHAT CONVERSATION COMPLETELY WITH CLEANUP
  void deleteChatCompletely(String chatId) {
    final convIdx = _conversations.indexWhere((c) => c.id == chatId);
    if (convIdx != -1) {
      _conversations.removeAt(convIdx);
      _saveConversations();
    }
    if (_activeChat?.id == chatId) {
      closeChat();
    }
    notifyListeners();
  }

  // GROUP PERMISSIONS & ADMIN MANAGEMENT
  void toggleGroupAdmin(String chatId, String userId) {
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      final currentAdmins = List<String>.from(_conversations[idx].adminIds);
      if (currentAdmins.contains(userId)) {
        currentAdmins.remove(userId);
      } else {
        currentAdmins.add(userId);
      }
      _conversations[idx] = _conversations[idx].copyWith(adminIds: currentAdmins);
      if (_activeChat?.id == chatId) {
        _activeChat = _conversations[idx];
      }
      _saveConversations();
      notifyListeners();
    }
  }

  void toggleGroupBlockMember(String chatId, String userId) {
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      final currentBlocked = List<String>.from(_conversations[idx].blockedMemberIds);
      if (currentBlocked.contains(userId)) {
        currentBlocked.remove(userId);
      } else {
        currentBlocked.add(userId);
      }
      _conversations[idx] = _conversations[idx].copyWith(blockedMemberIds: currentBlocked);
      if (_activeChat?.id == chatId) {
        _activeChat = _conversations[idx];
      }
      _saveConversations();
      notifyListeners();
    }
  }

  void removeGroupMember(String chatId, String userId) {
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      final updatedParticipants = _conversations[idx].participants.where((p) => p.id != userId).toList();
      final updatedAdmins = _conversations[idx].adminIds.where((id) => id != userId).toList();
      _conversations[idx] = _conversations[idx].copyWith(
        participants: updatedParticipants,
        adminIds: updatedAdmins,
      );
      if (_activeChat?.id == chatId) {
        _activeChat = _conversations[idx];
      }
      _saveConversations();
      notifyListeners();
    }
  }

  Future<void> syncBackground() => _syncBackgroundMessages();

  // SEND MESSAGE
  Future<void> sendMessage({
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    int? mediaSize,
    String? fileName,
    int? voiceDuration,
  }) async {
    if (_activeChat == null || (content.trim().isEmpty && mediaUrl == null && type != MessageType.voice)) {
      return;
    }

    SoundService.instance.playTiqSound();

    if (_editingMessage != null) {
      final editIdx = _currentMessages.indexWhere((m) => m.id == _editingMessage!.id);
      if (editIdx != -1) {
        _currentMessages[editIdx] = _currentMessages[editIdx].copyWith(
          content: content.trim(),
          isEdited: true,
        );
      }
      _editingMessage = null;
      if (_activeChat != null) {
        _saveMessagesToLocalCache(_activeChat!.id);
      }
      notifyListeners();
      return;
    }

    final newMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: _activeChat!.id,
      senderId: senderId,
      replyToId: _replyingToMessage?.id,
      replyToMessage: _replyingToMessage,
      messageType: type,
      content: content.trim(),
      mediaUrl: mediaUrl,
      mediaSize: mediaSize,
      fileName: fileName,
      voiceDuration: voiceDuration,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    _currentMessages.add(newMsg);

    final convIdx = _conversations.indexWhere((c) => c.id == _activeChat!.id);
    if (convIdx == -1) {
      _conversations.insert(0, _activeChat!);
    }

    _updateLastMessage(newMsg);
    _replyingToMessage = null;

    if (_activeChat != null) {
      _saveMessagesToLocalCache(_activeChat!.id);
    }
    await _saveConversations();
    notifyListeners();

    if (_supabaseService.isInitialized) {
      // Ensure chat and all participants are registered BEFORE sending the message
      // This is critical: the trigger only adds the sender, but the receiver must also be in chat_participants
      // so they can discover the conversation via syncConversationsFromSupabase
      if (_activeChat != null && !_activeChat!.id.startsWith('saved_messages')) {
        final participantIds = _activeChat!.participants.map((p) => p.id).toList();
        if (!participantIds.contains(senderId)) participantIds.add(senderId);
        await _supabaseService.createOrEnsureChat(
          chatId: _activeChat!.id,
          isGroup: _activeChat!.isGroup,
          groupName: _activeChat!.isGroup ? _activeChat!.name : null,
          groupAvatar: _activeChat!.isGroup ? _activeChat!.avatarUrl : null,
          createdBy: senderId,
          participantIds: participantIds,
        );
      }

      final sent = await _supabaseService.sendMessage(newMsg);
      final idx = _currentMessages.indexWhere((m) => m.id == newMsg.id);
      if (idx != -1) {
        _currentMessages[idx] = _currentMessages[idx].copyWith(
          status: sent != null ? MessageStatus.sent : MessageStatus.delivered,
        );
        if (_activeChat != null) {
          _saveMessagesToLocalCache(_activeChat!.id);
        }
        notifyListeners();
      }
    }
  }

  void _updateLastMessage(ChatMessage msg) {
    if (_activeChat == null) return;
    final idx = _conversations.indexWhere((c) => c.id == _activeChat!.id);
    if (idx != -1) {
      String preview = msg.content;
      if (msg.messageType == MessageType.image) preview = '📷 Rasm';
      if (msg.messageType == MessageType.video) preview = '🎥 Video';
      if (msg.messageType == MessageType.voice) preview = '🎤 Ovoz (${msg.voiceDuration ?? 10}s)';
      if (msg.messageType == MessageType.doc) preview = '📄 ${msg.fileName ?? "Hujjat"}';

      _conversations[idx] = _conversations[idx].copyWith(
        lastMessageText: preview,
        lastMessageType: msg.messageType,
        lastMessageAt: msg.createdAt,
      );
      _saveConversations();
    }
  }

  // Voice note play/pause toggle with AudioPlayer
  Future<void> togglePlayVoice(String msgId, int durationSeconds) async {
    if (_currentlyPlayingVoiceMsgId == msgId && _isVoicePlaying) {
      await _audioPlayer?.pause();
      await SoundService.instance.stopVoicePlayback();
      _isVoicePlaying = false;
      notifyListeners();
      return;
    }

    if (_currentlyPlayingVoiceMsgId == msgId && !_isVoicePlaying) {
      await _audioPlayer?.resume();
      _isVoicePlaying = true;
      notifyListeners();
      return;
    }

    await _audioPlayer?.stop();
    await SoundService.instance.stopVoicePlayback();
    _currentlyPlayingVoiceMsgId = msgId;
    _isVoicePlaying = true;
    _voiceProgress = 0.0;
    notifyListeners();

    final msg = _currentMessages.firstWhere(
      (m) => m.id == msgId,
      orElse: () => ChatMessage(
        id: msgId,
        chatId: '',
        senderId: '',
        content: '',
        createdAt: DateTime.now(),
      ),
    );

    try {
      if (msg.mediaUrl != null && msg.mediaUrl!.startsWith('http')) {
        await _audioPlayer!.play(UrlSource(msg.mediaUrl!));
      } else {
        await SoundService.instance.playVoiceTone(durationSeconds);
        _simulateVoiceProgress(msgId, durationSeconds);
      }
    } catch (e) {
      await SoundService.instance.playVoiceTone(durationSeconds);
      _simulateVoiceProgress(msgId, durationSeconds);
    }
  }

  void _simulateVoiceProgress(String msgId, int durationSeconds) {
    const stepDurationMs = 100;
    final totalSteps = (durationSeconds * 1000) ~/ stepDurationMs;
    int currentStep = 0;

    void tick() {
      if (!_isVoicePlaying || _currentlyPlayingVoiceMsgId != msgId) return;

      currentStep++;
      _voiceProgress = currentStep / totalSteps;
      if (_voiceProgress >= 1.0) {
        _isVoicePlaying = false;
        _voiceProgress = 0.0;
        _currentlyPlayingVoiceMsgId = null;
      } else {
        Future.delayed(const Duration(milliseconds: stepDurationMs), tick);
      }
      notifyListeners();
    }

    Future.delayed(const Duration(milliseconds: stepDurationMs), tick);
  }

  // Create new group with creator as owner
  void createNewGroup({
    required String groupName,
    required List<UserProfile> members,
    String? avatarUrl,
    required String creatorId,
  }) {
    final groupId = _uuid.v4();
    final newGroup = ChatConversation(
      id: groupId,
      isGroup: true,
      name: groupName,
      avatarUrl: avatarUrl,
      createdBy: creatorId,
      adminIds: [creatorId],
      participants: members,
      lastMessageText: 'Guruh yaratildi 🎉',
      lastMessageType: MessageType.text,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    _conversations.insert(0, newGroup);
    _saveConversations();
    notifyListeners();

    if (_supabaseService.isInitialized) {
      _supabaseService.createOrEnsureChat(
        chatId: groupId,
        isGroup: true,
        groupName: groupName,
        groupAvatar: avatarUrl,
        createdBy: creatorId,
        participantIds: [creatorId, ...members.map((m) => m.id)],
      );
    }
  }

  // Start chat with a contact (Direct 1-on-1 chat)
  // Always uses username-based deterministic UUID for chat ID consistency
  ChatConversation startDirectChat(UserProfile contact, {UserProfile? currentUser}) {
    final existingIdx = _conversations.indexWhere(
      (c) => !c.isGroup && c.participants.any((p) => p.id == contact.id || p.username.toLowerCase() == contact.username.toLowerCase()),
    );

    // Determine my username: prefer currentUser.username, then _currentActiveUsername, never userId
    final myUsername = (currentUser?.username.isNotEmpty == true
            ? currentUser!.username
            : _currentActiveUsername ?? '')
        .trim()
        .toLowerCase();
    final targetUsername = contact.username.trim().toLowerCase();

    // Compute deterministic chat ID based on usernames (sorted alphabetically)
    final sortedUsernames = [myUsername, targetUsername]..sort();
    final chatId = myUsername.isNotEmpty
        ? _uuid.v5(Namespace.url.value, 'supachat:direct:${sortedUsernames.join(':')}')
        : _uuid.v4(); // fallback, should never happen

    // If existing conv found by participants, return it (already matched above)
    if (existingIdx != -1) {
      // But also check if the stored chat ID matches expected - if not, update it
      final existing = _conversations[existingIdx];
      if (existing.id == chatId) return existing;
      // IDs differ - prefer the deterministic one (open the correct chat)
    }

    // Check by computed chatId as well
    final byIdIdx = _conversations.indexWhere((c) => c.id == chatId);
    if (byIdIdx != -1) return _conversations[byIdIdx];

    final newChat = ChatConversation(
      id: chatId,
      isGroup: false,
      name: contact.fullName,
      avatarUrl: contact.avatarUrl,
      participants: currentUser != null ? [currentUser, contact] : [contact],
      lastMessageText: contact.about,
      lastMessageType: MessageType.text,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    _conversations.insert(0, newChat);
    _saveConversations();
    notifyListeners();

    if (_supabaseService.isInitialized && currentUser != null) {
      _supabaseService.createOrEnsureChat(
        chatId: chatId,
        isGroup: false,
        createdBy: currentUser.id,
        participantIds: [currentUser.id, contact.id],
      );
    }

    return newChat;
  }

  /// Fetch conversations from Supabase for the current user and merge into local list
  Future<void> syncConversationsFromSupabase() async {
    if (!_supabaseService.isInitialized || _currentActiveUserId == null) return;
    try {
      final remote = await _supabaseService.fetchUserConversations(_currentActiveUserId!);
      for (final conv in remote) {
        final localIdx = _conversations.indexWhere((c) => c.id == conv.id);
        if (localIdx == -1) {
          // New conversation not yet in local list — add it
          _conversations.insert(0, conv);
        }
      }
      if (remote.isNotEmpty) {
        _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        await _saveConversations();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing conversations from Supabase: $e');
    }
  }
}
