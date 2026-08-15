import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_conversation.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/call_overlay.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startCall(bool isVideo) {
    final contact = widget.conversation.participants.isNotEmpty
        ? widget.conversation.participants.first
        : UserProfile(
            id: 'demo-contact',
            username: widget.conversation.name.toLowerCase().replaceAll(' ', '_'),
            fullName: widget.conversation.name,
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallOverlay(
          contact: contact,
          isVideoCall: isVideo,
        ),
      ),
    );
  }

  void _showMediaGallery() {
    final messages = context.read<ChatProvider>().currentMessages;
    final mediaMsgs = messages.where((m) => m.messageType == MessageType.image || m.messageType == MessageType.doc).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Media va Hujjatlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (mediaMsgs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Hozircha hech qanday media yuborilmagan')),
                  )
                else
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: mediaMsgs.length,
                      itemBuilder: (c, idx) {
                        final m = mediaMsgs[idx];
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black12,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: m.messageType == MessageType.image && m.mediaUrl != null
                                ? CachedNetworkImage(imageUrl: m.mediaUrl!, fit: BoxFit.cover)
                                : Center(child: Text(m.fileName ?? m.content)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = authProvider.currentUser.id;
    final messages = chatProvider.currentMessages;

    final isOnline = !widget.conversation.isGroup &&
        widget.conversation.participants.isNotEmpty &&
        widget.conversation.participants.first.isOnline;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            chatProvider.closeChat();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            // AVATAR
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  backgroundImage: widget.conversation.avatarUrl != null
                      ? CachedNetworkImageProvider(widget.conversation.avatarUrl!)
                      : null,
                  child: widget.conversation.avatarUrl == null
                      ? Text(
                          widget.conversation.name.isNotEmpty
                              ? widget.conversation.name.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // NAME & STATUS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _isBlocked
                        ? 'Bloklangan'
                        : (widget.conversation.isTyping
                            ? 'Yozmoqda...'
                            : (widget.conversation.isGroup
                                ? '${widget.conversation.participants.length} ta a\'zo'
                                : (isOnline ? 'Online' : 'Yaqinda ko\'rilgan'))),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isBlocked
                          ? AppTheme.error
                          : (widget.conversation.isTyping
                              ? AppTheme.primary
                              : (isOnline ? AppTheme.tertiary : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Video Call Icon -> Full screen interactive video call
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video qo\'ng\'iroq',
            onPressed: () => _startCall(true),
          ),
          // Voice Call Icon -> Full screen interactive voice call
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            tooltip: 'Ovozli qo\'ng\'iroq',
            onPressed: () => _startCall(false),
          ),
          // More Menu (3 dots)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'media') {
                _showMediaGallery();
              } else if (val == 'clear') {
                chatProvider.clearChatHistory(widget.conversation.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Suhbat tarixi tozalandi!')),
                );
              } else if (val == 'delete') {
                chatProvider.deleteChat(widget.conversation.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat o\'chirib yuborildi')),
                );
              } else if (val == 'block') {
                setState(() {
                  _isBlocked = !_isBlocked;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_isBlocked ? 'Foydalanuvchi bloklandi' : 'Foydalanuvchi blokdan chiqarildi')),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'media',
                child: Row(
                  children: [
                    Icon(Icons.perm_media_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Media va hujjatlar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, size: 20, color: _isBlocked ? AppTheme.tertiary : AppTheme.warning),
                    const SizedBox(width: 10),
                    Text(_isBlocked ? 'Blokdan chiqarish' : 'Bloklash'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Tarixni tozalash'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, size: 20, color: AppTheme.error),
                    SizedBox(width: 10),
                    Text('Chatni o\'chirish', style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // MESSAGES LIST
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: messages.length + 1, // +1 for "Bugun" date badge header
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Date separator badge matching screenshot ("Bugun")
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Bugun',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                        ),
                      ),
                    ),
                  );
                }

                final msg = messages[index - 1];
                final isMe = msg.senderId == currentUserId;

                return MessageBubble(
                  message: msg,
                  isMe: isMe,
                  isVoicePlaying: chatProvider.currentlyPlayingVoiceMsgId == msg.id && chatProvider.isVoicePlaying,
                  voiceProgress: chatProvider.currentlyPlayingVoiceMsgId == msg.id ? chatProvider.voiceProgress : 0.0,
                  onVoicePlayToggle: () {
                    chatProvider.togglePlayVoice(msg.id, msg.voiceDuration ?? 14);
                  },
                  onReply: (m) => chatProvider.setReplyingTo(m),
                  onEdit: (m) => chatProvider.setEditingMessage(m),
                  onDelete: (m) {
                    setState(() {
                      messages.removeWhere((item) => item.id == m.id);
                    });
                  },
                );
              },
            ),
          ),

          // BOTTOM CHAT INPUT BAR (IF NOT BLOCKED)
          if (!_isBlocked)
            ChatInputBar(
              replyingTo: chatProvider.replyingToMessage,
              editingMessage: chatProvider.editingMessage,
              onCancelReplyOrEdit: () => chatProvider.cancelReplyOrEdit(),
              onSendText: (text) {
                chatProvider.sendMessage(
                  senderId: currentUserId,
                  content: text,
                  type: MessageType.text,
                );
                Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
              },
              onSendMedia: (path, bytes, name, size, type) {
                chatProvider.sendMessage(
                  senderId: currentUserId,
                  content: name,
                  type: type,
                  mediaUrl: 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?w=800&auto=format&fit=crop&q=80',
                  fileName: name,
                  mediaSize: size,
                );
                Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
              },
              onSendVoice: (durationSeconds) {
                chatProvider.sendMessage(
                  senderId: currentUserId,
                  content: 'Voice message',
                  type: MessageType.voice,
                  voiceDuration: durationSeconds,
                );
                Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.error.withValues(alpha: 0.1),
              child: const Center(
                child: Text(
                  'Foydalanuvchi bloklangan. Xabar yuborib bo\'lmaydi.',
                  style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
