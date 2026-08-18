import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/theme_provider.dart';
import '../chats/chat_detail_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'SupaChat',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // PROFILE CARD
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: AvatarHelper.buildAvatarWidget(
                          avatarUrl: user.avatarUrl,
                          name: user.fullName,
                          radius: 48,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _editProfile(context),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.inputBgLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    user.about,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SETTINGS LIST TILES
          _buildSettingsTile(
            context,
            icon: Icons.bookmark_border_rounded,
            title: 'Saqlangan xabarlar 📌',
            subtitle: 'O\'zingizga xabar, rasm va fayllarni saqlash',
            isDark: isDark,
            onTap: () {
              final chatProvider = context.read<ChatProvider>();
              final savedChat = chatProvider.startSavedMessagesChat(user);
              chatProvider.openChat(savedChat, user.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(conversation: savedChat),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.person_outline_rounded,
            title: 'Hisob',
            subtitle: 'Privacy, Security, Change Number',
            isDark: isDark,
            onTap: () => _editProfile(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Bildirishnomalar va ovozlar',
            subtitle: 'Message tones, group alerts',
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bildirishnomalar yoqilgan')),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.pie_chart_outline_rounded,
            title: 'Ma\'lumotlar va xotira',
            subtitle: 'Storage usage, Network usage',
            isDark: isDark,
            onTap: () {
              _showStorageDialog(context);
            },
          ),

          // THEME SWITCH TILE
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                width: 0.5,
              ),
            ),
            child: ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: AppTheme.primary,
              ),
              title: const Text('Mavzu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                isDark ? 'Dark mode (Qorong\'i)' : 'Light mode (Yorug\')',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
              ),
              trailing: Switch(
                value: isDark,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) {
                  themeProvider.toggleTheme(val);
                },
              ),
            ),
          ),

          // BIOMETRIC LOCK SWITCH TILE
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                width: 0.5,
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.fingerprint_rounded, color: AppTheme.primary),
              title: const Text('Biometrik qulf', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                'Face ID / Fingerprint',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
              ),
              trailing: Switch(
                value: authProvider.biometricEnabled,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) {
                  authProvider.toggleBiometric(val);
                },
              ),
            ),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.help_outline_rounded,
            title: 'Yordam va qo\'llab-quvvatlash',
            subtitle: 'FAQ, bog\'lanish',
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SupaChat Messenger (Online & Cloud Sync)')),
              );
            },
          ),

          // LOG OUT TILE
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppTheme.error.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
              title: const Text(
                'Hisobdan chiqish',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.error),
              ),
              subtitle: Text(
                'Ilovadan butunlay chiqish',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.error),
              onTap: () => _confirmLogOut(context),
            ),
          ),

          const SizedBox(height: 20),

          // ELEGANT CREATOR ATTRIBUTION CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.code_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yaratuvchi:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hayrulloh Abdusamadov',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse('https://t.me/HayrullohAdusamadov');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Telegram kanalga o\'tish',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    IconData? trailingIcon,
    Color? trailingColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
          ),
        ),
        trailing: Icon(trailingIcon ?? Icons.chevron_right_rounded, color: trailingColor),
        onTap: onTap,
      ),
    );
  }

  // ELEGANT & SPACIOUS EDIT PROFILE DIALOG
  void _editProfile(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameCtrl = TextEditingController(text: auth.currentUser.fullName);
    final userCtrl = TextEditingController(text: auth.currentUser.username);
    final bioCtrl = TextEditingController(text: auth.currentUser.about);
    Uint8List? newImageBytes;

    bool isImageDeleted = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final currentAvatarUrl = isImageDeleted ? null : auth.currentUser.avatarUrl;
            final hasAvatar = newImageBytes != null || currentAvatarUrl != null;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profilni tahrirlash',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      // AVATAR PICKER
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                                  backgroundImage: newImageBytes != null
                                      ? MemoryImage(newImageBytes!)
                                      : AvatarHelper.getImageProvider(currentAvatarUrl),
                                  child: !hasAvatar
                                      ? const Icon(Icons.person, size: 48, color: AppTheme.primary)
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: () async {
                                      final picker = ImagePicker();
                                      final picked = await picker.pickImage(source: ImageSource.gallery);
                                      if (picked != null) {
                                        final bytes = await picked.readAsBytes();
                                        setDialogState(() {
                                          newImageBytes = bytes;
                                          isImageDeleted = false;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hasAvatar) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text("Rasmni o'chirish", style: TextStyle(fontSize: 13)),
                                onPressed: () {
                                  setDialogState(() {
                                    newImageBytes = null;
                                    isImageDeleted = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FULL NAME INPUT
                      const Text(
                        'To\'liq ism',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ismingiz va familiyangiz',
                          filled: true,
                          fillColor: isDark ? AppTheme.surfaceDark : AppTheme.inputBgLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // USERNAME INPUT
                      const Text(
                        'Username',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: userCtrl,
                        decoration: InputDecoration(
                          prefixText: '@',
                          hintText: 'username',
                          filled: true,
                          fillColor: isDark ? AppTheme.surfaceDark : AppTheme.inputBgLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // BIO STATUS INPUT
                      const Text(
                        'Status / Bio',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bioCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'O\'zingiz haqingizda...',
                          filled: true,
                          fillColor: isDark ? AppTheme.surfaceDark : AppTheme.inputBgLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ACTION BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Bekor qilish'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              final nav = Navigator.of(dialogCtx);
                              await auth.updateProfile(
                                fullName: nameCtrl.text.trim(),
                                username: userCtrl.text.trim(),
                                about: bioCtrl.text.trim(),
                                newAvatarBytes: newImageBytes,
                                deleteExistingAvatar: isImageDeleted,
                              );
                              nav.pop();
                            },
                            child: const Text('Saqlash'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStorageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xotira va Ma\'lumotlar'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Rasmlar keshi: 18.4 MB'),
            SizedBox(height: 6),
            Text('• Hujjatlar: 4.2 MB'),
            SizedBox(height: 6),
            Text('• Ovozli xabarlar: 2.1 MB'),
            SizedBox(height: 6),
            Text('• Supabase Database: Sinxronlangan ✅'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  void _confirmLogOut(BuildContext context) {
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 36),
        ),
        title: const Text('Ilovadan chiqish', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Haqiqatan ham hisobingizdan butunlay chiqmoqchimisiz? Qayta kirish uchun ma\'lumotlaringizni kiritishingiz kerak bo\'ladi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<ChatProvider>().clearUserData();
              await auth.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hisobdan muvaffaqiyatli chiqildi'),
                    backgroundColor: Colors.grey,
                  ),
                );
              }
            },
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }
}

