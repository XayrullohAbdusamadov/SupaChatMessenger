import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/mock_data.dart';
import '../core/utils/smart_reply_helper.dart';
import '../data/models/chat_conversation.dart';
import '../data/models/chat_message.dart';
import '../data/models/user_profile.dart';
import '../data/models/user_story.dart';

class ChatProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Uuid _uuid = const Uuid();

  List<ChatConversation> _conversations = [];
  List<UserProfile> _contacts = [];
  List<ChatMessage> _currentMessages = [];
  List<UserStory> _stories = [];
  final Set<String> _blockedUserIds = {};
  final Set<String> _viewedStoryIds = {};
  ChatConversation? _activeChat;
  ChatMessage? _replyingToMessage;
  ChatMessage? _editingMessage;
  String _searchQuery = '';
  final bool _isLoading = false;
  RealtimeChannel? _realtimeSubscription;

  // Audio voice note player
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingVoiceMsgId;
  bool _isVoicePlaying = false;
  double _voiceProgress = 0.0;

  List<ChatConversation> get conversations {
    if (_searchQuery.isEmpty) {
      return _conversations;
    }
    return _conversations.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  List<UserProfile> get contacts {
    if (_searchQuery.isEmpty) {
      return _contacts;
    }
    return _contacts.where((u) =>
        u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        u.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (u.role != null && u.role!.toLowerCase().contains(_searchQuery.toLowerCase()))).toList();
  }

  List<ChatMessage> get currentMessages => _currentMessages;
  List<UserStory> get stories => _stories;
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

  ChatProvider() {
    _loadInitialData();
    _initAudioPlayer();
  }

  Future<void> _loadInitialData() async {
    _conversations = MockData.getInitialChats();
    _contacts = MockData.contacts;
    _initStories();

    // Load blocked user ids from preferences
    final prefs = await SharedPreferences.getInstance();
    final savedBlocked = prefs.getStringList('blocked_user_ids') ?? [];
    _blockedUserIds.addAll(savedBlocked);

    final savedViewed = prefs.getStringList('viewed_story_ids') ?? [];
    _viewedStoryIds.addAll(savedViewed);

    notifyListeners();
  }

  void _initStories() {
    _stories = [
      UserStory(
        id: 'story-1',
        userId: 'user-lola',
        userName: 'Lola Ahmedova',
        userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&auto=format&fit=crop&q=80',
        mediaUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&auto=format&fit=crop&q=80',
        caption: 'Bugungi quyoshli kun! ✨☀️',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      UserStory(
        id: 'story-2',
        userId: 'user-jasur',
        userName: 'Jasur Saidov',
        userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
        mediaUrl: 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=800&auto=format&fit=crop&q=80',
        caption: 'Tog\'lardagi ajoyib dam olish 🏔️',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      UserStory(
        id: 'story-3',
        userId: 'user-malika',
        userName: 'Malika Karimova',
        userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
        mediaUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?w=800&auto=format&fit=crop&q=80',
        caption: 'Yangi loyiha start oldi! 🚀💻',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      UserStory(
        id: 'story-4',
        userId: 'user-anvar',
        userName: 'Anvar Temirov',
        userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
        mediaUrl: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&auto=format&fit=crop&q=80',
        caption: 'Sayohat taassurotlari ✈️🌍',
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      ),
    ];
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
    // Find contact for story
    final contact = _contacts.firstWhere(
      (c) => c.id == story.userId,
      orElse: () => UserProfile(
        id: story.userId,
        username: story.userName.toLowerCase().replaceAll(' ', '_'),
        fullName: story.userName,
        avatarUrl: story.userAvatar,
      ),
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

  void setSearchQuery(String query) {
    _searchQuery = query;
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
  void openChat(ChatConversation conversation, String currentUserId) {
    _activeChat = conversation;
    _replyingToMessage = null;
    _editingMessage = null;

    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1 && _conversations[index].unreadCount > 0) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    }

    if (conversation.id == 'chat-lola') {
      _currentMessages = MockData.getLolaMessages();
    } else {
      _currentMessages = [
        ChatMessage(
          id: _uuid.v4(),
          chatId: conversation.id,
          senderId: conversation.participants.isNotEmpty
              ? conversation.participants.first.id
              : 'other-user',
          content: conversation.lastMessageText ?? 'Salom! Qalaysiz?',
          messageType: conversation.lastMessageType ?? MessageType.text,
          status: MessageStatus.read,
          createdAt: conversation.lastMessageAt,
        ),
      ];
    }

    notifyListeners();

    if (_supabaseService.isInitialized) {
      _subscribeToRealtime(conversation.id);
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
          notifyListeners();
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
    }
    notifyListeners();
  }

  // DELETE MESSAGE
  void deleteMessage(String messageId) {
    _currentMessages.removeWhere((m) => m.id == messageId);
    if (_activeChat != null && _currentMessages.isNotEmpty) {
      _updateLastMessage(_currentMessages.last);
    }
    notifyListeners();
  }

  // DELETE CHAT CONVERSATION COMPLETELY WITH CLEANUP
  void deleteChatCompletely(String chatId) {
    final convIdx = _conversations.indexWhere((c) => c.id == chatId);
    if (convIdx != -1) {
      final conv = _conversations[convIdx];
      final participantIds = conv.participants.map((p) => p.id).toSet();
      // Remove all stories associated with this contact/chat
      _stories.removeWhere((s) => participantIds.contains(s.userId));
      // Remove from contacts if direct chat
      if (!conv.isGroup) {
        _contacts.removeWhere((c) => participantIds.contains(c.id));
      }
      _conversations.removeAt(convIdx);
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
      notifyListeners();
    }
  }

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

    // If editing existing message
    if (_editingMessage != null) {
      final editIdx = _currentMessages.indexWhere((m) => m.id == _editingMessage!.id);
      if (editIdx != -1) {
        _currentMessages[editIdx] = _currentMessages[editIdx].copyWith(
          content: content.trim(),
          isEdited: true,
        );
      }
      _editingMessage = null;
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
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );

    _currentMessages.add(newMsg);
    _updateLastMessage(newMsg);
    _replyingToMessage = null;
    notifyListeners();

    if (_supabaseService.isInitialized) {
      await _supabaseService.sendMessage(newMsg);
    } else {
      _simulateIntelligentReply(newMsg);
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
    }
  }

  // DYNAMIC INTELLIGENT BOT REPLIES
  void _simulateIntelligentReply(ChatMessage userMsg) {
    if (_activeChat == null || _activeChat!.isGroup) return;

    final targetContact = _activeChat!.participants.isNotEmpty
        ? _activeChat!.participants.first
        : UserProfile(id: 'demo-user', username: 'user', fullName: _activeChat!.name);

    // If target contact is blocked, do not reply
    if (_blockedUserIds.contains(targetContact.id)) return;

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_activeChat == null) return;

      final replyContent = SmartReplyHelper.generateReply(
        userMessage: userMsg,
        contactName: targetContact.fullName,
      );

      final replyMsg = ChatMessage(
        id: _uuid.v4(),
        chatId: _activeChat!.id,
        senderId: targetContact.id,
        messageType: MessageType.text,
        content: replyContent,
        status: MessageStatus.read,
        createdAt: DateTime.now(),
      );

      _currentMessages.add(replyMsg);
      _updateLastMessage(replyMsg);

      for (int i = 0; i < _currentMessages.length; i++) {
        if (_currentMessages[i].senderId == userMsg.senderId) {
          _currentMessages[i] = _currentMessages[i].copyWith(status: MessageStatus.read);
        }
      }

      notifyListeners();
    });
  }

  // Voice note play/pause toggle with AudioPlayer
  Future<void> togglePlayVoice(String msgId, int durationSeconds) async {
    if (_currentlyPlayingVoiceMsgId == msgId && _isVoicePlaying) {
      await _audioPlayer?.pause();
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
        _simulateVoiceProgress(msgId, durationSeconds);
      }
    } catch (e) {
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
    final newGroup = ChatConversation(
      id: 'group-${_uuid.v4()}',
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
    notifyListeners();
  }

  // Start chat with a contact
  ChatConversation startDirectChat(UserProfile contact) {
    final existingIdx = _conversations.indexWhere(
      (c) => !c.isGroup && c.participants.any((p) => p.id == contact.id),
    );

    if (existingIdx != -1) {
      return _conversations[existingIdx];
    }

    final newChat = ChatConversation(
      id: 'chat-${contact.username}',
      isGroup: false,
      name: contact.fullName,
      avatarUrl: contact.avatarUrl,
      participants: [contact],
      lastMessageText: contact.about,
      lastMessageType: MessageType.text,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    _conversations.insert(0, newChat);
    notifyListeners();
    return newChat;
  }
}
