import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      final savedUrl = prefs.getString('supabase_url');
      final savedKey = prefs.getString('supabase_anon_key');

      if (savedUrl != null && savedKey != null && savedUrl.isNotEmpty && savedKey.isNotEmpty) {
        return await connect(savedUrl, savedKey);
      }
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
    return false;
  }

  // Connect to custom Supabase instance
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
    return await _client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse?> signUpWithEmail(
    String email,
    String password, {
    required String username,
    required String fullName,
  }) async {
    if (!isInitialized) return null;
    return await _client!.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'username': username.trim(),
        'full_name': fullName.trim(),
      },
    );
  }

  Future<void> signOut() async {
    if (!isInitialized) return;
    await _client!.auth.signOut();
  }

  // PROFILES
  Future<UserProfile?> fetchProfile(String userId) async {
    if (!isInitialized) return null;
    try {
      final response = await _client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  Future<bool> updateProfile(UserProfile profile) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('profiles').upsert({
        'id': profile.id,
        'username': profile.username,
        'full_name': profile.fullName,
        'avatar_url': profile.avatarUrl,
        'about': profile.about,
        'is_online': profile.isOnline,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (!isInitialized) return [];
    try {
      final response = await _client!
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(20);

      return (response as List).map((json) => UserProfile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
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

  // REALTIME SUBSCRIPTION
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
}
