import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../data/models/chat_conversation.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/call_overlay.dart';
import 'widgets/group_admin_panel_dialog.dart';

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

  // 1. NATIVE VOICE CALL HANDLER
  Future<void> _makeNativePhoneCall(UserProfile contact) async {
    final phone = contact.phoneNumber.replaceAll(' ', '').trim();
    final Uri url = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Telefon xizmatiga ulanib bo'lmadi: $phone")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Qo'ng'iroq qilinmoqda: $phone")),
        );
      }
    }
  }

  // 2. VIDEO CALL HANDLER WITH OFFLINE CHECK
  void _startVideoCall(UserProfile contact) {
    if (contact.isOnline) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallOverlay(
            contact: contact,
            isVideoCall: true,
          ),
        ),
      );
    } else {
      // OFFLINE FALLBACK DIALOG
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_off_rounded, color: Colors.orange, size: 36),
          ),
          title: const Text('Foydalanuvchi tarmoqda emas', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text(
            '${contact.fullName} hozirda oflayn bo\'lganligi sababli video qo\'ng\'iroq qilib bo\'lmaydi.\n\nIltimos oddiy qo\'ng\'iroq tizimidan foydalaning.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: const Text('Oddiy qo\'ng\'iroq'),
              onPressed: () {
                Navigator.pop(ctx);
                _makeNativePhoneCall(contact);
              },
            ),
          ],
        ),
      );
    }
  }

  void _confirmDeleteChat(BuildContext context, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 40),
        title: const Text("Chatni o'chirish", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Ushbu suhbat va unga tegishli barcha xabarlar butunlay o'chirib yuboriladi. Davom etasizmi?",
          textAlign: TextAlign.center,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              chatProvider.deleteChatCompletely(widget.conversation.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat butunlay o\'chirildi')),
              );
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  void _showMediaGallery() {
    final messages = context.read<ChatProvider>().currentMessages;
    final mediaMsgs = messages.where((m) => m.messageType == MessageType.image || m.messageType == MessageType.video || m.messageType == MessageType.doc).toList();

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

    // Active conversation
    final activeConv = chatProvider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );

    final contact = activeConv.participants.isNotEmpty
        ? activeConv.participants.first
        : UserProfile(
            id: 'demo-contact',
            username: activeConv.name.toLowerCase().replaceAll(' ', '_'),
            fullName: activeConv.name,
          );

    final isBlocked = !activeConv.isGroup && chatProvider.isUserBlocked(contact.id);
    final isOnline = !activeConv.isGroup && contact.isOnline && !isBlocked;
    final isGroupOwner = activeConv.isGroup && activeConv.isOwner(currentUserId);
    final isGroupAdmin = activeConv.isGroup && activeConv.isAdmin(currentUserId);

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
                AvatarHelper.buildAvatarWidget(
                  avatarUrl: activeConv.avatarUrl,
                  name: activeConv.name,
                  radius: 19,
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
                    activeConv.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isBlocked
                        ? 'Bloklangan'
                        : (activeConv.isTyping
                            ? 'Yozmoqda...'
                            : (activeConv.isGroup
                                ? '${activeConv.participants.length} ta a\'zo'
                                : (isOnline ? 'Online' : 'Yaqinda ko\'rilgan'))),
                    style: TextStyle(
                      fontSize: 12,
                      color: isBlocked
                          ? AppTheme.error
                          : (activeConv.isTyping
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
          // Video Call Icon -> Full screen interactive video call / offline check
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video qo\'ng\'iroq',
            onPressed: () => _startVideoCall(contact),
          ),
          // Voice Call Icon -> Native phone call service
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            tooltip: 'Oddiy qo\'ng\'iroq',
            onPressed: () => _makeNativePhoneCall(contact),
          ),
          // More Menu (3 dots)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'admin_panel') {
                showDialog(
                  context: context,
                  builder: (_) => GroupAdminPanelDialog(conversation: activeConv),
                );
              } else if (val == 'media') {
                _showMediaGallery();
              } else if (val == 'clear') {
                chatProvider.clearChatHistory(activeConv.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Suhbat tarixi tozalandi!')),
                );
              } else if (val == 'delete') {
                _confirmDeleteChat(context, chatProvider);
              } else if (val == 'block') {
                chatProvider.toggleBlockUser(contact.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isBlocked ? 'Foydalanuvchi blokdan chiqarildi' : 'Foydalanuvchi bloklandi')),
                );
              }
            },
            itemBuilder: (ctx) => [
              if (activeConv.isGroup && (isGroupOwner || isGroupAdmin))
                const PopupMenuItem(
                  value: 'admin_panel',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 20, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Text('Admin Panel 🛡️', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                ),
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
              if (!activeConv.isGroup)
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, size: 20, color: isBlocked ? AppTheme.tertiary : AppTheme.warning),
                      const SizedBox(width: 10),
                      Text(isBlocked ? 'Blokdan chiqarish' : 'Bloklash'),
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

                UserProfile? senderProfile;
                if (!isMe && activeConv.isGroup) {
                  try {
                    senderProfile = activeConv.participants.firstWhere(
                      (p) => p.id == msg.senderId,
                      orElse: () => UserProfile(
                        id: msg.senderId,
                        username: 'user',
                        fullName: 'Guruh a\'zosi',
                      ),
                    );
                  } catch (_) {
                    senderProfile = UserProfile(
                      id: msg.senderId,
                      username: 'user',
                      fullName: 'Guruh a\'zosi',
                    );
                  }
                }

                return MessageBubble(
                  message: msg,
                  isMe: isMe,
                  isGroup: activeConv.isGroup,
                  senderName: senderProfile?.fullName,
                  senderAvatarUrl: senderProfile?.avatarUrl,
                  isGroupOwner: isGroupOwner,
                  isGroupAdmin: isGroupAdmin,
                  isVoicePlaying: chatProvider.currentlyPlayingVoiceMsgId == msg.id && chatProvider.isVoicePlaying,
                  voiceProgress: chatProvider.currentlyPlayingVoiceMsgId == msg.id ? chatProvider.voiceProgress : 0.0,
                  onVoicePlayToggle: () {
                    chatProvider.togglePlayVoice(msg.id, msg.voiceDuration ?? 14);
                  },
                  onReply: (m) => chatProvider.setReplyingTo(m),
                  onEdit: (m) => chatProvider.setEditingMessage(m),
                  onDelete: (m) => chatProvider.deleteMessage(m.id),
                );
              },
            ),
          ),

          // BOTTOM CHAT INPUT BAR
          ChatInputBar(
            replyingTo: chatProvider.replyingToMessage,
            editingMessage: chatProvider.editingMessage,
            isBlocked: isBlocked,
            onUnblock: () => chatProvider.toggleBlockUser(contact.id),
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
              final mediaUrl = bytes != null
                  ? (type == MessageType.video
                      ? 'data:video/mp4;base64,${base64Encode(bytes)}'
                      : 'data:image/jpeg;base64,${base64Encode(bytes)}')
                  : null;

              chatProvider.sendMessage(
                senderId: currentUserId,
                content: name,
                type: type,
                mediaUrl: mediaUrl,
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
          ),
        ],
      ),
    );
  }
}
