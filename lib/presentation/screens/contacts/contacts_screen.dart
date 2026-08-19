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
                  child: Material(
                    color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
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
    final searchMemberController = TextEditingController();
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser.id;
    final selectedMembers = <UserProfile>{};
    List<UserProfile> searchResults = [];
    bool isSearching = false;

    final allPartners = chatProvider.getAllChatPartners(currentUserId);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final isSearchMode = searchMemberController.text.trim().isNotEmpty;
            final displayList = isSearchMode ? searchResults : allPartners;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_add_rounded, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Yangi guruh yaratish',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // GROUP NAME INPUT
                    TextField(
                      controller: groupNameController,
                      decoration: InputDecoration(
                        hintText: 'Guruh nomi (masalan: Dasturchilar)',
                        prefixIcon: const Icon(Icons.group_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SEARCH MEMBER INPUT
                    TextField(
                      controller: searchMemberController,
                      onChanged: (val) async {
                        final clean = val.trim().replaceAll('@', '').toLowerCase();
                        if (clean.isEmpty) {
                          setDialogState(() {
                            isSearching = false;
                            searchResults = [];
                          });
                          return;
                        }
                        setDialogState(() {
                          isSearching = true;
                        });
                        final res = await chatProvider.searchUsers(clean);
                        setDialogState(() {
                          searchResults = res.where((u) => u.id != currentUserId).toList();
                          isSearching = false;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '@username yoki ism orqali izlash...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: searchMemberController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  searchMemberController.clear();
                                  setDialogState(() {
                                    searchResults = [];
                                    isSearching = false;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // SELECTED MEMBERS CHIPS
                    if (selectedMembers.isNotEmpty) ...[
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedMembers.length,
                          separatorBuilder: (c, i) => const SizedBox(width: 6),
                          itemBuilder: (c, idx) {
                            final u = selectedMembers.elementAt(idx);
                            return Chip(
                              avatar: CircleAvatar(
                                radius: 12,
                                child: Text(
                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              label: Text(
                                u.fullName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              deleteIcon: const Icon(Icons.close_rounded, size: 14),
                              onDeleted: () {
                                setDialogState(() {
                                  selectedMembers.remove(u);
                                });
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Text(
                      isSearchMode
                          ? 'Qidiruv natijalari (${displayList.length}):'
                          : 'A\'zolarni tanlang (${displayList.length}):',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),

                    // MEMBERS LIST
                    Expanded(
                      child: isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : displayList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      isSearchMode
                                          ? 'Foydalanuvchi topilmadi'
                                          : 'Hozircha suhbatdoshlar yo\'q. Tepadan username orqali qidiring!',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: displayList.length,
                                  separatorBuilder: (c, i) => const Divider(height: 6, thickness: 0.3),
                                  itemBuilder: (c, idx) {
                                    final contact = displayList[idx];
                                    final isSelected = selectedMembers.any((m) => m.id == contact.id);

                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                      secondary: AvatarHelper.buildAvatarWidget(
                                        avatarUrl: contact.avatarUrl,
                                        name: contact.fullName,
                                        radius: 18,
                                      ),
                                      title: Text(
                                        contact.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      subtitle: Text('@${contact.username}'),
                                      value: isSelected,
                                      activeColor: AppTheme.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedMembers.add(contact);
                                          } else {
                                            selectedMembers.removeWhere((m) => m.id == contact.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 12),

                    // ACTION BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Bekor qilish'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          ),
                          onPressed: () {
                            final name = groupNameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Guruh nomini kiriting!')),
                              );
                              return;
                            }
                            chatProvider.createNewGroup(
                              groupName: name,
                              members: selectedMembers.toList(),
                              creatorId: authProvider.currentUser.id,
                            );
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"$name" guruhi yaratildi! 🎉'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: const Text('Yaratish'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
