import 'user_profile.dart';
import 'chat_message.dart';

class ChatConversation {
  final String id;
  final bool isGroup;
  final String name;
  final String? avatarUrl;
  final String? createdBy;
  final List<String> adminIds;
  final List<String> blockedMemberIds;
  final List<UserProfile> participants;
  final ChatMessage? lastMessage;
  final String? lastMessageText;
  final MessageType? lastMessageType;
  final String? lastMessageSenderId;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isTyping;
  final String? typingUserName;
  final String? draftMessage;

  ChatConversation({
    required this.id,
    this.isGroup = false,
    required this.name,
    this.avatarUrl,
    this.createdBy,
    this.adminIds = const [],
    this.blockedMemberIds = const [],
    this.participants = const [],
    this.lastMessage,
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageSenderId,
    DateTime? lastMessageAt,
    this.unreadCount = 0,
    this.isTyping = false,
    this.typingUserName,
    this.draftMessage,
  }) : lastMessageAt = lastMessageAt ?? DateTime.now();

  bool isOwner(String userId) => createdBy == userId;
  bool isAdmin(String userId) => isOwner(userId) || adminIds.contains(userId);
  bool isMemberBlocked(String userId) => blockedMemberIds.contains(userId);

  String getDisplayName(String? currentUserId, {String? currentUsername}) {
    if (isGroup) return name;
    if (id.startsWith('saved_messages')) return 'Saqlangan xabarlar 📌';

    if (participants.isNotEmpty) {
      final others = participants.where((p) {
        if (currentUserId != null && currentUserId.isNotEmpty && p.id == currentUserId) return false;
        if (currentUsername != null && currentUsername.isNotEmpty && p.username.toLowerCase() == currentUsername.toLowerCase()) return false;
        return true;
      }).toList();

      if (others.isNotEmpty) {
        final other = others.first;
        if (other.fullName.isNotEmpty) return other.fullName;
        if (other.username.isNotEmpty) return other.username;
      }
    }

    if (currentUsername != null && currentUsername.isNotEmpty && name.toLowerCase() == currentUsername.toLowerCase()) {
      if (participants.isNotEmpty && participants.first.fullName.isNotEmpty) {
        return participants.first.fullName;
      }
    }

    return name;
  }

  String? getDisplayAvatar(String? currentUserId, {String? currentUsername}) {
    if (isGroup) return avatarUrl;
    if (id.startsWith('saved_messages')) return avatarUrl;

    if (participants.isNotEmpty) {
      final others = participants.where((p) {
        if (currentUserId != null && currentUserId.isNotEmpty && p.id == currentUserId) return false;
        if (currentUsername != null && currentUsername.isNotEmpty && p.username.toLowerCase() == currentUsername.toLowerCase()) return false;
        return true;
      }).toList();

      if (others.isNotEmpty) {
        return others.first.avatarUrl ?? avatarUrl;
      }
    }
    return avatarUrl;
  }

  UserProfile? getOtherParticipant(String? currentUserId, {String? currentUsername}) {
    if (isGroup || participants.isEmpty) return null;
    final others = participants.where((p) {
      if (currentUserId != null && currentUserId.isNotEmpty && p.id == currentUserId) return false;
      if (currentUsername != null && currentUsername.isNotEmpty && p.username.toLowerCase() == currentUsername.toLowerCase()) return false;
      return true;
    }).toList();

    if (others.isNotEmpty) return others.first;
    return participants.first;
  }

  factory ChatConversation.fromJson(
    Map<String, dynamic> json, {
    List<UserProfile> participants = const [],
    ChatMessage? lastMessage,
  }) {
    return ChatConversation(
      id: json['id'] as String,
      isGroup: json['is_group'] as bool? ?? false,
      name: json['group_name'] as String? ?? 'Chat',
      avatarUrl: json['group_avatar'] as String?,
      createdBy: json['created_by'] as String?,
      adminIds: (json['admin_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      blockedMemberIds: (json['blocked_member_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      participants: participants,
      lastMessage: lastMessage,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageType: json['last_message_type'] != null
          ? MessageType.values.firstWhere(
              (e) => e.name == json['last_message_type'],
              orElse: () => MessageType.text,
            )
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
      draftMessage: json['draft_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_group': isGroup,
      'group_name': name,
      'group_avatar': avatarUrl,
      'created_by': createdBy,
      'admin_ids': adminIds,
      'blocked_member_ids': blockedMemberIds,
      'last_message_text': lastMessageText,
      'last_message_type': lastMessageType?.name,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_at': lastMessageAt.toIso8601String(),
    };
  }

  ChatConversation copyWith({
    String? id,
    bool? isGroup,
    String? name,
    String? avatarUrl,
    String? createdBy,
    List<String>? adminIds,
    List<String>? blockedMemberIds,
    List<UserProfile>? participants,
    ChatMessage? lastMessage,
    String? lastMessageText,
    MessageType? lastMessageType,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isTyping,
    String? typingUserName,
    String? draftMessage,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy ?? this.createdBy,
      adminIds: adminIds ?? this.adminIds,
      blockedMemberIds: blockedMemberIds ?? this.blockedMemberIds,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isTyping: isTyping ?? this.isTyping,
      typingUserName: typingUserName ?? this.typingUserName,
      draftMessage: draftMessage ?? this.draftMessage,
    );
  }
}
