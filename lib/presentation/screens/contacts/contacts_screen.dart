import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/chat_conversation.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../chats/chat_detail_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = authProvider.currentUser;

    final filteredContacts = chatProvider.contacts.where((u) {
      if (_searchFilter.isEmpty) return true;
      return u.fullName.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          u.username.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          (u.role != null && u.role!.toLowerCase().contains(_searchFilter.toLowerCase()));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'SupaChat',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: AvatarHelper.buildAvatarWidget(
                    avatarUrl: currentUser.avatarUrl,
                    name: currentUser.fullName,
                    radius: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // SEARCH BAR
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.inputBgDark : AppTheme.inputBgLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchFilter = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Kontaktlarni qidirish...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // + YANGI GURUH YARATISH BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.group_add_rounded, size: 20),
              label: const Text(
                '+ Yangi guruh yaratish',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _showCreateGroupDialog(context),
            ),
          ),
          const SizedBox(height: 24),

          // SECTION 1: MENING KONTAKTLARIM
          _buildSectionHeader('MENING KONTAKTLARIM', isDark),
          const SizedBox(height: 8),
          ...filteredContacts.map((contact) => _buildContactTile(context, contact, currentUser.id, isDark)),

          const SizedBox(height: 24),

          // SECTION 2: GURUHLAR
          _buildSectionHeader('GURUHLAR', isDark),
          const SizedBox(height: 8),
          _buildGroupTile(
            context,
            name: 'Dev Team Alpha',
            membersCount: 12,
            iconColor: const Color(0xFF10B981),
            icon: Icons.code_rounded,
            isDark: isDark,
          ),
          _buildGroupTile(
            context,
            name: 'Marketing Sync',
            membersCount: 8,
            iconColor: const Color(0xFF3B82F6),
            icon: Icons.campaign_rounded,
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // SECTION 3: GLOBAL QIDIRUV
          _buildSectionHeader('GLOBAL QIDIRUV', isDark),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.inputBgLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 28,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Qidiruv uchun @username\nyoki ism kiriting',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
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

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, UserProfile contact, String currentUserId, bool isDark) {
    final chatProvider = context.read<ChatProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              AvatarHelper.buildAvatarWidget(
                avatarUrl: contact.avatarUrl,
                name: contact.fullName,
                radius: 24,
              ),
              if (contact.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.fullName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.role ?? '@${contact.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 20),
            onPressed: () {
              final chat = chatProvider.startDirectChat(contact);
              chatProvider.openChat(chat, currentUserId);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(conversation: chat),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(
    BuildContext context, {
    required String name,
    required int membersCount,
    required Color iconColor,
    required IconData icon,
    required bool isDark,
  }) {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$membersCount ta a\'zo',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              final group = chatProvider.conversations.firstWhere(
                (c) => c.isGroup && c.name == name,
                orElse: () => ChatConversation(
                  id: 'group-$name',
                  isGroup: true,
                  name: name,
                  lastMessageText: '$membersCount ta a\'zo guruhda faol',
                ),
              );
              chatProvider.openChat(group, authProvider.currentUser.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(conversation: group),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final groupNameController = TextEditingController();
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final selectedMembers = <UserProfile>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Yangi guruh yaratish'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        hintText: 'Guruh nomi (masalan, Marketing Sync)',
                        prefixIcon: Icon(Icons.group_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'A\'zolarni tanlang:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: chatProvider.contacts.length,
                        itemBuilder: (c, idx) {
                          final contact = chatProvider.contacts[idx];
                          final isSelected = selectedMembers.contains(contact);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(contact.fullName),
                            subtitle: Text('@${contact.username}'),
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedMembers.add(contact);
                                } else {
                                  selectedMembers.remove(contact);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = groupNameController.text.trim();
                    if (name.isNotEmpty) {
                      chatProvider.createNewGroup(
                        groupName: name,
                        members: selectedMembers.toList(),
                        creatorId: authProvider.currentUser.id,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"$name" guruhi yaratildi!')),
                      );
                    }
                  },
                  child: const Text('Yaratish'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
