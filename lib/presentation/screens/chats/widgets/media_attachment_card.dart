import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/chat_message.dart';

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
    } else {
      return _buildDocumentCard(context);
    }
  }

  Widget _buildImageCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
        ? message.mediaUrl!
        : 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?w=800&auto=format&fit=crop&q=80';

    return Container(
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
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, url) => Container(
                      color: isDark ? AppTheme.cardDark : AppTheme.inputBgLight,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                    ),
                    errorWidget: (c, url, err) => Container(
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
                            Icons.image_rounded,
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
                    ),
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
