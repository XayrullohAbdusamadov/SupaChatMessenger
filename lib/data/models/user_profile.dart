class UserProfile {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String about;
  final String? role; // e.g. "Software Engineer", "UI/UX Designer", "Project Manager"
  final bool isOnline;
  final DateTime lastSeen;
  final String? fcmToken;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.about = 'Hey there! I am using SupaChat.',
    this.role,
    this.isOnline = false,
    DateTime? lastSeen,
    this.fcmToken,
    DateTime? createdAt,
  })  : lastSeen = lastSeen ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'user',
      fullName: json['full_name'] as String? ?? 'SupaChat User',
      avatarUrl: json['avatar_url'] as String?,
      about: json['about'] as String? ?? 'Hey there! I am using SupaChat.',
      role: json['role'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fcmToken: json['fcm_token'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'about': about,
      'is_online': isOnline,
      'last_seen': lastSeen.toIso8601String(),
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? about,
    String? role,
    bool? isOnline,
    DateTime? lastSeen,
    String? fcmToken,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      about: about ?? this.about,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
    );
  }
}
