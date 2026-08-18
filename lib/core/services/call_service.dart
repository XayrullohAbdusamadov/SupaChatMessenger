import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/call_model.dart';
import '../../data/models/user_profile.dart';
import 'supabase_service.dart';

class CallService extends ChangeNotifier {
  static final CallService instance = CallService._internal();
  CallService._internal();

  final SupabaseService _supabaseService = SupabaseService.instance;
  final Uuid _uuid = const Uuid();

  CallModel? _currentCall;
  bool _isIncoming = false;
  RealtimeChannel? _callsSubscription;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;

  CallModel? get currentCall => _currentCall;
  bool get isIncoming => _isIncoming;
  bool get isInCall => _currentCall != null && _currentCall!.status == CallStatus.accepted;
  bool get isRinging => _currentCall != null && _currentCall!.status == CallStatus.ringing;
  int get callDurationSeconds => _callDurationSeconds;

  void initializeForUser(String userId) {
    _callsSubscription?.unsubscribe();
    _callsSubscription = _supabaseService.subscribeToUserCalls(
      userId,
      onIncomingCall: (call) {
        if (_currentCall == null) {
          _currentCall = call;
          _isIncoming = true;
          notifyListeners();
        }
      },
      onCallStatusChanged: (callId, status) {
        if (_currentCall != null && _currentCall!.id == callId) {
          if (status == CallStatus.accepted) {
            _currentCall = _currentCall!.copyWith(status: CallStatus.accepted, startedAt: DateTime.now());
            _startDurationTimer();
          } else if (status == CallStatus.rejected || status == CallStatus.ended || status == CallStatus.missed) {
            _endActiveCallLocally();
          }
          notifyListeners();
        }
      },
    );
  }

  Future<CallModel> startCall({
    required UserProfile caller,
    required UserProfile receiver,
    required String chatId,
    required bool isVideo,
  }) async {
    final callId = _uuid.v4();
    final call = CallModel(
      id: callId,
      callerId: caller.id,
      callerName: caller.fullName.isNotEmpty ? caller.fullName : caller.username,
      callerAvatarUrl: caller.avatarUrl,
      receiverId: receiver.id,
      receiverName: receiver.fullName.isNotEmpty ? receiver.fullName : receiver.username,
      receiverAvatarUrl: receiver.avatarUrl,
      chatId: chatId,
      callType: isVideo ? CallType.video : CallType.audio,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );

    _currentCall = call;
    _isIncoming = false;
    _callDurationSeconds = 0;
    notifyListeners();

    await _supabaseService.createCall(call);
    return call;
  }

  Future<void> acceptCall() async {
    if (_currentCall == null) return;
    _currentCall = _currentCall!.copyWith(
      status: CallStatus.accepted,
      startedAt: DateTime.now(),
    );
    _isIncoming = false;
    _startDurationTimer();
    notifyListeners();

    await _supabaseService.updateCallStatus(
      callId: _currentCall!.id,
      status: CallStatus.accepted,
      startedAt: _currentCall!.startedAt,
    );
  }

  Future<void> rejectCall() async {
    if (_currentCall == null) return;
    final callId = _currentCall!.id;
    _endActiveCallLocally();

    await _supabaseService.updateCallStatus(
      callId: callId,
      status: CallStatus.rejected,
      endedAt: DateTime.now(),
      duration: 0,
    );
  }

  Future<void> endCall() async {
    if (_currentCall == null) return;
    final callId = _currentCall!.id;
    final duration = _callDurationSeconds;
    _endActiveCallLocally();

    await _supabaseService.updateCallStatus(
      callId: callId,
      status: CallStatus.ended,
      endedAt: DateTime.now(),
      duration: duration,
    );
  }

  void _startDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationSeconds = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _endActiveCallLocally() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    _currentCall = null;
    _isIncoming = false;
    _callDurationSeconds = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _callDurationTimer?.cancel();
    _callsSubscription?.unsubscribe();
    super.dispose();
  }
}
