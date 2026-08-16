import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/models/user_story.dart';
import '../../../../providers/chat_provider.dart';
import 'story_viewer_dialog.dart';

class StoryAvatarBar extends StatelessWidget {
  final UserProfile currentUser;
  final List<UserProfile> activeContacts;
  final Function(UserProfile) onContactTap;

  const StoryAvatarBar({
    super.key,
    required this.currentUser,
    required this.activeContacts,
    required this.onContactTap,
  });

  Future<void> _addStory(BuildContext context, bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final bytes = await file.readAsBytes();
      final mimeType = isVideo ? 'video/mp4' : 'image/jpeg';
      final mediaDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final newStory = UserStory(
        id: const Uuid().v4(),
        userId: currentUser.id,
        userName: currentUser.fullName,
        userAvatar: currentUser.avatarUrl,
        mediaUrl: mediaDataUrl,
        isVideo: isVideo,
        caption: isVideo ? 'Video story 🎥' : 'Mening story\'yim ✨',
        createdAt: DateTime.now(),
      );

      if (context.mounted) {
        context.read<ChatProvider>().addStory(newStory);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yangi story muvaffaqiyatli qo\'shildi! 🎉'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showAddStoryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image_rounded, color: AppTheme.primary),
                title: const Text('Rasm joylash (Image Story)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addStory(context, false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Colors.purple),
                title: const Text('Video joylash (Video Story)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addStory(context, true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleMyStoryTap(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final myStories = chatProvider.getStoriesForUser(currentUser.id);

    if (myStories.isEmpty) {
      _showAddStoryOptions(context);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.remove_red_eye_rounded, color: AppTheme.primary),
                  title: const Text('Mening storylarimni ko\'rish'),
                  subtitle: Text('${myStories.length} ta story mavjud'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => StoryViewerDialog(
                        userId: currentUser.id,
                        userName: currentUser.fullName,
                        userAvatar: currentUser.avatarUrl,
                        stories: myStories,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                  title: const Text('Yangi story qo\'shish'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddStoryOptions(context);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final myStories = chatProvider.getStoriesForUser(currentUser.id);

    return Container(
      height: 108,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: activeContacts.length + 1,
          separatorBuilder: (ctx, idx) => const SizedBox(width: 14),
          itemBuilder: (ctx, index) {
            if (index == 0) {
              // "Your Story" Item with interactive + button & stories ring
              return GestureDetector(
                onTap: () => _handleMyStoryTap(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: myStories.isNotEmpty ? AppTheme.storyRingGradient : null,
                            border: myStories.isEmpty
                                ? Border.all(
                                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: ClipOval(
                            child: AvatarHelper.buildAvatarWidget(
                              avatarUrl: currentUser.avatarUrl,
                              name: currentUser.fullName,
                              radius: 28,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your Story',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            final contact = activeContacts[index - 1];
            final contactStories = chatProvider.getStoriesForUser(contact.id);
            final hasStories = contactStories.isNotEmpty;

            // Check if all stories are viewed for this contact
            final allViewed = hasStories && contactStories.every((s) => chatProvider.isStoryViewed(s.id));
            final hasUnviewedStories = hasStories && !allViewed;

            return GestureDetector(
              onTap: () {
                if (hasStories) {
                  showDialog(
                    context: context,
                    builder: (_) => StoryViewerDialog(
                      userId: contact.id,
                      userName: contact.fullName,
                      userAvatar: contact.avatarUrl,
                      stories: contactStories,
                    ),
                  );
                } else {
                  onContactTap(contact);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Vibrant gradient for unviewed, thin border for viewed stories
                          gradient: hasUnviewedStories ? AppTheme.storyRingGradient : null,
                          border: allViewed
                              ? Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1.5)
                              : (!hasStories
                                  ? Border.all(
                                      color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                      width: 1.5,
                                    )
                                  : null),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: AvatarHelper.buildAvatarWidget(
                              avatarUrl: contact.avatarUrl,
                              name: contact.fullName,
                              radius: 28,
                            ),
                          ),
                        ),
                      ),
                      if (contact.isOnline)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.tertiary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 62,
                    child: Text(
                      contact.fullName.split(' ').first,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
