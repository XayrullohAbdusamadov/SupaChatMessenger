import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/user_profile.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              // "Your Story" Item matching screenshot
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: currentUser.avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: currentUser.avatarUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (c, url) => Container(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
                                  errorWidget: (c, url, err) => const Icon(Icons.person, color: AppTheme.primary),
                                )
                              : const Icon(Icons.person, color: AppTheme.primary),
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
              );
            }

            final contact = activeContacts[index - 1];
            return GestureDetector(
              onTap: () => onContactTap(contact),
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
                          gradient: contact.isOnline ? AppTheme.storyRingGradient : null,
                          border: !contact.isOnline
                              ? Border.all(
                                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: contact.avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: contact.avatarUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (c, url) => Container(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
                                    errorWidget: (c, url, err) => Text(contact.fullName[0]),
                                  )
                                : Center(
                                    child: Text(
                                      contact.fullName.isNotEmpty ? contact.fullName[0] : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
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
