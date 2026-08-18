import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/chat_message.dart';

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

  Future<ChatMessage?> sendMessage(ChatMessage message) async {
    if (!isInitialized) return null;
    try {
      final inserted = await _client!
          .from('messages')
          .insert(message.toJson())
          .select()
          .single();

      // Update last message in chat
      await _client!.from('chats').update({
        'last_message_text': message.content,
        'last_message_type': message.messageType.name,
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', message.chatId);

      return ChatMessage.fromJson(inserted);
    } catch (e) {
      debugPrint('Error sending message: $e');
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
      event: PostgresChangeEvent.insert,
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
          final message = ChatMessage.fromJson(newRecord);
          onMessageReceived(message);
        }
      },
    ).subscribe();

    return channel;
  }

  // GLOBAL REALTIME MESSAGE LISTENER
  RealtimeChannel? subscribeToAllMessages({
    required Function(ChatMessage message) onMessageReceived,
    Function(ChatMessage message)? onMessageUpdated,
  }) {
    if (!isInitialized) return null;

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
            debugPrint('Error decoding realtime message: $e');
          }
        }
      },
    ).subscribe();

    return channel;
  }
}
