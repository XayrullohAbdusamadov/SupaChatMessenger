import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_conversation.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isInitialized = false;
  String? _currentSupabaseUrl;
  String? _currentAnonKey;

  SupabaseClient? get client => _client;
  bool get isInitialized => _isInitialized && _client != null;
  bool get isAuthenticated => _client?.auth.currentUser != null;
  User? get currentAuthUser => _client?.auth.currentUser;
  String? get currentSupabaseUrl => _currentSupabaseUrl;
  String? get currentAnonKey => _currentAnonKey;

  // Initialize from saved preferences or defaults
  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('supabase_url') ?? AppConstants.defaultSupabaseUrl;
      final savedKey = prefs.getString('supabase_anon_key') ?? AppConstants.defaultSupabaseAnonKey;

      if (savedUrl.isNotEmpty && savedKey.isNotEmpty && savedUrl.startsWith('http') && !savedUrl.contains('your-project')) {
        return await connect(savedUrl, savedKey);
      }
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
    return false;
  }

  // Connect to Supabase instance
  Future<bool> connect(String url, String anonKey) async {
    try {
      if (url.isEmpty || anonKey.isEmpty || !url.startsWith('http')) {
        return false;
      }

      await Supabase.initialize(
        url: url.trim(),
        // ignore: deprecated_member_use
        anonKey: anonKey.trim(),
        debug: kDebugMode,
      );

      _client = Supabase.instance.client;
      _isInitialized = true;
      _currentSupabaseUrl = url.trim();
      _currentAnonKey = anonKey.trim();

      // Save credentials locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_url', url.trim());
      await prefs.setString('supabase_anon_key', anonKey.trim());

      debugPrint('Connected to Supabase: $url');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to Supabase: $e');
      return false;
    }
  }

  // Clear saved credentials
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supabase_url');
    await prefs.remove('supabase_anon_key');
    _client = null;
    _isInitialized = false;
  }

  // AUTHENTICATION
  Future<AuthResponse?> signInWithEmail(String email, String password) async {
    if (!isInitialized) return null;
    try {
      return await _client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('Supabase signInWithEmail error: $e');
      return null;
    }
  }

  Future<AuthResponse?> signUpWithEmail(
    String email,
    String password, {
    required String username,
    required String fullName,
  }) async {
    if (!isInitialized) return null;
    try {
      return await _client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': username.trim().toLowerCase(),
          'full_name': fullName.trim(),
        },
      );
    } catch (e) {
      debugPrint('Supabase signUpWithEmail error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!isInitialized) return;
    try {
      await _client!.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut error: $e');
    }
  }

  // PROFILES
  Future<UserProfile?> fetchProfile(String userId) async {
    if (!isInitialized) return null;
    try {
      // 1. Try by id
      final response = await _client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }

      // 2. Try by username
      final clean = userId.replaceAll('user-', '').trim().toLowerCase();
      final responseUser = await _client!
          .from('profiles')
          .select()
          .eq('username', clean)
          .maybeSingle();

      if (responseUser != null) {
        return UserProfile.fromJson(responseUser);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  Future<UserProfile?> fetchProfileByUsername(String username) async {
    if (!isInitialized) return null;
    final clean = username.trim().toLowerCase();
    try {
      final response = await _client!
          .from('profiles')
          .select()
          .eq('username', clean)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('Error fetching profile by username: $e');
    }
    return null;
  }

  Future<List<ChatMessage>> fetchRecentGlobalMessages() async {
    if (!isInitialized) return [];
    try {
      final response = await _client!
          .from('messages')
          .select()
          .order('created_at', ascending: false)
          .limit(30);

      return (response as List).map((j) => ChatMessage.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateProfile(UserProfile profile) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('profiles').upsert({
        'id': profile.id,
        'username': profile.username.trim().toLowerCase(),
        'full_name': profile.fullName.trim().isNotEmpty ? profile.fullName.trim() : profile.username.trim(),
        'avatar_url': profile.avatarUrl,
        'about': profile.about.isNotEmpty ? profile.about : 'Hey there! I am using SupaChat.',
        'is_online': profile.isOnline,
        'last_seen': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating profile in Supabase: $e');
      return false;
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (!isInitialized) return [];
    final clean = query.trim().replaceAll('@', '').toLowerCase();
    if (clean.isEmpty) return [];

    final Map<String, UserProfile> userMap = {};

    // 1. Direct equality on username
    try {
      final exactRes = await _client!
          .from('profiles')
          .select()
          .eq('username', clean)
          .limit(5);

      for (final row in exactRes as List) {
        final u = UserProfile.fromJson(row);
        userMap[u.username.toLowerCase()] = u;
      }
    } catch (e) {
      debugPrint('Error searching exact username in Supabase: $e');
    }

    // 2. ILIKE query on username or full_name
    try {
      final response = await _client!
          .from('profiles')
          .select()
          .or('username.ilike.%$clean%,full_name.ilike.%$clean%')
          .limit(25);

      for (final row in response as List) {
        final u = UserProfile.fromJson(row);
        userMap[u.username.toLowerCase()] = u;
      }
    } catch (e) {
      debugPrint('Error searching users in Supabase: $e');
      try {
        final response = await _client!
            .from('profiles')
            .select()
            .ilike('username', '%$clean%')
            .limit(25);

        for (final row in response as List) {
          final u = UserProfile.fromJson(row);
          userMap[u.username.toLowerCase()] = u;
        }
      } catch (err) {
        debugPrint('Fallback username search error: $err');
      }
    }

    return userMap.values.toList();
  }

  // CHATS
  Future<bool> createOrEnsureChat({
    required String chatId,
    required bool isGroup,
    String? groupName,
    String? groupAvatar,
    required String createdBy,
    required List<String> participantIds,
  }) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('chats').upsert({
        'id': chatId,
        'is_group': isGroup,
        'group_name': groupName,
        'group_avatar': groupAvatar,
        'created_by': createdBy,
      });

      for (final uid in participantIds) {
        await _client!.from('chat_participants').upsert({
          'chat_id': chatId,
          'user_id': uid,
          'role': uid == createdBy ? 'admin' : 'member',
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error ensuring chat in Supabase: $e');
      return false;
    }
  }

  Future<bool> isUserParticipant(String chatId, String userId) async {
    if (!isInitialized) return false;
    try {
      final res = await _client!
          .from('chat_participants')
          .select('chat_id')
          .eq('chat_id', chatId)
          .eq('user_id', userId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('Error checking isUserParticipant: $e');
      return false;
    }
  }

  // STORAGE UPLOADS
  Future<String?> uploadFile({
    required String bucketName,
    required String filePath,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    if (!isInitialized) return null;
    try {
      await _client!.storage.from(bucketName).uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      final publicUrl = _client!.storage.from(bucketName).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading file to storage: $e');
      return null;
    }
  }

  // MESSAGES
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    if (!isInitialized) return [];
    try {
      final response = await _client!
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  RealtimeChannel? _globalChannel;

  Future<ChatMessage?> sendMessage(ChatMessage message) async {
    if (!isInitialized) return null;
    try {
      final inserted = await _client!
          .from('messages')
          .insert(message.toJson())
          .select()
          .single();

      // Update last message in chat
      try {
        await _client!.from('chats').upsert({
          'id': message.chatId,
          'last_message_text': message.content.isNotEmpty ? message.content : 'Media xabar',
          'last_message_type': message.messageType.name,
          'last_message_sender_id': message.senderId,
          'last_message_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      // Broadcast immediately across Realtime channels for zero-latency peer updates
      try {
        if (_globalChannel != null) {
          _globalChannel!.sendBroadcastMessage(
            event: 'new_message',
            payload: message.toJson(),
          );
        } else {
          _client!.channel('public:messages:all').sendBroadcastMessage(
            event: 'new_message',
            payload: message.toJson(),
          );
        }

        // Also broadcast directly on chat channel
        _client!.channel('public:messages:${message.chatId}').sendBroadcastMessage(
          event: 'new_message',
          payload: message.toJson(),
        );
      } catch (err) {
        debugPrint('Broadcast error (non-fatal): $err');
      }

      return ChatMessage.fromJson(inserted);
    } catch (e) {
      debugPrint('Error sending message to Supabase: $e');
      return null;
    }
  }

  Future<void> updateMessageReactions(String messageId, List<String> reactions) async {
    if (!isInitialized) return;
    try {
      await _client!.from('messages').update({
        'reactions': reactions,
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('Error updating message reactions in Supabase: $e');
    }
  }

  // REALTIME SUBSCRIPTIONS
  RealtimeChannel? subscribeToChatMessages(
    String chatId, {
    required Function(ChatMessage message) onMessageReceived,
  }) {
    if (!isInitialized) return null;

    final channel = _client!.channel('public:messages:$chatId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_id',
        value: chatId,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          try {
            final message = ChatMessage.fromJson(newRecord);
            onMessageReceived(message);
          } catch (e) {
            debugPrint('Error decoding chat message payload: $e');
          }
        }
      },
    );

    channel.onBroadcast(
      event: 'new_message',
      callback: (payload) {
        try {
          final message = ChatMessage.fromJson(payload);
          onMessageReceived(message);
        } catch (e) {
          debugPrint('Error decoding chat broadcast payload: $e');
        }
      },
    );

    channel.subscribe();
    return channel;
  }

  // GLOBAL REALTIME MESSAGE LISTENER
  RealtimeChannel? subscribeToAllMessages({
    required Function(ChatMessage message) onMessageReceived,
    Function(ChatMessage message)? onMessageUpdated,
  }) {
    if (!isInitialized) return null;

    try {
      _globalChannel?.unsubscribe();
    } catch (_) {}

    final channel = _client!.channel('public:messages:all');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          try {
            final message = ChatMessage.fromJson(newRecord);
            if (payload.eventType == PostgresChangeEvent.insert) {
              onMessageReceived(message);
            } else if (payload.eventType == PostgresChangeEvent.update) {
              onMessageUpdated?.call(message);
            }
          } catch (e) {
            debugPrint('Error decoding realtime postgres message: $e');
          }
        }
      },
    );

    channel.onBroadcast(
      event: 'new_message',
      callback: (payload) {
        try {
          final message = ChatMessage.fromJson(payload);
          onMessageReceived(message);
        } catch (e) {
          debugPrint('Error decoding broadcast message: $e');
        }
      },
    );

    channel.subscribe();
    _globalChannel = channel;
    return channel;
  }

  /// Fetch all conversations for a user from Supabase (via chat_participants table)
  Future<List<ChatConversation>> fetchUserConversations(String userId) async {
    if (!isInitialized) return [];
    try {
      // Get all chat IDs where this user is a participant
      final participantRows = await _client!
          .from('chat_participants')
          .select('chat_id, unread_count')
          .eq('user_id', userId);

      if ((participantRows as List).isEmpty) return [];

      final chatIds = participantRows.map((r) => r['chat_id'] as String).toList();
      final unreadMap = <String, int>{};
      for (final r in participantRows) {
        unreadMap[r['chat_id'] as String] = r['unread_count'] as int? ?? 0;
      }

      // Fetch chat metadata
      final chatRows = await _client!
          .from('chats')
          .select()
          .inFilter('id', chatIds)
          .order('last_message_at', ascending: false);

      final List<ChatConversation> conversations = [];
      for (final chatRow in chatRows as List) {
        final chatId = chatRow['id'] as String;

        // Fetch participants for this chat
        final partRows = await _client!
            .from('chat_participants')
            .select('user_id')
            .eq('chat_id', chatId);

        final List<UserProfile> participants = [];
        for (final pr in partRows as List) {
          final uid = pr['user_id'] as String;
          final profile = await fetchProfile(uid);
          if (profile != null) participants.add(profile);
        }

        // Fetch latest message from messages table to get exact latest content, sender, and time
        String? lastText = chatRow['last_message_text'] as String?;
        String? lastTypeStr = chatRow['last_message_type'] as String?;
        String? lastSenderId = chatRow['last_message_sender_id'] as String?;
        DateTime lastAt = chatRow['last_message_at'] != null
            ? DateTime.tryParse(chatRow['last_message_at'].toString()) ?? DateTime.now()
            : DateTime.now();

        try {
          final lastMsgRes = await _client!
              .from('messages')
              .select('content, message_type, sender_id, file_name, voice_duration, created_at')
              .eq('chat_id', chatId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (lastMsgRes != null) {
            final c = lastMsgRes['content'] as String?;
            final mType = lastMsgRes['message_type'] as String?;
            if (mType == 'image') {
              lastText = '📷 Rasm';
            } else if (mType == 'video') {
              lastText = '🎥 Video';
            } else if (mType == 'voice') {
              lastText = '🎤 Ovozli xabar';
            } else if (mType == 'doc') {
              lastText = '📄 ${lastMsgRes['file_name'] ?? "Hujjat"}';
            } else {
              lastText = c;
            }
            lastTypeStr = mType ?? lastTypeStr;
            lastSenderId = lastMsgRes['sender_id'] as String? ?? lastSenderId;
            if (lastMsgRes['created_at'] != null) {
              lastAt = DateTime.tryParse(lastMsgRes['created_at'].toString()) ?? lastAt;
            }
          }
        } catch (_) {}

        conversations.add(ChatConversation(
          id: chatId,
          isGroup: chatRow['is_group'] as bool? ?? false,
          name: chatRow['group_name'] as String? ?? 'Chat',
          avatarUrl: chatRow['group_avatar'] as String?,
          createdBy: chatRow['created_by'] as String?,
          adminIds: (chatRow['admin_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          blockedMemberIds: (chatRow['blocked_member_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          participants: participants,
          lastMessageText: lastText,
          lastMessageType: lastTypeStr != null
              ? MessageType.values.firstWhere(
                  (e) => e.name == lastTypeStr,
                  orElse: () => MessageType.text,
                )
              : null,
          lastMessageSenderId: lastSenderId,
          lastMessageAt: lastAt,
          unreadCount: unreadMap[chatId] ?? 0,
        ));
      }

      return conversations;
    } catch (e) {
      debugPrint('Error fetching user conversations: $e');
      return [];
    }
  }
}
