import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = authProvider.currentUser;

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
                  hintText: 'Suhbatlarni qidirish...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  chatProvider.setSearchQuery(val);
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
                  chatProvider.setSearchQuery('');
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
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // STORIES / ACTIVE CONTACTS CAROUSEL
            SliverToBoxAdapter(
              child: StoryAvatarBar(
                currentUser: currentUser,
                activeContacts: chatProvider.contacts,
                onContactTap: (contact) {
                  final chat = chatProvider.startDirectChat(contact);
                  chatProvider.openChat(chat, currentUser.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(conversation: chat),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 1, thickness: 0.5),
            ),

            // CHATS LIST
            if (chatProvider.conversations.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 56,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Suhbatlar topilmadi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conversation = chatProvider.conversations[index];
                    return ChatListItem(
                      conversation: conversation,
                      onTap: () {
                        chatProvider.openChat(conversation, currentUser.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(conversation: conversation),
                          ),
                        );
                      },
                    );
                  },
                  childCount: chatProvider.conversations.length,
                ),
              ),
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
                    'Yangi suhbat',
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
                          final chat = chatProvider.startDirectChat(contact);
                          chatProvider.openChat(chat, authProvider.currentUser.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(conversation: chat),
                            ),
                          );
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
