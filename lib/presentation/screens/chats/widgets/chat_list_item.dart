import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/chat_conversation.dart';

class ChatListItem extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // AVATAR
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conversation.isGroup
                        ? AppTheme.secondary.withValues(alpha: 0.15)
                        : AppTheme.primary.withValues(alpha: 0.1),
                  ),
                  child: ClipOval(
                    child: AvatarHelper.buildAvatarWidget(
                      avatarUrl: conversation.avatarUrl,
                      name: conversation.name,
                      radius: 26,
                    ),
                  ),
                ),
                if (!conversation.isGroup &&
                    conversation.participants.isNotEmpty &&
                    conversation.participants.first.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.formatChatTime(conversation.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: conversation.unreadCount > 0
                              ? AppTheme.primary
                              : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                          fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubtitle(isDark),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSubtitle(bool isDark) {
    if (conversation.isTyping) {
      return Row(
        children: [
          const Text(
            'Typing',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '...',
            style: TextStyle(
              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    if (conversation.draftMessage != null && conversation.draftMessage!.isNotEmpty) {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text: 'DRAFT: ',
          style: const TextStyle(
            color: AppTheme.error,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: conversation.draftMessage,
              style: TextStyle(
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      conversation.lastMessageText ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
      ),
    );
  }
}
