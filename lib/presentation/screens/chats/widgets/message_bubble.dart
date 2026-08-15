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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(context),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
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
                  else if (message.messageType == MessageType.image || message.messageType == MessageType.doc)
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppTheme.primary),
                title: const Text("Iqtibos bilan javob berish (Reply)"),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply(message);
                },
              ),
              if (message.content.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text("Nusxa olish (Copy)"),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Xabardan nusxa olindi"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              if (isMe && message.messageType == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text("Tahrirlash (Edit)"),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit(message);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                  title: const Text("O'chirish (Delete)", style: TextStyle(color: AppTheme.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
