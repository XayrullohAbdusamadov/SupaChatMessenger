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
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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
        splashColor: AppTheme.primary.withValues(alpha: 0.08),
        highlightColor: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: hasUnread
                ? (isDark
                    ? AppTheme.primary.withValues(alpha: 0.09)
                    : AppTheme.primary.withValues(alpha: 0.045))
                : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── UNREAD LEFT ACCENT INDICATOR BAR ─────────────────
              if (hasUnread)
                Container(
                  width: 3.5,
                  height: 38,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),

              // ── AVATAR with online dot & unread ring ─────────────
              _buildAvatar(context, displayName, displayAvatar, isDark, hasUnread),

              const SizedBox(width: 12),

              // ── CONTENT ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Name + Time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.conversation.isGroup) ...[
                          Icon(
                            Icons.group_rounded,
                            size: 15,
                            color: hasUnread
                                ? AppTheme.primary
                                : (isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textLightSecondary),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
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
                                        ? (hasUnread
                                            ? Colors.white
                                            : AppTheme.textDarkPrimary)
                                        : (hasUnread
                                            ? const Color(0xFF0F172A)
                                            : AppTheme.textLightPrimary),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Time — highlighted in vibrant blue when unread
                        Text(
                          DateFormatter.formatChatTime(
                              widget.conversation.lastMessageAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: hasUnread
                                ? const Color(0xFF2563EB)
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

                    const SizedBox(height: 4),

                    // Row 2: Subtitle / Message Text + Unread Count Badge
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
    bool hasUnread,
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
          // Avatar circle with subtle unread glowing ring
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: hasUnread
                  ? Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                      width: 2,
                    )
                  : null,
              gradient: LinearGradient(
                colors: widget.conversation.isGroup
                    ? [
                        AppTheme.secondary.withValues(alpha: 0.35),
                        AppTheme.primary.withValues(alpha: 0.25),
                      ]
                    : [
                        AppTheme.primary.withValues(alpha: 0.22),
                        AppTheme.primaryLight.withValues(alpha: 0.12),
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
                      color: AppTheme.tertiary.withValues(alpha: 0.6),
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

  // ── UNREAD BADGE (ACCOUNT BLOGI OXIRIDA XABARLAR SONI) ───────────────────
  Widget _buildBadge(BuildContext context) {
    final count = widget.conversation.unreadCount;
    final label = count > 99 ? '99+' : '$count';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Text(
            'YANGI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── SUBTITLE / LAST MESSAGE PREVIEW (YANGI XABAR KELGANINI BILDIRUVCHI DIZAYN) ──
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
            const TextSpan(
              text: 'Qoralama: ',
              style: TextStyle(
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

    final rawText = widget.conversation.lastMessageText;
    if (rawText == null || rawText.trim().isEmpty) {
      return Text(
        'Yangi suhbat',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: isDark
              ? AppTheme.textDarkSecondary.withValues(alpha: 0.5)
              : AppTheme.textLightSecondary.withValues(alpha: 0.5),
        ),
      );
    }

    // Determine if current user sent the last message
    final senderId = widget.conversation.lastMessageSenderId;
    bool isMine = false;
    if (senderId != null) {
      final myId = widget.currentUserId?.toLowerCase();
      final myUsername = widget.currentUsername?.toLowerCase();
      final cleanSender = senderId.replaceAll('user-', '').toLowerCase();

      if (myId != null && (senderId.toLowerCase() == myId || cleanSender == myId.replaceAll('user-', ''))) {
        isMine = true;
      } else if (myUsername != null && (cleanSender == myUsername || senderId.toLowerCase() == 'user-$myUsername')) {
        isMine = true;
      }
    }

    final preview = _resolvePreview();

    // Text style based on read / unread status
    final Color textColor;
    final FontWeight textWeight;

    if (hasUnread && !isMine) {
      // Unread incoming message: bold, high contrast, vibrant design!
      textColor = isDark
          ? const Color(0xFFF1F5F9) // Bright crisp white in dark mode
          : const Color(0xFF0F172A); // Deep dark slate in light mode
      textWeight = FontWeight.w600;
    } else if (hasUnread && isMine) {
      textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
      textWeight = FontWeight.w500;
    } else {
      // Read message: secondary calm color
      textColor = isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary;
      textWeight = FontWeight.w400;
    }

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
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF2563EB),
              ),
            ),
            TextSpan(
              text: preview,
              style: TextStyle(
                fontSize: 13,
                fontWeight: textWeight,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    // Other person's message
    return Row(
      children: [
        if (hasUnread) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'YANGI',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
        Expanded(
          child: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: textWeight,
              color: textColor,
            ),
          ),
        ),
      ],
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
        const Text(
          'Yozmoqda',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
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
