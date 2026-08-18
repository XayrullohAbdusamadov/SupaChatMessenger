import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:supachat_messenger/core/constants/app_constants.dart';

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
    const uuid = Uuid();
    final userA = 'anvarjon'.trim().toLowerCase().replaceAll('@', '');
    final userB = 'usmoxan'.trim().toLowerCase().replaceAll('@', '');

    final sorted1 = [userA, userB]..sort();
    final chatId1 = uuid.v5(Namespace.url.value, 'supachat:direct:${sorted1.join(':')}');

    final sorted2 = [userB, userA]..sort();
    final chatId2 = uuid.v5(Namespace.url.value, 'supachat:direct:${sorted2.join(':')}');

    expect(chatId1, equals(chatId2));
    expect(chatId1, equals('d3f0e553-dcda-5ab3-a980-84986e63f760'));
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
