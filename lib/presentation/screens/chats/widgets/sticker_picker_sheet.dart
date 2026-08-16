import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StickerPickerSheet extends StatefulWidget {
  final Function(String stickerText) onStickerSelected;
  final Function(String emoji) onEmojiSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
    required this.onEmojiSelected,
  });

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _popularStickers = [
    '😎', '🔥', '🚀', '🥳', '🤩', '✨', '💯', '👏',
    '❤️', '💖', '😍', '🥰', '😘', '😻', '💐', '🌹',
    '😂', '🤣', '😆', '😜', '🤪', '😇', '🤖', '👑',
    '👍', '👌', '✌️', '💪', '🙌', '🤝', '🎉', '🏆',
  ];

  final List<String> _animalStickers = [
    '🐱', '🐶', '🐼', '🦊', '🦁', '🐯', '🐨', '🐻',
    '🐰', '🐹', '🐭', '🐸', '🐵', '🦄', '🐝', '🦋',
    '🦉', '🦅', '🦆', '🐧', '🐬', '🐳', '🐙', '🐢',
  ];

  final List<String> _emotionStickers = [
    '😀', '😃', '😄', '😁', '😆', '🥹', '😅', '😂',
    '🤣', '🥲', '☺️', '😊', '😇', '🙂', '🙃', '😉',
    '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋',
    '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎',
    '🥸', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟',
    '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺',
    '😢', '😭', '😮‍💨', '😤', '😠', '😡', '🤬', '🤯',
  ];

  final List<String> _lifeStickers = [
    '💼', '💻', '📱', '☕', '🍕', '🍔', '🍦', '🍩',
    '⚽', '🏀', '🎾', '🚗', '✈️', '🏖️', '🏔️', '🏕️',
    '🎮', '🎧', '🎬', '📚', '💡', '⏰', '🎁', '🎈',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // DRAG HANDLE
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // TAB BAR
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: '🔥 Ommabop'),
              Tab(text: '😀 Emodzilar'),
              Tab(text: '🐱 Hayvonlar'),
              Tab(text: '☕ Kundalik'),
            ],
          ),

          // TAB BAR VIEW
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(_popularStickers, isLarge: true),
                _buildGrid(_emotionStickers, isLarge: false),
                _buildGrid(_animalStickers, isLarge: true),
                _buildGrid(_lifeStickers, isLarge: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<String> items, {required bool isLarge}) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLarge ? 4 : 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            widget.onStickerSelected(item);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLarge ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.cardDark : AppTheme.inputBgLight) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              item,
              style: TextStyle(fontSize: isLarge ? 34 : 26),
            ),
          ),
        );
      },
    );
  }
}
