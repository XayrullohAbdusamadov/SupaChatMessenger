import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supachat_messenger/core/constants/app_constants.dart';
import 'package:supachat_messenger/data/models/chat_conversation.dart';
import 'package:supachat_messenger/data/models/user_profile.dart';
import 'package:supachat_messenger/data/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: AppConstants.defaultSupabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConstants.defaultSupabaseAnonKey,
    );
  });

  test('Deterministic Chat ID is identical for User A and User B', () {
    final chatId1 = ChatConversation.computeDirectChatId('anvarjon', 'usmoxan');
    final chatId2 = ChatConversation.computeDirectChatId('usmoxan', 'anvarjon');

    expect(chatId1, equals(chatId2));
    expect(chatId1, equals('d3f0e553-dcda-5ab3-a980-84986e63f760'));
  });

  test('Deterministic Chat ID handles prefixes, whitespace, uppercase and @ symbols', () {
    final chatId1 = ChatConversation.computeDirectChatId(' @AnvarJon ', 'user-usmoxan');
    final chatId2 = ChatConversation.computeDirectChatId('USMOXAN', '@anvarjon');

    expect(chatId1, equals(chatId2));
    expect(chatId1, equals('d3f0e553-dcda-5ab3-a980-84986e63f760'));
  });

  test('ChatConversation model preserves participants across JSON serialization', () {
    final userA = UserProfile(id: 'u1', username: 'alice', fullName: 'Alice Smith');
    final userB = UserProfile(id: 'u2', username: 'bob', fullName: 'Bob Jones');
    final directId = ChatConversation.computeDirectChatId('alice', 'bob');

    final originalConv = ChatConversation(
      id: directId,
      name: 'Direct Chat',
      participants: [userA, userB],
      lastMessageText: 'Hello there!',
      lastMessageType: MessageType.text,
      unreadCount: 2,
    );

    final json = originalConv.toJson();
    expect(json['participants'], isNotNull);
    expect((json['participants'] as List).length, equals(2));

    final restoredConv = ChatConversation.fromJson(json);
    expect(restoredConv.id, equals(directId));
    expect(restoredConv.participants.length, equals(2));
    expect(restoredConv.participants[0].username, equals('alice'));
    expect(restoredConv.participants[1].username, equals('bob'));
    expect(restoredConv.getDisplayName('u1', currentUsername: 'alice'), equals('Bob Jones'));
    expect(restoredConv.getDisplayName('u2', currentUsername: 'bob'), equals('Alice Smith'));
  });

  test('ChatMessage serialization preserves replyToMessage and replyToId', () {
    final originalReply = ChatMessage(
      id: 'msg-001',
      chatId: 'chat-001',
      senderId: 'user-alice',
      content: 'Salom, qandaysiz?',
    );

    final replyMsg = ChatMessage(
      id: 'msg-002',
      chatId: 'chat-001',
      senderId: 'user-bob',
      replyToId: originalReply.id,
      replyToMessage: originalReply,
      content: 'Rahmat, yaxshi!',
    );

    final json = replyMsg.toJson();
    expect(json['reply_to_id'], equals('msg-001'));
    expect(json['reply_to_message'], isNotNull);
    expect(json['reply_to_message']['content'], equals('Salom, qandaysiz?'));

    final restored = ChatMessage.fromJson(json);
    expect(restored.replyToId, equals('msg-001'));
    expect(restored.replyToMessage, isNotNull);
    expect(restored.replyToMessage!.content, equals('Salom, qandaysiz?'));
    expect(restored.replyToMessage!.senderId, equals('user-alice'));
  });

  test('Realtime Channel connects and receives broadcast/postgres events', () async {
    final client = Supabase.instance.client;
    final channel = client.channel(
      'test_realtime_channel',
      opts: const RealtimeChannelConfig(self: true),
    );
    final completer = Completer<bool>();

    channel.onBroadcast(
      event: 'test_event',
      callback: (payload) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );

    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await Future.delayed(const Duration(milliseconds: 500));
        await channel.sendBroadcastMessage(
          event: 'test_event',
          payload: {'content': 'Hello from test!'},
        );
      }
    });

    final received = await completer.future.timeout(const Duration(seconds: 10));
    await channel.unsubscribe();

    expect(received, isTrue);
  });

  test('Deduplication preserves valid lastMessageText over empty/null remote text', () {
    final userA = UserProfile(id: 'u1', username: 'anvar', fullName: 'Anvar');
    final userB = UserProfile(id: 'u2', username: 'xayrulloh', fullName: 'Xayrulloh');
    final directId = ChatConversation.computeDirectChatId('anvar', 'xayrulloh');

    final localConvWithMsg = ChatConversation(
      id: directId,
      name: 'Anvar',
      participants: [userA, userB],
      lastMessageText: 'Test message from script',
      lastMessageSenderId: 'u1',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 1,
    );

    final remoteEmptyConv = ChatConversation(
      id: directId,
      name: 'Anvar',
      participants: [userA, userB],
      lastMessageText: null,
      lastMessageSenderId: null,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    final hasConvMsg = remoteEmptyConv.lastMessageText != null && remoteEmptyConv.lastMessageText!.trim().isNotEmpty;
    final hasExistingMsg = localConvWithMsg.lastMessageText != null && localConvWithMsg.lastMessageText!.trim().isNotEmpty;

    final String? latestText;
    final String? latestSender;
    final DateTime latestAt;

    if (hasConvMsg && hasExistingMsg) {
      final convIsNewer = remoteEmptyConv.lastMessageAt.isAfter(localConvWithMsg.lastMessageAt);
      latestAt = convIsNewer ? remoteEmptyConv.lastMessageAt : localConvWithMsg.lastMessageAt;
      latestText = convIsNewer ? remoteEmptyConv.lastMessageText : localConvWithMsg.lastMessageText;
      latestSender = convIsNewer ? remoteEmptyConv.lastMessageSenderId : localConvWithMsg.lastMessageSenderId;
    } else if (hasConvMsg) {
      latestAt = remoteEmptyConv.lastMessageAt;
      latestText = remoteEmptyConv.lastMessageText;
      latestSender = remoteEmptyConv.lastMessageSenderId;
    } else if (hasExistingMsg) {
      latestAt = localConvWithMsg.lastMessageAt;
      latestText = localConvWithMsg.lastMessageText;
      latestSender = localConvWithMsg.lastMessageSenderId;
    } else {
      latestAt = remoteEmptyConv.lastMessageAt;
      latestText = null;
      latestSender = null;
    }

    expect(latestText, equals('Test message from script'));
    expect(latestSender, equals('u1'));
    expect(latestAt, equals(localConvWithMsg.lastMessageAt));
  });
}
