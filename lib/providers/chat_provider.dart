import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/mock_data.dart';
import '../data/models/chat_conversation.dart';
import '../data/models/chat_message.dart';
import '../data/models/user_profile.dart';

class ChatProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Uuid _uuid = const Uuid();

  List<ChatConversation> _conversations = [];
  List<UserProfile> _contacts = [];
  List<ChatMessage> _currentMessages = [];
  ChatConversation? _activeChat;
  ChatMessage? _replyingToMessage;
  ChatMessage? _editingMessage;
  String _searchQuery = '';
  final bool _isLoading = false;
  RealtimeChannel? _realtimeSubscription;

  // Audio voice note simulation state
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
  }

  void _loadInitialData() {
    _conversations = MockData.getInitialChats();
    _contacts = MockData.contacts;
    notifyListeners();
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

    // Reset unread count for this conversation
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
          content: conversation.lastMessageText ?? 'Salom!',
          messageType: conversation.lastMessageType ?? MessageType.text,
          status: MessageStatus.read,
          createdAt: conversation.lastMessageAt,
        ),
      ];
    }

    notifyListeners();

    // Subscribe to Supabase realtime if connected
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

  // DELETE CHAT CONVERSATION COMPLETELY
  void deleteChat(String chatId) {
    _conversations.removeWhere((c) => c.id == chatId);
    if (_activeChat?.id == chatId) {
      closeChat();
    }
    notifyListeners();
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

    // Send to Supabase DB if connected
    if (_supabaseService.isInitialized) {
      await _supabaseService.sendMessage(newMsg);
    } else {
      // Simulate reply after 1.5 seconds for interactive demo feeling
      _simulateDemoReply(newMsg);
    }
  }

  void _updateLastMessage(ChatMessage msg) {
    if (_activeChat == null) return;
    final idx = _conversations.indexWhere((c) => c.id == _activeChat!.id);
    if (idx != -1) {
      String preview = msg.content;
      if (msg.messageType == MessageType.image) preview = '📷 Rasm yuborildi';
      if (msg.messageType == MessageType.voice) preview = '🎤 Ovozli xabar (${msg.voiceDuration ?? 10}s)';
      if (msg.messageType == MessageType.doc) preview = '📄 ${msg.fileName ?? "Hujjat"}';

      _conversations[idx] = _conversations[idx].copyWith(
        lastMessageText: preview,
        lastMessageType: msg.messageType,
        lastMessageAt: msg.createdAt,
      );
    }
  }

  void _simulateDemoReply(ChatMessage userMsg) {
    if (_activeChat == null || _activeChat!.isGroup) return;

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_activeChat == null) return;

      final replyMsg = ChatMessage(
        id: _uuid.v4(),
        chatId: _activeChat!.id,
        senderId: _activeChat!.participants.isNotEmpty
            ? _activeChat!.participants.first.id
            : 'other-user',
        messageType: MessageType.text,
        content: "Ajoyib! SupaChat Messenger tizimi juda tez va qulay ishlamoqda. 🚀",
        status: MessageStatus.read,
        createdAt: DateTime.now(),
      );

      _currentMessages.add(replyMsg);
      _updateLastMessage(replyMsg);

      // Mark all previous user messages as read
      for (int i = 0; i < _currentMessages.length; i++) {
        if (_currentMessages[i].senderId == userMsg.senderId) {
          _currentMessages[i] = _currentMessages[i].copyWith(status: MessageStatus.read);
        }
      }

      notifyListeners();
    });
  }

  // Voice note play/pause toggle
  void togglePlayVoice(String msgId, int durationSeconds) {
    if (_currentlyPlayingVoiceMsgId == msgId && _isVoicePlaying) {
      _isVoicePlaying = false;
      notifyListeners();
    } else {
      _currentlyPlayingVoiceMsgId = msgId;
      _isVoicePlaying = true;
      _voiceProgress = 0.0;
      notifyListeners();

      // Simulate playback progression
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

  // Create new group
  void createNewGroup({
    required String groupName,
    required List<UserProfile> members,
    String? avatarUrl,
  }) {
    final newGroup = ChatConversation(
      id: 'group-${_uuid.v4()}',
      isGroup: true,
      name: groupName,
      avatarUrl: avatarUrl,
      participants: members,
      lastMessageText: 'Guruh yaratildi',
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
