import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../data/models/chat_conversation.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/chat_provider.dart';

class GroupAdminPanelDialog extends StatelessWidget {
  final ChatConversation conversation;

  const GroupAdminPanelDialog({
    super.key,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUser.id;

    // Fetch latest state of this conversation from provider
    final currentConv = chatProvider.conversations.firstWhere(
      (c) => c.id == conversation.id,
      orElse: () => conversation,
    );

    final isOwner = currentConv.isOwner(currentUserId);
    final isAdmin = currentConv.isAdmin(currentUserId);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentConv.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Admin Boshqaruv Paneli • ${currentConv.participants.length} a\'zo',
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
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),

            // ROLE BADGES LEGEND
            Row(
              children: [
                _buildRoleBadge('👑 Guruh Egasi', Colors.amber[800]!),
                const SizedBox(width: 8),
                _buildRoleBadge('🛡️ Admin', AppTheme.primary),
                const SizedBox(width: 8),
                _buildRoleBadge('👤 A\'zo', Colors.grey),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Guruh A\'zolari va Huquqlari:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // MEMBERS LIST
            Expanded(
              child: ListView.separated(
                itemCount: currentConv.participants.length,
                separatorBuilder: (c, i) => const Divider(height: 8, thickness: 0.3),
                itemBuilder: (ctx, index) {
                  final member = currentConv.participants[index];
                  final isMemberOwner = currentConv.isOwner(member.id);
                  final isMemberAdmin = currentConv.isAdmin(member.id);
                  final isMemberBlocked = currentConv.isMemberBlocked(member.id);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarHelper.buildAvatarWidget(
                      avatarUrl: member.avatarUrl,
                      name: member.fullName,
                      radius: 20,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isMemberOwner)
                          const Text('👑', style: TextStyle(fontSize: 14))
                        else if (isMemberAdmin)
                          const Text('🛡️', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    subtitle: Text(
                      isMemberBlocked
                          ? '🚫 Xabar yozishi cheklangan'
                          : (isMemberOwner ? 'Asosiy Ega' : (isMemberAdmin ? 'Admin' : 'Oddiy A\'zo')),
                      style: TextStyle(
                        fontSize: 12,
                        color: isMemberBlocked ? AppTheme.error : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary),
                      ),
                    ),
                    trailing: isOwner && !isMemberOwner
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onSelected: (val) {
                              if (val == 'toggle_admin') {
                                chatProvider.toggleGroupAdmin(currentConv.id, member.id);
                              } else if (val == 'toggle_block') {
                                chatProvider.toggleGroupBlockMember(currentConv.id, member.id);
                              } else if (val == 'remove') {
                                chatProvider.removeGroupMember(currentConv.id, member.id);
                              }
                            },
                            itemBuilder: (c) => [
                              PopupMenuItem(
                                value: 'toggle_admin',
                                child: Row(
                                  children: [
                                    Icon(isMemberAdmin ? Icons.shield_outlined : Icons.shield_rounded, color: AppTheme.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Text(isMemberAdmin ? "Adminlikni bekor qilish" : "Admin qilish"),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle_block',
                                child: Row(
                                  children: [
                                    Icon(isMemberBlocked ? Icons.lock_open_rounded : Icons.block_rounded, color: Colors.orange, size: 18),
                                    const SizedBox(width: 8),
                                    Text(isMemberBlocked ? "Blokdan chiqarish" : "Guruhda bloklash"),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_remove_rounded, color: AppTheme.error, size: 18),
                                    SizedBox(width: 8),
                                    Text("Guruhdan chiqarish", style: TextStyle(color: AppTheme.error)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : (isAdmin && !isMemberOwner && !isMemberAdmin && member.id != currentUserId
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_rounded, color: AppTheme.error, size: 20),
                                tooltip: "Guruhdan chiqarish",
                                onPressed: () {
                                  chatProvider.removeGroupMember(currentConv.id, member.id);
                                },
                              )
                            : null),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
