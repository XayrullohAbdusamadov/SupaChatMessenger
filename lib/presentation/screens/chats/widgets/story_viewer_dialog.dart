import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/user_story.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/chat_provider.dart';

class StoryViewerDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final List<UserStory> stories;

  const StoryViewerDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.stories,
  });

  @override
  State<StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<StoryViewerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final TextEditingController _replyController = TextEditingController();
  int _currentIndex = 0;

  final List<String> _quickReactions = ['❤️', '🔥', '😂', '👏', '😍', '😮'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _animController.forward();

    // Mark initial story as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.stories.isNotEmpty) {
        context.read<ChatProvider>().markStoryAsViewed(widget.stories[_currentIndex].id);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      context.read<ChatProvider>().markStoryAsViewed(widget.stories[_currentIndex].id);
      _animController.reset();
      _animController.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _animController.reset();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _sendStoryReply(String replyText) {
    if (replyText.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentStory = widget.stories[_currentIndex];

    chatProvider.replyToStory(
      story: currentStory,
      replyText: replyText.trim(),
      currentUserId: auth.currentUser.id,
    );

    _replyController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Javob ${widget.userName}ga yuborildi 🚀"),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = widget.stories[_currentIndex];
    final auth = context.read<AuthProvider>();
    final isMe = widget.userId == auth.currentUser.id;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // MEDIA DISPLAY
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < screenWidth * 0.3) {
                  _prevStory();
                } else if (details.globalPosition.dx > screenWidth * 0.7) {
                  _nextStory();
                }
              },
              child: Container(
                color: Colors.black,
                child: Center(
                  child: currentStory.mediaUrl.startsWith('data:image')
                      ? Image.memory(
                          AvatarHelper.getImageProvider(currentStory.mediaUrl) != null
                              ? (AvatarHelper.getImageProvider(currentStory.mediaUrl) as MemoryImage).bytes
                              : Uint8List(0),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          currentStory.mediaUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (c, err, stack) => Container(
                            color: Colors.grey[900],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  currentStory.isVideo ? Icons.video_library_rounded : Icons.image_rounded,
                                  size: 72,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  currentStory.isVideo ? 'Video Story' : 'Rasm Story',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // TOP GRADIENT & PROGRESS BARS & HEADER
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      // PROGRESS BARS
                      Row(
                        children: List.generate(widget.stories.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (ctx, child) {
                                  double value = 0.0;
                                  if (index < _currentIndex) {
                                    value = 1.0;
                                  } else if (index == _currentIndex) {
                                    value = _animController.value;
                                  }
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white30,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 3,
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // USER INFO & CLOSE / DELETE
                      Row(
                        children: [
                          AvatarHelper.buildAvatarWidget(
                            avatarUrl: widget.userAvatar,
                            name: widget.userName,
                            radius: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormatter.formatMessageTime(currentStory.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMe)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                              onPressed: () {
                                context.read<ChatProvider>().deleteStory(currentStory.id);
                                Navigator.pop(context);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CAPTION & TELEGRAM-STYLE IN-STORY REPLY BAR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CAPTION IF ANY
                    if (currentStory.caption != null && currentStory.caption!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          currentStory.caption!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // QUICK EMOJI REACTIONS ROW (TELEGRAM STYLE)
                    if (!isMe) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _quickReactions.map((emoji) {
                          return GestureDetector(
                            onTap: () => _sendStoryReply(emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // TEXT REPLY INPUT FIELD
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: TextField(
                                controller: _replyController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'Xabar yozing...',
                                  hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: _sendStoryReply,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _sendStoryReply(_replyController.text),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
