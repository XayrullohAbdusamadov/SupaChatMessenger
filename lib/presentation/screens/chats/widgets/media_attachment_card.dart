import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/chat_message.dart';
import 'full_screen_image_viewer.dart';
import 'full_screen_video_viewer.dart';

class MediaAttachmentCard extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MediaAttachmentCard({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (message.messageType == MessageType.image) {
      return _buildImageCard(context);
    } else if (message.messageType == MessageType.video) {
      return _buildVideoCard(context);
    } else {
      return _buildDocumentCard(context);
    }
  }

  Widget _buildImageCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
        ? message.mediaUrl!
        : 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?w=800&auto=format&fit=crop&q=80';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: imageUrl,
              title: message.fileName ?? message.content,
            ),
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: isMe ? AppTheme.outgoingBubble : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.startsWith('data:image'))
                      Image.memory(
                        base64Decode(imageUrl.substring(imageUrl.indexOf(',') + 1)),
                        fit: BoxFit.cover,
                        errorBuilder: (c, err, stack) => _buildErrorWidget(isDark, false),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (c, url) => Container(
                          color: isDark ? AppTheme.cardDark : AppTheme.inputBgLight,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          ),
                        ),
                        errorWidget: (c, url, err) => _buildErrorWidget(isDark, false),
                      ),

                    // Bottom gradient shadow overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer with file name & time
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        message.fileName ?? (message.content.isNotEmpty ? message.content : 'Rasm'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatter.formatMessageTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final videoUrl = message.mediaUrl ?? 'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenVideoViewer(
              videoUrl: videoUrl,
              title: message.fileName ?? message.content,
            ),
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: isMe ? AppTheme.outgoingBubble : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFF1E293B),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                    ),

                    // Top Left Video Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Video', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        message.fileName ?? (message.content.isNotEmpty ? message.content : 'Video xabar'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatter.formatMessageTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark, bool isVideo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.secondary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.image_rounded,
            size: 44,
            color: isMe ? Colors.white70 : AppTheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            message.fileName ?? message.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = message.fileName ?? message.content;
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isZip = fileName.toLowerCase().endsWith('.zip');

    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : (isDark ? AppTheme.surfaceDark : AppTheme.cardLight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? Colors.white24 : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPdf
                  ? Colors.red.withValues(alpha: 0.2)
                  : (isZip ? Colors.amber.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : (isZip ? Icons.folder_zip_rounded : Icons.description_rounded),
              color: isPdf ? Colors.red : (isZip ? Colors.amber[800] : AppTheme.primary),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.formatFileSize(message.mediaSize),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
