class UserStory {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String mediaUrl;
  final bool isVideo;
  final String? caption;
  final DateTime createdAt;

  UserStory({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.mediaUrl,
    this.isVideo = false,
    this.caption,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'media_url': mediaUrl,
      'is_video': isVideo,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserStory.fromJson(Map<String, dynamic> json) {
    return UserStory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Foydalanuvchi',
      userAvatar: json['user_avatar'] as String?,
      mediaUrl: json['media_url'] as String,
      isVideo: json['is_video'] as bool? ?? false,
      caption: json['caption'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}
