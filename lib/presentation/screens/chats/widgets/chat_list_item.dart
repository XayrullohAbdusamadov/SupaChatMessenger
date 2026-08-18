import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/chat_conversation.dart';
import '../../../../data/models/chat_message.dart';

class ChatListItem extends StatefulWidget {
  final ChatConversation conversation;
  final String? currentUserId;
  final String? currentUsername;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.conversation,
    this.currentUserId,
    this.currentUsername,
    required this.onTap,
  });

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _wasUnread = false;

  @override
  void initState() {
    super.initState();
    _wasUnread = widget.conversation.unreadCount > 0;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (_wasUnread) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasUnread = widget.conversation.unreadCount > 0;
    if (hasUnread && !_wasUnread) {
      _pulseController.repeat(reverse: true);
    } else if (!hasUnread && _wasUnread) {
      _pulseController.stop();
      _pulseController.reset();
    }
    _wasUnread = hasUnread;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = widget.conversation.getDisplayName(
      widget.currentUserId,
      currentUsername: widget.currentUsername,
    );
    final displayAvatar = widget.conversation.getDisplayAvatar(
      widget.currentUserId,
      currentUsername: widget.currentUsername,
    );
    final hasUnread = widget.conversation.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        splashColor: AppTheme.primary.withValues(alpha: 0.07),
        highlightColor: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: hasUnread
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? AppTheme.primary.withValues(alpha: 0.06)
                      : AppTheme.primary.withValues(alpha: 0.035),
                )
              : const BoxDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── AVATAR with online dot ──────────────────────────────
              _buildAvatar(context, displayName, displayAvatar, isDark),

              const SizedBox(width: 13),

              // ── CONTENT ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: name + time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Group/muted icon
                        if (widget.conversation.isGroup) ...[
                          Icon(
                            Icons.group_rounded,
                            size: 14,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : AppTheme.textLightSecondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textDarkPrimary
                                  : AppTheme.textLightPrimary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Time — highlighted when unread
                        Text(
                          DateFormatter.formatChatTime(
                              widget.conversation.lastMessageAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: hasUnread
                                ? AppTheme.primary
                                : (isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textLightSecondary),
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Row 2: subtitle + badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildSubtitle(isDark, hasUnread)),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          _buildBadge(context),
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
    );
  }

  // ── AVATAR ──────────────────────────────────────────────────────────────
  Widget _buildAvatar(
    BuildContext context,
    String displayName,
    String? displayAvatar,
    bool isDark,
  ) {
    final isOnline = !widget.conversation.isGroup &&
        widget.conversation.participants.isNotEmpty &&
        widget.conversation.participants
            .any((p) => p.isOnline && p.id != widget.currentUserId);

    return GestureDetector(
      onTap: () => _showEnlargedAvatarDialog(context, displayName, displayAvatar),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: widget.conversation.isGroup
                    ? [
                        AppTheme.secondary.withValues(alpha: 0.3),
                        AppTheme.primary.withValues(alpha: 0.2),
                      ]
                    : [
                        AppTheme.primary.withValues(alpha: 0.18),
                        AppTheme.primaryLight.withValues(alpha: 0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipOval(
              child: AvatarHelper.buildAvatarWidget(
                avatarUrl: displayAvatar,
                name: displayName,
                radius: 26,
              ),
            ),
          ),

          // Online indicator
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.tertiary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.tertiary.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── UNREAD BADGE ────────────────────────────────────────────────────────
  Widget _buildBadge(BuildContext context) {
    final count = widget.conversation.unreadCount;
    final label = count > 99 ? '99+' : '$count';

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4C6EF5), Color(0xFF2F54EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  // ── SUBTITLE / LAST MESSAGE PREVIEW ─────────────────────────────────────
  Widget _buildSubtitle(bool isDark, bool hasUnread) {
    // Typing indicator
    if (widget.conversation.isTyping) {
      return _typingIndicator(isDark);
    }

    // Draft
    if (widget.conversation.draftMessage != null &&
        widget.conversation.draftMessage!.isNotEmpty) {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Qoralama: ',
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: widget.conversation.draftMessage,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : AppTheme.textLightSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Determine if current user sent the last message
    final senderId = widget.conversation.lastMessageSenderId;
    final isMine = senderId != null &&
        widget.currentUserId != null &&
        (senderId == widget.currentUserId ||
            (widget.currentUsername != null &&
                senderId.replaceAll('user-', '').toLowerCase() ==
                    widget.currentUsername!.toLowerCase()));

    final preview = _resolvePreview();
    final subtitleColor = hasUnread
        ? (isDark
            ? AppTheme.textDarkPrimary.withValues(alpha: 0.85)
            : AppTheme.textLightPrimary.withValues(alpha: 0.75))
        : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary);
    final subtitleWeight =
        hasUnread ? FontWeight.w600 : FontWeight.w400;

    if (isMine) {
      // "Siz: [preview]"
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Siz: ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.primary.withValues(alpha: 0.85)
                    : AppTheme.primary.withValues(alpha: 0.9),
              ),
            ),
            TextSpan(
              text: preview,
              style: TextStyle(
                fontSize: 13,
                fontWeight: subtitleWeight,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    // Other person's message — plain preview
    return Text(
      preview,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: subtitleWeight,
        color: subtitleColor,
      ),
    );
  }

  String _resolvePreview() {
    final type = widget.conversation.lastMessageType;
    final raw = widget.conversation.lastMessageText ?? '';
    if (type == MessageType.image && !raw.startsWith('📷')) return '📷 Rasm';
    if (type == MessageType.video && !raw.startsWith('🎥')) return '🎥 Video';
    if (type == MessageType.voice && !raw.startsWith('🎤')) return '🎤 Ovozli xabar';
    if (type == MessageType.doc && !raw.startsWith('📄')) return '📄 Hujjat';
    return raw.isEmpty ? 'Yangi suhbat' : raw;
  }

  // Animated typing dots
  Widget _typingIndicator(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Yozmoqda',
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 3),
        _DotsWave(),
      ],
    );
  }

  // ── ENLARGED AVATAR DIALOG ───────────────────────────────────────────────
  void _showEnlargedAvatarDialog(
      BuildContext context, String name, String? avatarUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: AvatarHelper.buildAvatarWidget(
                          avatarUrl: avatarUrl,
                          name: name,
                          radius: 140,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Animated 3-dot wave ───────────────────────────────────────────────────
class _DotsWave extends StatefulWidget {
  @override
  State<_DotsWave> createState() => _DotsWaveState();
}

class _DotsWaveState extends State<_DotsWave> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: -4)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
