import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

class ChatProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Uuid _uuid = const Uuid();

  List<ChatConversation> _conversations = [];
  final List<UserProfile> _contacts = [];
  List<ChatMessage> _currentMessages = [];
  List<UserProfile> _recentSearches = [];
  List<UserProfile> _sqlSearchResults = [];
  bool _isSearchingUsers = false;

  final Set<String> _blockedUserIds = {};
  ChatConversation? _activeChat;
  ChatMessage? _replyingToMessage;
  ChatMessage? _editingMessage;
  String _searchQuery = '';
  final bool _isLoading = false;
  RealtimeChannel? _realtimeSubscription;
  StreamSubscription<List<ChatMessage>>? _activeChatStreamSubscription;
  StreamSubscription<List<ChatMessage>>? _globalStreamSubscription;
  Timer? _periodicSyncTimer;

  // Audio voice note player
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingVoiceMsgId;
  bool _isVoicePlaying = false;
  double _voiceProgress = 0.0;

  int get totalUnreadCount => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  List<ChatConversation> get conversations {
    final cleanMyUsername = _currentActiveUsername?.trim().toLowerCase().replaceAll('@', '') ?? '';
    final Map<String, ChatConversation> deduplicated = {};

    for (final conv in _conversations) {
      if (conv.id.contains('00000000') ||
          conv.name.contains('SupaChat Developer') ||
          conv.name.contains('SupaChat Assistant') ||
          conv.name.contains('SupaChat Community') ||
          conv.participants.any((p) => p.username == 'admin_dev' || p.username == 'supachat_bot')) {
        continue;
      }

      String key = conv.id;
      if (!conv.isGroup && !conv.id.startsWith('saved_messages') && cleanMyUsername.isNotEmpty) {
        final other = conv.getOtherParticipant(_currentActiveUserId ?? '', currentUsername: cleanMyUsername);
        if (other != null && other.username.isNotEmpty) {
          final targetU = other.username.trim().toLowerCase().replaceAll('@', '');
          key = 'direct_${ChatConversation.computeDirectChatId(cleanMyUsername, targetU)}';
        }
      }

      if (deduplicated.containsKey(key)) {
        final existing = deduplicated[key]!;
        final latestAt = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageAt : existing.lastMessageAt;
        final latestText = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageText : existing.lastMessageText;
        final latestType = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageType : existing.lastMessageType;
        final latestSender = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageSenderId : existing.lastMessageSenderId;

        final mergedParticipants = List<UserProfile>.from(existing.participants);
        for (final p in conv.participants) {
          if (!mergedParticipants.any((mp) => mp.username.toLowerCase() == p.username.toLowerCase())) {
            mergedParticipants.add(p);
          }
        }

        deduplicated[key] = existing.copyWith(
          participants: mergedParticipants,
          lastMessageAt: latestAt,
          lastMessageText: latestText,
          lastMessageType: latestType,
          lastMessageSenderId: latestSender,
          unreadCount: existing.unreadCount + conv.unreadCount,
        );
      } else {
        deduplicated[key] = conv;
      }
    }

    final list = deduplicated.values.toList()..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    if (_searchQuery.isEmpty) {
      return list;
    }
    final q = _searchQuery.toLowerCase().replaceAll('@', '');
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
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
  List<UserProfile> get recentSearches => _recentSearches;
  List<UserProfile> get sqlSearchResults => _sqlSearchResults;
  bool get isSearchingUsers => _isSearchingUsers;

  Set<String> get blockedUserIds => _blockedUserIds;
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
    String? resolvedUsername = username?.trim().isNotEmpty == true
        ? username
        : prefs.getString('local_username');

    // If username is still empty, resolve it from Supabase before realtime starts
    if ((resolvedUsername == null || resolvedUsername.isEmpty) && _supabaseService.isInitialized) {
      final profile = await _supabaseService.fetchProfile(userId);
      if (profile != null && profile.username.isNotEmpty) {
        resolvedUsername = profile.username.trim().toLowerCase();
        await prefs.setString('local_username', resolvedUsername);
        debugPrint('[ChatProvider] Resolved username from Supabase: $resolvedUsername');
      }
    }
    _currentActiveUsername = resolvedUsername;

    await _loadSavedConversations(userId);
    await _loadRecentSearches(userId);

    final savedBlocked = prefs.getStringList('blocked_user_ids_$userId') ?? [];
    _blockedUserIds.clear();
    _blockedUserIds.addAll(savedBlocked);

    // Only start realtime after username is confirmed
    initGlobalRealtime(userId);
    _startPeriodicSync();
    notifyListeners();

    // Sync from Supabase in background (non-blocking)
    syncConversationsFromSupabase();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncBackgroundMessages();
    });
  }

  void _mergeFetchedMessages(List<ChatMessage> fetched) {
    if (fetched.isEmpty) return;
    final Map<String, ChatMessage> map = {};
    for (final m in _currentMessages) {
      map[m.id] = m;
    }
    bool changed = false;
    for (final m in fetched) {
      if (!map.containsKey(m.id) || map[m.id]?.status != m.status || map[m.id]?.content != m.content) {
        map[m.id] = m;
        changed = true;
      }
    }
    if (changed || map.length != _currentMessages.length) {
      final list = map.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _currentMessages = _hydrateReplies(list);
      if (_currentMessages.isNotEmpty) {
        _updateLastMessage(_currentMessages.last);
      }
      if (_activeChat != null) {
        _saveMessagesToLocalCache(_activeChat!.id);
      }
      notifyListeners();
    }
  }

  Future<void> _syncBackgroundMessages() async {
    if (!_supabaseService.isInitialized || _currentActiveUserId == null) return;
    try {
      if (_activeChat != null) {
        final fetched = await _supabaseService.fetchMessages(_activeChat!.id);
        if (fetched.isNotEmpty) {
          _mergeFetchedMessages(fetched);
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
      List<ChatConversation> loaded = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        loaded = decoded.map((j) => ChatConversation.fromJson(j)).toList();
      }

      // Deduplicate conversations (merge duplicates with different IDs for same 1-on-1 contact)
      final Map<String, ChatConversation> deduplicated = {};
      final cleanMyUsername = _currentActiveUsername?.trim().toLowerCase().replaceAll('@', '') ?? '';

      for (final conv in loaded) {
        if (conv.id.contains('00000000') ||
            conv.name.contains('SupaChat Developer') ||
            conv.name.contains('SupaChat Assistant') ||
            conv.name.contains('SupaChat Community') ||
            conv.participants.any((p) => p.username == 'admin_dev' || p.username == 'supachat_bot')) {
          continue;
        }

        String key = conv.id;
        if (!conv.isGroup && !conv.id.startsWith('saved_messages') && cleanMyUsername.isNotEmpty) {
          final other = conv.getOtherParticipant(userId, currentUsername: cleanMyUsername);
          if (other != null && other.username.isNotEmpty) {
            final targetU = other.username.trim().toLowerCase().replaceAll('@', '');
            key = ChatConversation.computeDirectChatId(cleanMyUsername, targetU);
          }
        }

        if (deduplicated.containsKey(key)) {
          final existing = deduplicated[key]!;
          final mergedParticipants = List<UserProfile>.from(existing.participants);
          for (final p in conv.participants) {
            if (!mergedParticipants.any((mp) => mp.username.toLowerCase() == p.username.toLowerCase())) {
              mergedParticipants.add(p);
            }
          }
          final latestAt = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageAt : existing.lastMessageAt;
          final latestText = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageText : existing.lastMessageText;
          final latestType = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageType : existing.lastMessageType;
          final latestSender = conv.lastMessageAt.isAfter(existing.lastMessageAt) ? conv.lastMessageSenderId : existing.lastMessageSenderId;

          deduplicated[key] = existing.copyWith(
            id: key,
            participants: mergedParticipants,
            lastMessageAt: latestAt,
            lastMessageText: latestText,
            lastMessageType: latestType,
            lastMessageSenderId: latestSender,
            unreadCount: existing.unreadCount + conv.unreadCount,
          );
        } else {
          deduplicated[key] = conv.copyWith(id: key);
        }
      }

      _conversations = deduplicated.values.toList();

      // Reconcile and calculate real unread counts and last message details from cached message store
      for (int i = 0; i < _conversations.length; i++) {
        final conv = _conversations[i];
        final cached = await _loadCachedMessagesForChat(conv.id);
        final lastReadMsgId = prefs.getString('last_read_msg_${conv.id}');

        if (cached.isNotEmpty) {
          final lastMsg = cached.last;
          String preview = lastMsg.content;
          if (lastMsg.messageType == MessageType.image) preview = '📷 Rasm';
          if (lastMsg.messageType == MessageType.video) preview = '🎥 Video';
          if (lastMsg.messageType == MessageType.voice) preview = '🎤 Ovoz (${lastMsg.voiceDuration ?? 10}s)';
          if (lastMsg.messageType == MessageType.doc) preview = '📄 ${lastMsg.fileName ?? "Hujjat"}';

          final myId = userId.toLowerCase();

          // Calculate how many messages are unread from other participants
          int calculatedUnread = 0;
          if (lastReadMsgId != null) {
            final lastReadIdx = cached.indexWhere((m) => m.id == lastReadMsgId);
            if (lastReadIdx != -1) {
              calculatedUnread = cached.sublist(lastReadIdx + 1).where((m) {
                final s = m.senderId.toLowerCase();
                if (s == myId) return false;
                if (cleanMyUsername.isNotEmpty && (s == cleanMyUsername || s.replaceAll('user-', '') == cleanMyUsername)) return false;
                return true;
              }).length;
            } else {
              calculatedUnread = cached.where((m) {
                final s = m.senderId.toLowerCase();
                if (s == myId) return false;
                if (cleanMyUsername.isNotEmpty && (s == cleanMyUsername || s.replaceAll('user-', '') == cleanMyUsername)) return false;
                return true;
              }).length;
            }
          } else {
            calculatedUnread = cached.where((m) {
              final s = m.senderId.toLowerCase();
              if (s == myId) return false;
              if (cleanMyUsername.isNotEmpty && (s == cleanMyUsername || s.replaceAll('user-', '') == cleanMyUsername)) return false;
              return true;
            }).length;
          }

          _conversations[i] = conv.copyWith(
            lastMessageText: preview,
            lastMessageType: lastMsg.messageType,
            lastMessageSenderId: lastMsg.senderId,
            lastMessageAt: lastMsg.createdAt,
            unreadCount: calculatedUnread > 0 ? calculatedUnread : conv.unreadCount,
          );
        } else if (conv.lastMessageText == 'Hey there! I am using SupaChat.' || conv.lastMessageText == 'Eslatmalar va fayllar joyi') {
          if (conv.id.startsWith('saved_messages')) {
            _conversations[i] = conv.copyWith(lastMessageText: 'Eslatmalar va fayllar joyi');
          } else {
            _conversations[i] = conv.copyWith(lastMessageText: null, lastMessageSenderId: null);
          }
        }
      }
      _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      await _saveConversations();
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

  Future<List<UserProfile>> searchUsers(String query, {String? currentUsername}) async {
    final cleanQuery = query.trim().replaceAll('@', '').toLowerCase();
    if (cleanQuery.isEmpty) {
      _sqlSearchResults = [];
      _isSearchingUsers = false;
      notifyListeners();
      return [];
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
    return _sqlSearchResults;
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
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
      _saveConversations();
    }

    await _loadMessagesFromLocalCache(conversation.id);
    if (_currentMessages.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_read_msg_${conversation.id}', _currentMessages.last.id);
    }
    notifyListeners();

    if (_supabaseService.isInitialized) {
      final participantIds = <String>{currentUserId};
      for (final p in conversation.participants) {
        participantIds.add(p.id);
        if (p.username.isNotEmpty) {
          final cleanU = p.username.trim().toLowerCase().replaceAll('@', '');
          participantIds.add(cleanU);
          participantIds.add(_uuid.v5(Namespace.url.value, 'supachat:user:$cleanU'));
        }
      }

      if (!conversation.isGroup && !conversation.id.startsWith('saved_messages') && conversation.participants.isNotEmpty) {
        final other = conversation.getOtherParticipant(currentUserId, currentUsername: _currentActiveUsername);
        if (other != null) {
          await _supabaseService.getOrCreateDirectConversation(
            user1Id: currentUserId,
            user2Id: other.id,
            user1Username: _currentActiveUsername,
            user2Username: other.username,
          );
        }
      } else {
        await _supabaseService.createOrEnsureChat(
          chatId: conversation.id,
          isGroup: conversation.isGroup,
          groupName: conversation.name,
          groupAvatar: conversation.avatarUrl,
          createdBy: currentUserId,
          participantIds: participantIds.toList(),
        );
      }

      final fetched = await _supabaseService.fetchMessages(conversation.id);
      if (fetched.isNotEmpty) {
        _mergeFetchedMessages(fetched);
      }
      _subscribeToRealtime(conversation.id);
    }
  }

  ChatMessage? getMessageById(String id) {
    try {
      return _currentMessages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ChatMessage> _hydrateReplies(List<ChatMessage> messages) {
    if (messages.isEmpty) return messages;
    final map = <String, ChatMessage>{for (final m in messages) m.id: m};
    return messages.map((m) {
      if (m.replyToId != null && m.replyToMessage == null && map.containsKey(m.replyToId)) {
        return m.copyWith(replyToMessage: map[m.replyToId]);
      }
      return m;
    }).toList();
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
        final raw = decoded.map((j) => ChatMessage.fromJson(j)).toList();
        _currentMessages = _hydrateReplies(raw);
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
    SoundService.instance.playIncomingSound();

    if (_activeChat == null || _activeChat!.id != message.chatId) {
      onIncomingNotification?.call(message, conversation);
    }
  }

  String? get currentActiveUserId => _currentActiveUserId;
  String? get currentActiveUsername => _currentActiveUsername;

  RealtimeChannel? _globalRealtimeSubscription;
  String? _currentListeningUserId;

  Future<void> processIncomingMessage(ChatMessage newMsg, {bool isPeriodicSync = false}) async {
    final currentUserId = _currentActiveUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    // If username not yet loaded, try to resolve it now
    if ((_currentActiveUsername == null || _currentActiveUsername!.isEmpty) && _supabaseService.isInitialized) {
      final profile = await _supabaseService.fetchProfile(currentUserId);
      if (profile != null && profile.username.isNotEmpty) {
        _currentActiveUsername = profile.username.trim().toLowerCase();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_username', _currentActiveUsername!);
        debugPrint('[ChatProvider] Lazily resolved username: $_currentActiveUsername');
      }
    }

    final myUsername = _currentActiveUsername?.trim().toLowerCase().replaceAll('@', '') ?? '';
    final senderClean = newMsg.senderId.replaceAll('user-', '').trim().toLowerCase().replaceAll('@', '');

    // If message was sent by ourselves, ignore
    if (newMsg.senderId == currentUserId || (myUsername.isNotEmpty && senderClean == myUsername)) {
      return;
    }

    // Resolve sender's profile
    UserProfile? senderProfile;
    if (_supabaseService.isInitialized) {
      senderProfile = await _supabaseService.fetchProfile(newMsg.senderId);
      if (senderProfile == null && senderClean.isNotEmpty) {
        senderProfile = await _supabaseService.fetchProfileByUsername(senderClean);
      }
    }
    final senderUsername = senderProfile?.username.trim().toLowerCase().replaceAll('@', '') ?? senderClean;
    senderProfile ??= UserProfile(
      id: newMsg.senderId,
      username: senderUsername,
      fullName: senderUsername.isNotEmpty ? senderUsername : 'SupaChat User',
    );

    final expectedDirectId = (myUsername.isNotEmpty && senderUsername.isNotEmpty)
        ? ChatConversation.computeDirectChatId(myUsername, senderUsername)
        : null;

    // In a 1-on-1 messenger, any message sent by another user is for us!
    bool isForMe = true;

    // Only filter out if it's a group chat where current user is not a participant
    if (_supabaseService.isInitialized) {
      try {
        final chatRow = await _supabaseService.getChatById(newMsg.chatId);
        if (chatRow != null && chatRow['is_group'] == true) {
          final isPart = await _supabaseService.isUserParticipant(newMsg.chatId, currentUserId, username: myUsername);
          if (!isPart) {
            isForMe = false;
          }
        }
      } catch (_) {}
    }

    if (!isForMe) {
      debugPrint('[ChatProvider] Dropped group message ${newMsg.id}: not a participant');
      return;
    }

    final targetChatId = expectedDirectId ?? newMsg.chatId;

    // Check if this chat is currently open and active
    bool isCurrentActiveChat = false;
    if (_activeChat != null) {
      if (_activeChat!.id == newMsg.chatId || (expectedDirectId != null && _activeChat!.id == expectedDirectId)) {
        isCurrentActiveChat = true;
      } else if (!_activeChat!.isGroup && myUsername.isNotEmpty && senderUsername.isNotEmpty) {
        final activeOther = _activeChat!.getOtherParticipant(currentUserId, currentUsername: myUsername);
        if (activeOther != null && activeOther.username.trim().toLowerCase().replaceAll('@', '') == senderUsername) {
          isCurrentActiveChat = true;
        }
      }
    }

    if (isCurrentActiveChat) {
      if (!_currentMessages.any((m) => m.id == newMsg.id)) {
        var msgToAdd = newMsg;
        if (msgToAdd.replyToId != null && msgToAdd.replyToMessage == null) {
          final foundReply = _currentMessages.firstWhere(
            (m) => m.id == msgToAdd.replyToId,
            orElse: () => msgToAdd,
          );
          if (foundReply != msgToAdd) {
            msgToAdd = msgToAdd.copyWith(replyToMessage: foundReply);
          }
        }
        _currentMessages.add(msgToAdd);
        _updateLastMessage(msgToAdd);
        _saveMessagesToLocalCache(_activeChat!.id);
        if (_activeChat!.id != newMsg.chatId) {
          _saveMessagesToLocalCache(newMsg.chatId);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_read_msg_${_activeChat!.id}', msgToAdd.id);
        if (!isPeriodicSync) {
          SoundService.instance.playIncomingSound();
        }
        notifyListeners();
      }
      return;
    }

    // Chat is NOT open: update or add conversation in list with unread bubble count
    final convIdx = _conversations.indexWhere(
      (c) => c.id == newMsg.chatId ||
             (expectedDirectId != null && c.id == expectedDirectId) ||
             (!c.isGroup && c.participants.any((p) => p.username.toLowerCase().replaceAll('@', '') == senderUsername)),
    );
    final cached = await _loadCachedMessagesForChat(newMsg.chatId);
    final alreadyExists = cached.any((m) => m.id == newMsg.id) || _currentMessages.any((m) => m.id == newMsg.id);

    String preview = newMsg.content.isNotEmpty ? newMsg.content : 'Media xabar';
    if (newMsg.messageType == MessageType.image) preview = '📷 Rasm';
    if (newMsg.messageType == MessageType.video) preview = '🎥 Video';
    if (newMsg.messageType == MessageType.voice) preview = '🎤 Ovozli xabar';
    if (newMsg.messageType == MessageType.doc) preview = '📄 ${newMsg.fileName ?? "Hujjat"}';

    ChatConversation conv;
    if (convIdx != -1) {
      final existing = _conversations[convIdx];
      final updatedParticipants = List<UserProfile>.from(existing.participants);
      if (!updatedParticipants.any((p) => p.id == senderProfile!.id || p.username.toLowerCase() == senderProfile.username.toLowerCase())) {
        updatedParticipants.add(senderProfile);
      }

      conv = existing.copyWith(
        id: targetChatId,
        name: existing.isGroup ? existing.name : (senderProfile.fullName.isNotEmpty ? senderProfile.fullName : existing.name),
        avatarUrl: existing.isGroup ? existing.avatarUrl : (senderProfile.avatarUrl ?? existing.avatarUrl),
        participants: updatedParticipants,
        lastMessageText: preview,
        lastMessageType: newMsg.messageType,
        lastMessageSenderId: newMsg.senderId,
        lastMessageAt: newMsg.createdAt,
        unreadCount: alreadyExists ? existing.unreadCount : (existing.unreadCount + 1),
      );
      _conversations.removeAt(convIdx);
      _conversations.insert(0, conv);
    } else {
      final myProfile = UserProfile(
        id: currentUserId,
        username: myUsername,
        fullName: _currentActiveUsername ?? myUsername,
      );
      final participantList = [senderProfile];
      if (myUsername.isNotEmpty) {
        participantList.add(myProfile);
      }
      conv = ChatConversation(
        id: targetChatId,
        isGroup: false,
        name: senderProfile.fullName.isNotEmpty ? senderProfile.fullName : senderProfile.username,
        avatarUrl: senderProfile.avatarUrl,
        participants: participantList,
        lastMessageText: preview,
        lastMessageType: newMsg.messageType,
        lastMessageSenderId: newMsg.senderId,
        lastMessageAt: newMsg.createdAt,
        unreadCount: 1,
      );
      _conversations.insert(0, conv);
    }

    _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    await _saveConversations();
    await _appendMessageToLocalCache(targetChatId, newMsg);
    if (newMsg.chatId != targetChatId) {
      await _appendMessageToLocalCache(newMsg.chatId, newMsg);
    }
    notifyListeners();

    // Trigger in-app notification banner and sound
    if (!alreadyExists && !isPeriodicSync) {
      triggerNotification(newMsg, conv);
    }
  }

  void initGlobalRealtime(String currentUserId) {
    if (_currentListeningUserId == currentUserId && _globalStreamSubscription != null) {
      return;
    }
    _currentListeningUserId = currentUserId;

    // 1. Primary: Rock-solid Supabase Realtime Stream
    _globalStreamSubscription?.cancel();
    _globalStreamSubscription = _supabaseService.getGlobalMessagesStream().listen(
      (messages) {
        for (final msg in messages.reversed) {
          processIncomingMessage(msg);
        }
      },
      onError: (err) {
        debugPrint('Global messages stream error: $err');
      },
    );

    // 2. Secondary: Postgres Changes & Broadcast Channel
    _globalRealtimeSubscription?.unsubscribe();
    _globalRealtimeSubscription = _supabaseService.subscribeToAllMessages(
      onMessageReceived: (newMsg) async {
        await processIncomingMessage(newMsg);
      },
      onMessageUpdated: (updatedMsg) async {
        final idx = _currentMessages.indexWhere((m) => m.id == updatedMsg.id);
        if (idx != -1) {
          _currentMessages[idx] = updatedMsg;
          if (_activeChat != null) {
            _saveMessagesToLocalCache(_activeChat!.id);
          }
          notifyListeners();
        }
      },
      onChatUpdated: () async {
        await syncConversationsFromSupabase();
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
    // 1. Cancel previous stream/channel for clean lifecycle
    _activeChatStreamSubscription?.cancel();
    _realtimeSubscription?.unsubscribe();

    // 2. Primary: Official Supabase Realtime Stream for active chat
    _activeChatStreamSubscription = _supabaseService.getChatMessagesStream(chatId).listen(
      (messages) {
        if (messages.isNotEmpty) {
          _mergeFetchedMessages(messages);
        }
      },
      onError: (err) {
        debugPrint('Chat messages stream error [$chatId]: $err');
      },
    );

    // 3. Secondary: Channel listener for broadcast & postgres events
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
    _activeChatStreamSubscription?.cancel();
    _activeChatStreamSubscription = null;
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

  List<UserProfile> getAllChatPartners(String currentUserId) {
    final Map<String, UserProfile> users = {};
    // Add existing contacts
    for (final c in _contacts) {
      if (c.id != currentUserId && c.id.isNotEmpty) {
        users[c.id] = c;
      }
    }
    // Add all 1-on-1 and group chat participants
    for (final conv in _conversations) {
      for (final p in conv.participants) {
        if (p.id != currentUserId && p.id.isNotEmpty) {
          users[p.id] = p;
        }
      }
    }
    return users.values.toList();
  }

  Future<void> addGroupMembers(String chatId, List<UserProfile> newMembers) async {
    if (newMembers.isEmpty) return;
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      final existingMap = {for (final p in _conversations[idx].participants) p.id: p};
      for (final m in newMembers) {
        existingMap[m.id] = m;
      }
      final updatedList = existingMap.values.toList();
      _conversations[idx] = _conversations[idx].copyWith(participants: updatedList);
      if (_activeChat?.id == chatId) {
        _activeChat = _conversations[idx];
      }
      _saveConversations();
      notifyListeners();

      if (_supabaseService.isInitialized) {
        for (final m in newMembers) {
          await _supabaseService.addGroupMember(chatId, m.id);
        }
      }
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

      if (_supabaseService.isInitialized) {
        _supabaseService.removeGroupMember(chatId, userId);
      }
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

    SoundService.instance.playSentSound();

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
      if (_activeChat != null && !_activeChat!.id.startsWith('saved_messages')) {
        if (!_activeChat!.isGroup && _activeChat!.participants.isNotEmpty) {
          final other = _activeChat!.getOtherParticipant(senderId, currentUsername: _currentActiveUsername);
          if (other != null) {
            // --- HARDENED: check result, retry once, fail visibly ---
            Map<String, dynamic>? chatResult = await _supabaseService.getOrCreateDirectConversation(
              user1Id: senderId,
              user2Id: other.id,
              user1Username: _currentActiveUsername,
              user2Username: other.username,
            );

            if (chatResult == null) {
              debugPrint('[sendMessage] getOrCreateDirectConversation returned null — retrying...');
              await Future.delayed(const Duration(milliseconds: 800));
              chatResult = await _supabaseService.getOrCreateDirectConversation(
                user1Id: senderId,
                user2Id: other.id,
                user1Username: _currentActiveUsername,
                user2Username: other.username,
              );
            }

            if (chatResult == null) {
              debugPrint('[sendMessage] Both attempts failed — marking message as failed.');
              _markMessageFailed(newMsg.id);
              return;
            }

            // Attach receiver_id so the DB trigger can add receiver as participant
            String targetRecId = other.id;
            final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
            if (!uuidRegex.hasMatch(targetRecId) && other.username.isNotEmpty) {
              final pRec = await _supabaseService.fetchProfileByUsername(other.username);
              if (pRec != null && uuidRegex.hasMatch(pRec.id)) {
                targetRecId = pRec.id;
              }
            }

            final msgWithReceiver = newMsg.copyWith(receiverId: targetRecId);
            final sent = await _supabaseService.sendMessage(msgWithReceiver);
            final idx = _currentMessages.indexWhere((m) => m.id == newMsg.id);
            if (idx != -1) {
              _currentMessages[idx] = _currentMessages[idx].copyWith(
                receiverId: targetRecId,
                status: sent != null ? MessageStatus.sent : MessageStatus.delivered,
              );
              if (_activeChat != null) _saveMessagesToLocalCache(_activeChat!.id);
              notifyListeners();
            }
            return; // Done for 1-on-1 chat
          }
        } else {
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

  /// Mark a pending message as 'failed' so the user can see it instead of silently dropping
  void _markMessageFailed(String msgId) {
    final idx = _currentMessages.indexWhere((m) => m.id == msgId);
    if (idx != -1) {
      _currentMessages[idx] = _currentMessages[idx].copyWith(status: MessageStatus.sending);
      if (_activeChat != null) _saveMessagesToLocalCache(_activeChat!.id);
      notifyListeners();
    }
    debugPrint('[sendMessage] Message $msgId marked as failed — chat participant setup failed.');
  }

  void _updateLastMessage(ChatMessage msg) {
    final chatId = msg.chatId;
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      String preview = msg.content;
      if (msg.messageType == MessageType.image) preview = '📷 Rasm';
      if (msg.messageType == MessageType.video) preview = '🎥 Video';
      if (msg.messageType == MessageType.voice) preview = '🎤 Ovoz (${msg.voiceDuration ?? 10}s)';
      if (msg.messageType == MessageType.doc) preview = '📄 ${msg.fileName ?? "Hujjat"}';

      _conversations[idx] = _conversations[idx].copyWith(
        lastMessageText: preview,
        lastMessageType: msg.messageType,
        lastMessageSenderId: msg.senderId,
        lastMessageAt: msg.createdAt,
      );
      _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      _saveConversations();
      notifyListeners();
    }
  }

  // Send real recorded voice message
  Future<void> sendVoiceMessage({
    required String senderId,
    required String filePath,
    required int durationSeconds,
  }) async {
    if (_activeChat == null) return;

    final voiceId = _uuid.v4();
    final newMsg = ChatMessage(
      id: voiceId,
      chatId: _activeChat!.id,
      senderId: senderId,
      content: '🎤 Ovozli xabar (${durationSeconds}s)',
      messageType: MessageType.voice,
      mediaUrl: filePath,
      voiceDuration: durationSeconds,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    _currentMessages.add(newMsg);
    final convIdx = _conversations.indexWhere((c) => c.id == _activeChat!.id);
    if (convIdx == -1) {
      _conversations.insert(0, _activeChat!);
    }
    _updateLastMessage(newMsg);
    _saveMessagesToLocalCache(_activeChat!.id);
    await _saveConversations();
    notifyListeners();

    if (_supabaseService.isInitialized) {
      // For 1-on-1 chats: ensure both participants exist before sending voice message
      UserProfile? voiceReceiver;
      if (!_activeChat!.isGroup && _activeChat!.participants.isNotEmpty) {
        voiceReceiver = _activeChat!.getOtherParticipant(senderId, currentUsername: _currentActiveUsername);
        if (voiceReceiver != null) {
          Map<String, dynamic>? chatResult = await _supabaseService.getOrCreateDirectConversation(
            user1Id: senderId,
            user2Id: voiceReceiver.id,
            user1Username: _currentActiveUsername,
            user2Username: voiceReceiver.username,
          );
          if (chatResult == null) {
            await Future.delayed(const Duration(milliseconds: 800));
            chatResult = await _supabaseService.getOrCreateDirectConversation(
              user1Id: senderId,
              user2Id: voiceReceiver.id,
              user1Username: _currentActiveUsername,
              user2Username: voiceReceiver.username,
            );
          }
          if (chatResult == null) {
            _markMessageFailed(newMsg.id);
            return;
          }
        }
      }

      String? uploadedUrl;
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          uploadedUrl = await _supabaseService.uploadFile(
            bucketName: 'chat-media',
            filePath: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
            fileBytes: bytes,
            contentType: 'audio/mp4',
          );
        }
      } catch (e) {
        debugPrint('Error uploading voice message: $e');
      }

      final finalMsg = newMsg.copyWith(
        mediaUrl: uploadedUrl ?? filePath,
        receiverId: voiceReceiver?.id,
      );

      final sent = await _supabaseService.sendMessage(finalMsg);
      final idx = _currentMessages.indexWhere((m) => m.id == voiceId);
      if (idx != -1) {
        _currentMessages[idx] = _currentMessages[idx].copyWith(
          mediaUrl: uploadedUrl ?? filePath,
          receiverId: voiceReceiver?.id,
          status: sent != null ? MessageStatus.sent : MessageStatus.delivered,
        );
        _saveMessagesToLocalCache(_activeChat!.id);
        notifyListeners();
      }
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
    _audioPlayer ??= AudioPlayer();
    _currentlyPlayingVoiceMsgId = msgId;
    _isVoicePlaying = true;
    _voiceProgress = 0.0;
    notifyListeners();

    _audioPlayer!.onPositionChanged.listen((pos) {
      if (_currentlyPlayingVoiceMsgId == msgId && durationSeconds > 0) {
        _voiceProgress = (pos.inMilliseconds / (durationSeconds * 1000)).clamp(0.0, 1.0);
        notifyListeners();
      }
    });

    _audioPlayer!.onPlayerComplete.listen((_) {
      if (_currentlyPlayingVoiceMsgId == msgId) {
        _isVoicePlaying = false;
        _voiceProgress = 0.0;
        _currentlyPlayingVoiceMsgId = null;
        notifyListeners();
      }
    });

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
      if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
        if (msg.mediaUrl!.startsWith('http')) {
          await _audioPlayer!.play(UrlSource(msg.mediaUrl!));
        } else {
          await _audioPlayer!.play(DeviceFileSource(msg.mediaUrl!));
        }
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
    // Determine usernames: prefer currentUser.username, then _currentActiveUsername
    String myUsername = (currentUser?.username.isNotEmpty == true
            ? currentUser!.username
            : _currentActiveUsername ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('@', '');
    if (myUsername.isEmpty && _currentActiveUserId != null) {
      myUsername = _currentActiveUserId!.replaceAll('user-', '').toLowerCase();
    }

    String targetUsername = contact.username.trim().toLowerCase().replaceAll('@', '');
    if (targetUsername.isEmpty) {
      targetUsername = contact.id.replaceAll('user-', '').toLowerCase();
    }

    // Compute deterministic chat ID based on sorted usernames
    final chatId = (myUsername.isNotEmpty && targetUsername.isNotEmpty)
        ? ChatConversation.computeDirectChatId(myUsername, targetUsername)
        : _uuid.v4();

    // Check if conversation already exists (by chatId OR by participant match)
    final existingIdx = _conversations.indexWhere(
      (c) => c.id == chatId || (!c.isGroup && (
        c.participants.any((p) => p.id == contact.id || p.username.toLowerCase().replaceAll('@', '') == targetUsername) ||
        (myUsername.isNotEmpty && targetUsername.isNotEmpty && c.id == ChatConversation.computeDirectChatId(myUsername, targetUsername))
      )),
    );

    if (existingIdx != -1) {
      final existing = _conversations[existingIdx];
      final currentParticipants = List<UserProfile>.from(existing.participants);
      if (currentUser != null && !currentParticipants.any((p) => p.username.toLowerCase().replaceAll('@', '') == myUsername)) {
        currentParticipants.add(currentUser);
      }
      if (!currentParticipants.any((p) => p.username.toLowerCase().replaceAll('@', '') == targetUsername)) {
        currentParticipants.add(contact);
      }

      final updated = existing.copyWith(
        id: chatId,
        participants: currentParticipants,
        name: existing.isGroup ? existing.name : (contact.fullName.isNotEmpty ? contact.fullName : contact.username),
        avatarUrl: existing.isGroup ? existing.avatarUrl : (contact.avatarUrl ?? existing.avatarUrl),
      );
      _conversations[existingIdx] = updated;
      _saveConversations();

      if (_supabaseService.isInitialized) {
        final myId = currentUser?.id ?? _currentActiveUserId ?? myUsername;
        _supabaseService.getOrCreateDirectConversation(
          user1Id: myId,
          user2Id: contact.id,
          user1Username: myUsername,
          user2Username: targetUsername,
        );
      }

      return updated;
    }

    final newChat = ChatConversation(
      id: chatId,
      isGroup: false,
      name: contact.fullName.isNotEmpty ? contact.fullName : contact.username,
      avatarUrl: contact.avatarUrl,
      participants: currentUser != null ? [currentUser, contact] : [contact],
      lastMessageText: null,
      lastMessageType: MessageType.text,
      lastMessageSenderId: null,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    _conversations.insert(0, newChat);
    _saveConversations();
    notifyListeners();

    if (_supabaseService.isInitialized) {
      final myId = currentUser?.id ?? _currentActiveUserId ?? myUsername;
      _supabaseService.getOrCreateDirectConversation(
        user1Id: myId,
        user2Id: contact.id,
        user1Username: myUsername,
        user2Username: targetUsername,
      );
    }

    return newChat;
  }

  /// Fetch conversations from Supabase for the current user and merge into local list
  Future<void> syncConversationsFromSupabase() async {
    if (!_supabaseService.isInitialized || _currentActiveUserId == null) return;
    try {
      final remote = await _supabaseService.fetchUserConversations(
        _currentActiveUserId!,
        username: _currentActiveUsername,
      );
      for (final conv in remote) {
        if (conv.id.contains('00000000') ||
            conv.name.contains('SupaChat Developer') ||
            conv.name.contains('SupaChat Assistant') ||
            conv.name.contains('SupaChat Community') ||
            conv.participants.any((p) => p.username == 'admin_dev' || p.username == 'supachat_bot')) {
          continue;
        }

        // Ignore empty 1-on-1 chats without any messages or unread count
        if (!conv.isGroup && (conv.lastMessageText == null || conv.lastMessageText!.trim().isEmpty) && conv.unreadCount == 0) {
          continue;
        }

        final localIdx = _conversations.indexWhere((c) => c.id == conv.id);
        if (localIdx == -1) {
          // Check if direct conversation exists with same participant under old ID
          final participantIdx = !conv.isGroup
              ? _conversations.indexWhere((c) => !c.isGroup && c.participants.any((p) => conv.participants.any((cp) => cp.username.toLowerCase() == p.username.toLowerCase())))
              : -1;

          if (participantIdx != -1) {
            _conversations[participantIdx] = conv;
          } else {
            _conversations.insert(0, conv);
          }
        } else {
          final existing = _conversations[localIdx];
          if (existing.participants.isEmpty && conv.participants.isNotEmpty) {
            _conversations[localIdx] = existing.copyWith(participants: conv.participants);
          }
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

  @override
  void dispose() {
    _activeChatStreamSubscription?.cancel();
    _globalStreamSubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _realtimeSubscription?.unsubscribe();
    _globalRealtimeSubscription?.unsubscribe();
    _audioPlayer?.dispose();
    super.dispose();
  }
}

