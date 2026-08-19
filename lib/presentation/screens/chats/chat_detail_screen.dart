import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/call_service.dart';
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
import 'widgets/add_group_members_dialog.dart';

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
  int _prevMessageCount = 0;

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

  bool _isMessageFromMe(String senderId, UserProfile currentUser) {
    final cleanSender = senderId.trim().toLowerCase();
    final myId = currentUser.id.trim().toLowerCase();
    final myUsername = currentUser.username.trim().toLowerCase();

    // 1. Direct ID match
    if (myId.isNotEmpty && cleanSender == myId) return true;

    // 2. Direct username match
    if (myUsername.isNotEmpty && cleanSender == myUsername) return true;

    // 3. Normalized "user-xxx" prefix match
    final senderNoPrefix = cleanSender.replaceAll('user-', '');
    final myIdNoPrefix = myId.replaceAll('user-', '');
    if (myUsername.isNotEmpty && senderNoPrefix == myUsername) return true;
    if (myIdNoPrefix.isNotEmpty && senderNoPrefix == myIdNoPrefix) return true;

    // 4. Deterministic UUID v5 check for my username
    if (myUsername.isNotEmpty) {
      try {
        final expectedUuid = const Uuid().v5(Namespace.url.value, 'supachat:user:$myUsername').toLowerCase();
        if (cleanSender == expectedUuid) return true;
      } catch (_) {}
    }

    return false;
  }

  // 2. VIDEO & AUDIO CALL HANDLERS
  void _startVideoCall(UserProfile contact, ChatConversation activeConv, UserProfile currentUser) {
    CallService.instance.startCall(
      caller: currentUser,
      receiver: contact,
      chatId: activeConv.id,
      isVideo: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallOverlay(
          contactName: contact.fullName,
          contactAvatarUrl: contact.avatarUrl,
          contact: contact,
          isVideoCall: true,
          chatId: activeConv.id,
        ),
      ),
    );
  }

  Future<void> _callContactPhone(BuildContext context, UserProfile contact) async {
    final raw = contact.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon raqam topilmadi')),
      );
      return;
    }
    final uri = Uri.parse('tel:$raw');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Qo\'ng\'iroq ilovasini ochib bo\'lmadi: $e')),
      );
    }
  }

  void _showCallOptions(BuildContext context, UserProfile contact, ChatConversation activeConv, UserProfile currentUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Qo\'ng\'iroq turini tanlang',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // OPTION 1: NATIVE CELLULAR PHONE CALL (Native phone dialer)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 22),
                ),
                title: const Text('Oddiy telefon qo\'ng\'irog\'i', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(
                  contact.phoneNumber.isNotEmpty ? contact.phoneNumber : 'Telefon ilovasi ochiladi',
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  _callContactPhone(context, contact);
                },
              ),
              const SizedBox(height: 10),

              // OPTION 2: SUPACHAT INTERNET AUDIO CALL (VoIP)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded, color: AppTheme.primary, size: 22),
                ),
                title: const Text('SupaChat Audio qo\'ng\'iroq', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(
                  'Ilova ichida bepul internet qo\'ng\'iroq',
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  _startAudioCall(contact, activeConv, currentUser);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startAudioCall(UserProfile contact, ChatConversation activeConv, UserProfile currentUser) {
    CallService.instance.startCall(
      caller: currentUser,
      receiver: contact,
      chatId: activeConv.id,
      isVideo: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallOverlay(
          contactName: contact.fullName,
          contactAvatarUrl: contact.avatarUrl,
          contact: contact,
          isVideoCall: false,
          chatId: activeConv.id,
        ),
      ),
    );
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

  void _showUserProfileModal(BuildContext context, UserProfile contact, ChatConversation conversation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.read<ChatProvider>();
    final isBlocked = !conversation.isGroup && chatProvider.isUserBlocked(contact.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final authProvider = context.read<AuthProvider>();
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // BIG AVATAR
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: AvatarHelper.buildAvatarWidget(
                        avatarUrl: contact.avatarUrl,
                        name: contact.fullName,
                        radius: 48,
                      ),
                    ),
                  ),
                  if (contact.isOnline)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          width: 3.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // NAME & USERNAME
              Text(
                contact.fullName.isNotEmpty ? contact.fullName : contact.username,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${contact.username}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '@${contact.username}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('@${contact.username} nusxalandi! 📋'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.copy_rounded, size: 15, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // PHONE NUMBER CARD
              if (contact.phoneNumber.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Telefon raqam',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              contact.phoneNumber,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 20),
                        tooltip: 'Oddiy qo\'ng\'iroq qilish',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _callContactPhone(context, contact);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppTheme.primary, size: 18),
                        tooltip: 'Nusxalash',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: contact.phoneNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${contact.phoneNumber} nusxalandi! 📋'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // BIO / ABOUT CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio / Ma\'lumot',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.about.isNotEmpty ? contact.about : 'Hey there! I am using SupaChat.',
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ACTION BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileActionButton(
                    icon: Icons.phone_in_talk_rounded,
                    label: "Oddiy tel",
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _callContactPhone(context, contact);
                    },
                  ),
                  _buildProfileActionButton(
                    icon: Icons.headset_mic_rounded,
                    label: "SupaChat",
                    color: AppTheme.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startAudioCall(contact, conversation, authProvider.currentUser);
                    },
                  ),
                  _buildProfileActionButton(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: AppTheme.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startVideoCall(contact, conversation, authProvider.currentUser);
                    },
                  ),
                  _buildProfileActionButton(
                    icon: Icons.perm_media_rounded,
                    label: 'Media',
                    color: Colors.amber[800]!,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMediaGallery();
                    },
                  ),
                  _buildProfileActionButton(
                    icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    label: isBlocked ? 'Ochish' : 'Bloklash',
                    color: isBlocked ? AppTheme.tertiary : AppTheme.error,
                    onTap: () {
                      chatProvider.toggleBlockUser(contact.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isBlocked ? 'Foydalanuvchi blokdan chiqarildi' : 'Foydalanuvchi bloklandi'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = authProvider.currentUser.id;
    final messages = chatProvider.currentMessages;

    if (messages.length != _prevMessageCount) {
      _prevMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    // Active conversation
    final activeConv = chatProvider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );

    final displayName = activeConv.getDisplayName(currentUserId, currentUsername: authProvider.currentUser.username);
    final displayAvatar = activeConv.getDisplayAvatar(currentUserId, currentUsername: authProvider.currentUser.username);
    final otherContact = activeConv.getOtherParticipant(currentUserId, currentUsername: authProvider.currentUser.username);
    final contact = otherContact ?? (activeConv.participants.isNotEmpty
        ? activeConv.participants.first
        : UserProfile(
            id: 'contact',
            username: displayName.toLowerCase().replaceAll(' ', '_'),
            fullName: displayName,
          ));

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
        title: InkWell(
          onTap: () => _showUserProfileModal(context, contact, activeConv),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                // AVATAR
                Stack(
                  children: [
                    AvatarHelper.buildAvatarWidget(
                      avatarUrl: displayAvatar,
                      name: displayName,
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
                        displayName,
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
          ),
        ),
        actions: [
          // Video Call Icon -> Full screen interactive video call
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video qo\'ng\'iroq',
            onPressed: () => _startVideoCall(contact, activeConv, authProvider.currentUser),
          ),
          // Voice / Phone Call Icon -> Options (Cellular or SupaChat VoIP)
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            tooltip: 'Qo\'ng\'iroq qilish',
            onPressed: () => _showCallOptions(context, contact, activeConv, authProvider.currentUser),
          ),
          // More Menu (3 dots)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'add_member') {
                showDialog(
                  context: context,
                  builder: (_) => AddGroupMembersDialog(conversation: activeConv),
                );
              } else if (val == 'admin_panel') {
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
              if (activeConv.isGroup)
                const PopupMenuItem(
                  value: 'add_member',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_rounded, size: 20, color: Colors.green),
                      SizedBox(width: 10),
                      Text('A\'zo qo\'shish ➕', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
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
                final isMe = _isMessageFromMe(msg.senderId, authProvider.currentUser);

                UserProfile? senderProfile;
                if (!isMe && activeConv.isGroup) {
                  try {
                    senderProfile = activeConv.participants.firstWhere(
                      (p) => p.id == msg.senderId || p.username.toLowerCase() == msg.senderId.replaceAll('user-', '').toLowerCase(),
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
            onSendVoice: (filePath, durationSeconds) {
              chatProvider.sendVoiceMessage(
                senderId: currentUserId,
                filePath: filePath,
                durationSeconds: durationSeconds,
              );
              Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            },
          ),
        ],
      ),
    );
  }
}
