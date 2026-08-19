enum MessageType {
  text,
  image,
  video,
  voice,
  doc,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? receiverId;  // For 1-on-1 chats: the other participant's UUID
  final String? replyToId;
  final ChatMessage? replyToMessage;
  final MessageType messageType;
  final String content;
  final String? mediaUrl;
  final int? mediaSize; // in bytes
  final String? fileName;
  final int? voiceDuration; // in seconds (for voice messages)
  final MessageStatus status;
  final bool isEdited;
  final bool isDeleted;
  final List<String> reactions;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.receiverId,
    this.replyToId,
    this.replyToMessage,
    this.messageType = MessageType.text,
    this.content = '',
    this.mediaUrl,
    this.mediaSize,
    this.fileName,
    this.voiceDuration,
    this.status = MessageStatus.sent,
    this.isEdited = false,
    this.isDeleted = false,
    List<String>? reactions,
    DateTime? createdAt,
  })  : reactions = reactions ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json, {ChatMessage? replyMessage}) {
    MessageType type = MessageType.text;
    final typeStr = json['message_type'] as String? ?? 'text';
    switch (typeStr.toLowerCase()) {
      case 'image':
        type = MessageType.image;
        break;
      case 'video':
        type = MessageType.video;
        break;
      case 'voice':
        type = MessageType.voice;
        break;
      case 'doc':
      case 'file':
        type = MessageType.doc;
        break;
      default:
        type = MessageType.text;
    }

    MessageStatus stat = MessageStatus.sent;
    final statStr = json['status'] as String? ?? 'sent';
    switch (statStr.toLowerCase()) {
      case 'sending':
        stat = MessageStatus.sending;
        break;
      case 'delivered':
        stat = MessageStatus.delivered;
        break;
      case 'read':
        stat = MessageStatus.read;
        break;
      default:
        stat = MessageStatus.sent;
    }

    List<String> reactList = [];
    if (json['reactions'] != null && json['reactions'] is List) {
      reactList = List<String>.from(json['reactions']);
    }

    ChatMessage? replyMsg;
    if (json['reply_to_message'] != null && json['reply_to_message'] is Map) {
      try {
        replyMsg = ChatMessage.fromJson(Map<String, dynamic>.from(json['reply_to_message']));
      } catch (_) {}
    }
    replyMsg ??= replyMessage;

    return ChatMessage(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String?,
      replyToId: json['reply_to_id'] as String?,
      replyToMessage: replyMsg,
      messageType: type,
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      mediaSize: json['media_size'] as int?,
      fileName: json['file_name'] as String?,
      voiceDuration: json['voice_duration'] as int?,
      status: stat,
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      reactions: reactList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'reply_to_id': replyToId,
      'reply_to_message': replyToMessage?.toJson(),
      'message_type': messageType.name,
      'content': content,
      'media_url': mediaUrl,
      'media_size': mediaSize,
      'file_name': fileName,
      'voice_duration': voiceDuration,
      'status': status.name,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'reactions': reactions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      'reply_to_id': replyToId,
      'message_type': messageType.name,
      'content': content,
      'media_url': mediaUrl,
      'media_size': mediaSize,
      'file_name': fileName,
      'voice_duration': voiceDuration,
      'status': status.name,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'reactions': reactions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? replyToId,
    ChatMessage? replyToMessage,
    MessageType? messageType,
    String? content,
    String? mediaUrl,
    int? mediaSize,
    String? fileName,
    int? voiceDuration,
    MessageStatus? status,
    bool? isEdited,
    bool? isDeleted,
    List<String>? reactions,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      replyToId: replyToId ?? this.replyToId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaSize: mediaSize ?? this.mediaSize,
      fileName: fileName ?? this.fileName,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
