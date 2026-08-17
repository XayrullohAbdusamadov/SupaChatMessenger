import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/chat_message.dart';
import 'voice_message_player.dart';
import 'media_attachment_card.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // If outgoing message (isMe), place inline quick actions on the LEFT side of bubble
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
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
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
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
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
                    ],
                  ),
                ),
              ),
            ),
          ),

          // If incoming message (!isMe), place inline quick actions on the RIGHT side of bubble
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
        // 1. Vertical 3 dots options (⋮)
        InkWell(
          onTap: () => _showMessageOptions(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.more_vert_rounded, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(width: 2),
        // 2. Reply arrow (↩)
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
              // Top drag indicator handle
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

              // INSTAGRAM QUICK REACTION EMOJIS BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['❤️', '😂', '😮', '😢', '🙏', '👍'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$emoji Reaksiya qoldirildi'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Message snippet preview
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

              // ACTION BUTTONS GRID / LIST (Instagram style cards)
              Column(
                children: [
                  // REPLY
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

                  // EDIT (for sender)
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

                  // COPY
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

                  // DELETE
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
}
