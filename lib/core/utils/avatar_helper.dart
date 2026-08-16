import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarHelper {
  static ImageProvider? getImageProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    final url = avatarUrl.trim();
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final base64Str = url.substring(commaIdx + 1);
          final bytes = base64Decode(base64Str);
          return MemoryImage(bytes);
        }
      } catch (e) {
        return null;
      }
    }
    return CachedNetworkImageProvider(url);
  }

  static Widget buildAvatarWidget({
    required String? avatarUrl,
    required String name,
    double radius = 24,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    final imageProvider = getImageProvider(avatarUrl);
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.blue.withValues(alpha: 0.15),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
                color: iconColor ?? Colors.blue,
              ),
            )
          : null,
    );
  }
}
