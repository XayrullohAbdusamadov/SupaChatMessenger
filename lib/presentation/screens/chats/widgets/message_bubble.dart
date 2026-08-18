import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/chat_message.dart';
import '../../../../providers/chat_provider.dart';
import 'voice_message_player.dart';
import 'media_attachment_card.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isGroup;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool isGroupOwner;
  final bool isGroupAdmin;
  final bool isVoicePlaying;
  final double voiceProgress;
  final VoidCallback onVoicePlayToggle;
  final Function(ChatMessage) onReply;
  final Function(ChatMessage) onEdit;
  final Function(ChatMessage) onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    this.senderName,
    this.senderAvatarUrl,
    this.isGroupOwner = false,
    this.isGroupAdmin = false,
    required this.isVoicePlaying,
    required this.voiceProgress,
    required this.onVoicePlayToggle,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // INCOMING GROUP MESSAGE: SHOW SENDER AVATAR ON THE LEFT
          if (!isMe && isGroup) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: ClipOval(
                child: AvatarHelper.buildAvatarWidget(
                  avatarUrl: senderAvatarUrl,
                  name: senderName ?? 'A\'zo',
                  radius: 15,
                ),
              ),
            ),
          ],

          // Outgoing message inline actions on left
          if (isMe) ...[
            _buildInlineQuickActions(context, isDark),
            const SizedBox(width: 6),
          ],

          // MESSAGE BUBBLE CONTAINER
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.outgoingBubble
                      : (isDark ? AppTheme.incomingBubbleDark : AppTheme.incomingBubbleLight),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // INCOMING GROUP MESSAGE: SENDER NAME HEADER
                      if (!isMe && isGroup && senderName != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                          child: Text(
                            senderName!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),

                      // REPLY PREVIEW IF ANY
                      if (message.replyToMessage != null)
                        _buildReplyPreview(context, message.replyToMessage!, isDark),

                      // BODY CONTENT BY TYPE
                      if (message.messageType == MessageType.voice)
                        VoiceMessagePlayer(
                          messageId: message.id,
                          durationSeconds: message.voiceDuration ?? 14,
                          isPlaying: isVoicePlaying,
                          progress: voiceProgress,
                          isMe: isMe,
                          createdAt: message.createdAt,
                          onPlayToggle: onVoicePlayToggle,
                        )
                      else if (message.messageType == MessageType.image || message.messageType == MessageType.video || message.messageType == MessageType.doc)
                        MediaAttachmentCard(
                          message: message,
                          isMe: isMe,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isMe
                                      ? Colors.white
                                      : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary),
                                  height: 1.38,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (message.isEdited) ...[
                                    Text(
                                      'tahrirlangan',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: isMe ? Colors.white70 : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    DateFormatter.formatMessageTime(message.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white70
                                          : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    _buildStatusIcon(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      // TELEGRAM STYLE REACTION BADGES ATTACHED TO BUBBLE
                      _buildTelegramReactionBadges(context, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Incoming message inline actions on right
          if (!isMe) ...[
            const SizedBox(width: 6),
            _buildInlineQuickActions(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineQuickActions(BuildContext context, bool isDark) {
    final iconColor = isDark ? Colors.white54 : Colors.black45;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _showMessageOptions(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.more_vert_rounded, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: () => onReply(message),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.reply_rounded, size: 18, color: iconColor),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context, ChatMessage reply, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.15) : (isDark ? Colors.black26 : Colors.black12),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : AppTheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? 'Siz' : 'Ishtirokchi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : AppTheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 13, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
    }
  }

  void _showMessageOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (pickerCtx) {
                  final currentUserId = pickerCtx.read<ChatProvider>().currentActiveUserId ?? '';
                  final currentReactions = message.reactions;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['❤️', '👍', '🔥', '😂', '😮', '😢', '🙏', '🎉', '👏', '⚡'].map((emoji) {
                          final userToken = currentUserId.isNotEmpty ? '$emoji:$currentUserId' : emoji;
                          final isSelected = currentReactions.contains(userToken) || currentReactions.contains(emoji);

                          return GestureDetector(
                            onTap: () {
                              pickerCtx.read<ChatProvider>().toggleReaction(
                                messageId: message.id,
                                emoji: emoji,
                                userId: currentUserId,
                              );
                              Navigator.pop(ctx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (message.content.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? AppTheme.primary : AppTheme.secondary,
                        width: 3.5,
                      ),
                    ),
                  ),
                  child: Text(
                    message.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Column(
                children: [
                  _buildInstagramOptionTile(
                    context: context,
                    icon: Icons.reply_rounded,
                    iconBgColor: AppTheme.primary.withValues(alpha: 0.15),
                    iconColor: AppTheme.primary,
                    title: "Javob berish (Reply)",
                    subtitle: "Xabarga iqtibos bilan javob berish",
                    onTap: () {
                      Navigator.pop(ctx);
                      onReply(message);
                    },
                  ),
                  if (isMe && message.messageType == MessageType.text) ...[
                    const SizedBox(height: 8),
                    _buildInstagramOptionTile(
                      context: context,
                      icon: Icons.edit_rounded,
                      iconBgColor: Colors.amber.withValues(alpha: 0.15),
                      iconColor: Colors.amber[800]!,
                      title: "Tahrirlash (Edit)",
                      subtitle: "Xabar matnini o'zgartirish",
                      onTap: () {
                        Navigator.pop(ctx);
                        onEdit(message);
                      },
                    ),
                  ],
                  if (message.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInstagramOptionTile(
                      context: context,
                      icon: Icons.copy_rounded,
                      iconBgColor: Colors.teal.withValues(alpha: 0.15),
                      iconColor: Colors.teal,
                      title: "Nusxa olish (Copy)",
                      subtitle: "Xabar matnidan nusxa nusxalash",
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Xabardan nusxa olindi 📋"),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ],
                  if (isMe || isGroupOwner || isGroupAdmin) ...[
                    const SizedBox(height: 8),
                    _buildInstagramOptionTile(
                      context: context,
                      icon: Icons.delete_outline_rounded,
                      iconBgColor: AppTheme.error.withValues(alpha: 0.15),
                      iconColor: AppTheme.error,
                      title: isMe
                          ? "O'chirish (Delete)"
                          : (isGroupOwner ? "Egasi sifatida o'chirish" : "Admin sifatida o'chirish"),
                      subtitle: "Xabarni suhbatdan o'chirib tashlash",
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        onDelete(message);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstagramOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? AppTheme.error
                            : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white30 : Colors.black26,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramReactionBadges(BuildContext context, bool isDark) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    final currentUserId = context.read<ChatProvider>().currentActiveUserId ?? '';

    // Group reactions by emoji
    final Map<String, List<String>> emojiUserMap = {};
    for (var r in message.reactions) {
      String emoji = r;
      String uid = '';
      if (r.contains(':')) {
        final parts = r.split(':');
        emoji = parts[0];
        uid = parts.sublist(1).join(':');
      }
      emojiUserMap.putIfAbsent(emoji, () => []).add(uid);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 6, top: 4),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: emojiUserMap.entries.map((entry) {
          final emoji = entry.key;
          final userList = entry.value;
          final count = userList.length;
          final bool isSelectedByMe = currentUserId.isNotEmpty && userList.contains(currentUserId);

          return GestureDetector(
            onTap: () {
              context.read<ChatProvider>().toggleReaction(
                    messageId: message.id,
                    emoji: emoji,
                    userId: currentUserId,
                  );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: isSelectedByMe
                    ? (isMe ? Colors.white.withValues(alpha: 0.32) : AppTheme.primary.withValues(alpha: 0.2))
                    : (isMe
                        ? Colors.white.withValues(alpha: 0.16)
                        : (isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelectedByMe
                      ? (isMe ? Colors.white : AppTheme.primary)
                      : (isMe ? Colors.white24 : (isDark ? Colors.white12 : Colors.black12)),
                  width: isSelectedByMe ? 1.4 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSelectedByMe
                          ? (isMe ? Colors.white : AppTheme.primary)
                          : (isMe ? Colors.white70 : (isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
