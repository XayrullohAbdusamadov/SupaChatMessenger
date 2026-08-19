import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../data/models/chat_conversation.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/chat_provider.dart';

class AddGroupMembersDialog extends StatefulWidget {
  final ChatConversation conversation;

  const AddGroupMembersDialog({
    super.key,
    required this.conversation,
  });

  @override
  State<AddGroupMembersDialog> createState() => _AddGroupMembersDialogState();
}

class _AddGroupMembersDialogState extends State<AddGroupMembersDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<UserProfile> _selectedMembers = {};
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query, String currentUserId) async {
    final clean = query.trim().replaceAll('@', '').toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final chatProvider = context.read<ChatProvider>();
    final results = await chatProvider.searchUsers(clean);

    if (!mounted) return;

    final existingParticipantIds = widget.conversation.participants.map((p) => p.id).toSet();

    setState(() {
      _searchResults = results
          .where((u) => u.id != currentUserId && !existingParticipantIds.contains(u.id))
          .toList();
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUser.id;

    // Existing group participant IDs
    final existingIds = widget.conversation.participants.map((p) => p.id).toSet();

    // Chat partners who are NOT yet in the group
    final chatPartners = chatProvider
        .getAllChatPartners(currentUserId)
        .where((u) => !existingIds.contains(u.id))
        .toList();

    final isSearchMode = _searchController.text.trim().isNotEmpty;
    final displayList = isSearchMode ? _searchResults : chatPartners;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_rounded, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A\'zo qo\'shish',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // SEARCH BAR
            TextField(
              controller: _searchController,
              onChanged: (val) => _performSearch(val, currentUserId),
              decoration: InputDecoration(
                hintText: '@username yoki ism orqali izlash...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('', currentUserId);
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
            const SizedBox(height: 12),

            // SELECTED USERS CHIPS (if any)
            if (_selectedMembers.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMembers.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 6),
                  itemBuilder: (ctx, idx) {
                    final u = _selectedMembers.elementAt(idx);
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
                        setState(() {
                          _selectedMembers.remove(u);
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
              const SizedBox(height: 10),
            ],

            // SECTION TITLE
            Text(
              isSearchMode
                  ? 'Qidiruv natijalari (${displayList.length})'
                  : 'Yozishgan suhbatdoshlar (${displayList.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
              ),
            ),
            const SizedBox(height: 6),

            // CANDIDATES LIST
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : displayList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              isSearchMode
                                  ? 'Foydalanuvchi topilmadi'
                                  : 'Guruhga qo\'shilmagan boshqa suhbatdoshlar yo\'q. Tepadan username orqali qidiring!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: displayList.length,
                          separatorBuilder: (c, i) => const Divider(height: 6, thickness: 0.3),
                          itemBuilder: (ctx, index) {
                            final user = displayList[index];
                            final isSelected = _selectedMembers.any((m) => m.id == user.id);

                            return CheckboxListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              secondary: AvatarHelper.buildAvatarWidget(
                                avatarUrl: user.avatarUrl,
                                name: user.fullName,
                                radius: 18,
                              ),
                              title: Text(
                                user.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '@${user.username}${user.phoneNumber.isNotEmpty ? " • ${user.phoneNumber}" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                                ),
                              ),
                              value: isSelected,
                              activeColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedMembers.add(user);
                                  } else {
                                    _selectedMembers.removeWhere((m) => m.id == user.id);
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bekor qilish'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(_selectedMembers.isEmpty
                      ? "Qo'shish"
                      : "Qo'shish (${_selectedMembers.length})"),
                  onPressed: _selectedMembers.isEmpty
                      ? null
                      : () async {
                          final count = _selectedMembers.length;
                          await chatProvider.addGroupMembers(
                            widget.conversation.id,
                            _selectedMembers.toList(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$count ta yangi a\'zo guruhga qo\'shildi! 🎉'),
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
      ),
    );
  }
}
