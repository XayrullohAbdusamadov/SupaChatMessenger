import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import 'widgets/story_avatar_bar.dart';
import 'widgets/chat_list_item.dart';
import 'chat_detail_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChatWithUser(BuildContext context, UserProfile contact, String currentUserId) {
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

    if (currentUser.id.isNotEmpty && chatProvider.currentActiveUserId != currentUser.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.loadUserData(currentUser.id, username: currentUser.username);
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: AvatarHelper.buildAvatarWidget(
                  avatarUrl: currentUser.avatarUrl,
                  name: currentUser.fullName,
                  radius: 19,
                ),
              ),
            ),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '@username yoki ism bo\'yicha qidiruv...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  chatProvider.setSearchQuery(val, currentUsername: currentUser.username);
                },
              )
            : const Text(
                'SupaChat',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  chatProvider.setSearchQuery('', currentUsername: currentUser.username);
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // STORIES / ACTIVE CONTACTS CAROUSEL
            if (!_isSearching)
              SliverToBoxAdapter(
                child: StoryAvatarBar(
                  currentUser: currentUser,
                  activeContacts: chatProvider.contacts,
                  onContactTap: (contact) => _openChatWithUser(context, contact, currentUser.id),
                ),
              ),

            if (!_isSearching)
              const SliverToBoxAdapter(
                child: Divider(height: 1, thickness: 0.5),
              ),

            // SEARCH MODE
            if (_isSearching) ...[
              // IF SEARCH QUERY IS EMPTY: SHOW RECENT SEARCHES HISTORY WITH DELETE BUTTONS
              if (chatProvider.searchQuery.isEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'QIDIRUV TARIXI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                          ),
                        ),
                        if (chatProvider.recentSearches.isNotEmpty)
                          GestureDetector(
                            onTap: () => chatProvider.clearRecentSearches(),
                            child: const Text(
                              'Tozalash',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (chatProvider.recentSearches.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'Qidiruv tarixi bo\'sh.\n@username orqali yangi odamlarni izlang!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = chatProvider.recentSearches[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: AvatarHelper.buildAvatarWidget(
                            avatarUrl: user.avatarUrl,
                            name: user.fullName,
                            radius: 22,
                          ),
                          title: Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '@${user.username}${user.role != null ? " • ${user.role}" : ""}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                            tooltip: 'Tarixdan o\'chirish',
                            onPressed: () {
                              chatProvider.deleteRecentSearch(user.id);
                            },
                          ),
                          onTap: () => _openChatWithUser(context, user, currentUser.id),
                        );
                      },
                      childCount: chatProvider.recentSearches.length,
                    ),
                  ),
              ] else ...[
                // SEARCH QUERY NOT EMPTY: SHOW SEARCH RESULTS FROM SQL DATABASE & CONTACTS
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'NATIJALAR (@username):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                if (chatProvider.isSearchingUsers)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    ),
                  )
                else if (chatProvider.sqlSearchResults.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Foydalanuvchi topilmadi',
                              style: TextStyle(
                                fontSize: 16,
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
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = chatProvider.sqlSearchResults[index];
                        return ListTile(
                          leading: AvatarHelper.buildAvatarWidget(
                            avatarUrl: user.avatarUrl,
                            name: user.fullName,
                            radius: 22,
                          ),
                          title: Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '@${user.username} • ${user.about}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _openChatWithUser(context, user, currentUser.id),
                            child: const Text('Yozish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          onTap: () => _openChatWithUser(context, user, currentUser.id),
                        );
                      },
                      childCount: chatProvider.sqlSearchResults.length,
                    ),
                  ),
              ],
            ] else ...[
              // NORMAL CONVERSATIONS LIST
              if (chatProvider.conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Suhbatlar hali mavjud emas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Qidiruv bo\'limida @username orqali odamlarni topib suhbatni boshlang!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final conversation = chatProvider.conversations[index];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ChatListItem(
                              conversation: conversation,
                              currentUserId: currentUser.id,
                              currentUsername: currentUser.username,
                              onTap: () {
                                chatProvider.openChat(conversation, currentUser.id);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailScreen(conversation: conversation),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (index < chatProvider.conversations.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 82, right: 16),
                              child: Divider(
                                height: 1,
                                thickness: 0.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                        ],
                      );
                    },
                    childCount: chatProvider.conversations.length,
                  ),
                ),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.edit_rounded, size: 24),
        onPressed: () {
          _showNewChatSheet(context);
        },
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Yangi suhbat boshlash',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: chatProvider.contacts.length,
                    itemBuilder: (c, idx) {
                      final contact = chatProvider.contacts[idx];
                      return ListTile(
                        leading: AvatarHelper.buildAvatarWidget(
                          avatarUrl: contact.avatarUrl,
                          name: contact.fullName,
                          radius: 20,
                        ),
                        title: Text(contact.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('@${contact.username} • ${contact.role ?? contact.about}'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openChatWithUser(context, contact, authProvider.currentUser.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
