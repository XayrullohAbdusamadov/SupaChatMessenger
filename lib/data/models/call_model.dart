enum CallType {
  audio,
  video,
}

enum CallStatus {
  ringing,
  accepted,
  rejected,
  ended,
  missed,
  busy,
}

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatarUrl;
  final String chatId;
  final CallType callType;
  final CallStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int duration;
  final DateTime createdAt;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatarUrl,
    required this.chatId,
    required this.callType,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.duration = 0,
    required this.createdAt,
  });

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerAvatarUrl,
    String? receiverId,
    String? receiverName,
    String? receiverAvatarUrl,
    String? chatId,
    CallType? callType,
    CallStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
    DateTime? createdAt,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatarUrl: callerAvatarUrl ?? this.callerAvatarUrl,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatarUrl: receiverAvatarUrl ?? this.receiverAvatarUrl,
      chatId: chatId ?? this.chatId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_avatar_url': callerAvatarUrl,
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'receiver_avatar_url': receiverAvatarUrl,
      'chat_id': chatId,
      'call_type': callType.name,
      'status': status.name,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      callerName: json['caller_name'] as String? ?? 'User',
      callerAvatarUrl: json['caller_avatar_url'] as String?,
      receiverId: json['receiver_id'] as String,
      receiverName: json['receiver_name'] as String? ?? 'User',
      receiverAvatarUrl: json['receiver_avatar_url'] as String?,
      chatId: json['chat_id'] as String? ?? '',
      callType: json['call_type'] == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CallStatus.ringing,
      ),
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'].toString()) : null,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
