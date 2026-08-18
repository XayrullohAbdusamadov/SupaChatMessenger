import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Notification Service for handling Push Notifications (FCM) and Local Foreground Alerts.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  String? _currentFcmToken;
  String? get currentFcmToken => _currentFcmToken;

  /// Callback when a push notification or local banner is tapped (for Deep Linking)
  Function(String chatId, String senderId)? onNotificationOpenedChat;

  /// Initialize notification handlers
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentFcmToken = prefs.getString('user_fcm_token');
  }

  /// Register or update the user's FCM token in Supabase
  Future<bool> registerDeviceToken({
    required String userId,
    required String fcmToken,
    String? platform,
    String? deviceName,
  }) async {
    if (userId.isEmpty || fcmToken.isEmpty) return false;

    _currentFcmToken = fcmToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_fcm_token', fcmToken);

    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          // 1. Update in profiles table
          await client.from('profiles').update({
            'fcm_token': fcmToken,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);

          // 2. Upsert into user_devices table
          await client.from('user_devices').upsert({
            'user_id': userId,
            'fcm_token': fcmToken,
            'platform': platform ?? (kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase()),
            'device_name': deviceName ?? 'Mobile Device',
            'updated_at': DateTime.now().toIso8601String(),
          });

          debugPrint('FCM Token successfully saved to Supabase for user $userId');
          return true;
        }
      } catch (e) {
        debugPrint('Error saving FCM device token to Supabase: $e');
      }
    }
    return false;
  }

  /// Handle incoming notification payload (Deep Link to Chat)
  void handleNotificationPayload(Map<String, dynamic> data) {
    try {
      final chatId = data['chat_id'] as String?;
      final senderId = data['sender_id'] as String?;
      if (chatId != null && chatId.isNotEmpty) {
        onNotificationOpenedChat?.call(chatId, senderId ?? '');
      }
    } catch (e) {
      debugPrint('Error handling notification payload: $e');
    }
  }

  /// Formats push notification body text
  static String formatNotificationBody({
    required String senderFullName,
    required String senderUsername,
    required String messageContent,
    String? messageType,
  }) {
    String preview = messageContent;
    if (messageType == 'image') {
      preview = '📷 Rasm';
    } else if (messageType == 'video') {
      preview = '🎥 Video';
    } else if (messageType == 'voice') {
      preview = '🎤 Ovozli xabar';
    } else if (messageType == 'doc') {
      preview = '📄 Hujjat';
    }

    return '$senderFullName (@$senderUsername): $preview';
  }
}
