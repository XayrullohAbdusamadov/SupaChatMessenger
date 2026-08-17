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
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final double size = radius * 2;
    final url = avatarUrl?.trim();

    Widget placeholder = Container(
      width: size,
      height: size,
      color: backgroundColor ?? Colors.blue.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.85,
            color: iconColor ?? Colors.blue,
          ),
        ),
      ),
    );

    if (url == null || url.isEmpty) {
      return ClipOval(child: placeholder);
    }

    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final base64Str = url.substring(commaIdx + 1);
          final bytes = base64Decode(base64Str);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (c, err, stack) => placeholder,
            ),
          );
        }
      } catch (e) {
        return ClipOval(child: placeholder);
      }
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
      ),
    );
  }
}
