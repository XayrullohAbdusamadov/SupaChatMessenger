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

  void _openChat(BuildContext context, UserProfile contact, String currentUserId) {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    chatProvider.saveRecentSearch(contact);
    final chat = chatProvider.startDirectChat(contact, currentUser: authProvider.currentUser);
    chatProvider.openChat(chat, currentUserId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversation: chat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = authProvider.currentUser;

    final myContacts = chatProvider.contacts;
    final userGroups = chatProvider.conversations.where((c) => c.isGroup).toList();

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
                chatProvider.searchUsers(val, currentUsername: currentUser.username);
              },
              decoration: InputDecoration(
                hintText: '@username yoki ism bo\'yicha qidiruv...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchFilter = '';
                          });
                          chatProvider.searchUsers('', currentUsername: currentUser.username);
                        },
                      )
                    : null,
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

          // LIVE SEARCH RESULTS (If search filter is not empty)
          if (_searchFilter.trim().isNotEmpty) ...[
            _buildSectionHeader('QIDIRUV NATIJALARI (@username)', isDark),
            const SizedBox(height: 8),
            if (chatProvider.isSearchingUsers)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (chatProvider.sqlSearchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Foydalanuvchi topilmadi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ushbu username bo\'yicha akkaunt mavjud emas',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...chatProvider.sqlSearchResults.map((user) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: AvatarHelper.buildAvatarWidget(
                        avatarUrl: user.avatarUrl,
                        name: user.fullName,
                        radius: 22,
                      ),
                      title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('@${user.username} • ${user.about}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openChat(context, user, currentUser.id),
                        child: const Text('Yozish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      onTap: () => _openChat(context, user, currentUser.id),
                    ),
                  )),
            const SizedBox(height: 24),
          ],

          // QIDIRUV TARIXI (If search filter is empty & history exists)
          if (_searchFilter.isEmpty && chatProvider.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('QIDIRUV TARIXI', isDark),
                GestureDetector(
                  onTap: () => chatProvider.clearRecentSearches(),
                  child: const Text(
                    'Tozalash',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...chatProvider.recentSearches.map((user) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: AvatarHelper.buildAvatarWidget(
                      avatarUrl: user.avatarUrl,
                      name: user.fullName,
                      radius: 18,
                    ),
                    title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('@${user.username}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      onPressed: () => chatProvider.deleteRecentSearch(user.id),
                    ),
                    onTap: () => _openChat(context, user, currentUser.id),
                  ),
                )),
            const SizedBox(height: 20),
          ],

          // SECTION 1: MENING KONTAKTLARIM
          _buildSectionHeader('MENING KONTAKTLARIM', isDark),
          const SizedBox(height: 8),
          if (myContacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Hali kontaktlar mavjud emas.\nQidiruv orqali foydalanuvchilarni toping!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
              ),
            )
          else
            ...myContacts.map((contact) => _buildContactTile(context, contact, currentUser.id, isDark)),

          const SizedBox(height: 24),

          // SECTION 2: GURUHLAR
          _buildSectionHeader('GURUHLAR', isDark),
          const SizedBox(height: 8),
          if (userGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Hali guruhlar yaratilmagan.\n"+ Yangi guruh yaratish" tugmasini bosing!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                ),
              ),
            )
          else
            ...userGroups.map((group) => _buildGroupTile(
                  context,
                  group: group,
                  isDark: isDark,
                )),

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
                  '@${contact.username}${contact.role != null ? " • ${contact.role}" : ""}',
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
            onPressed: () => _openChat(context, contact, currentUserId),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(
    BuildContext context, {
    required ChatConversation group,
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
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.participants.length} ta a\'zo',
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

    final availableContacts = chatProvider.contacts;

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
                    if (availableContacts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          'Hali kontaktlar yo\'q. Avval foydalanuvchilar bilan suhbat boshlang!',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableContacts.length,
                          itemBuilder: (c, idx) {
                            final contact = availableContacts[idx];
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
