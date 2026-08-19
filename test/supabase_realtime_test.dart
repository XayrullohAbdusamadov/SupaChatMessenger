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
}
