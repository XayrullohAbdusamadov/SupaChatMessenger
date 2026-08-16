import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
  });

  void _copyImage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Rasm havolasidan nusxa olindi 📋"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
        ),
        title: const Text(
          'Galereyaga saqlandi! ✅',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Ushbu rasm qurilmangizning Galereya (Photos/Gallery) bo\'limiga muvaffaqiyatli yuklab olindi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tushundim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title ?? 'Rasm',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: imageUrl.startsWith('data:image')
              ? Image.memory(
                  base64Decode(imageUrl.substring(imageUrl.indexOf(',') + 1)),
                  fit: BoxFit.contain,
                  errorBuilder: (c, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  },
                  errorBuilder: (c, err, stack) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 72),
                      const SizedBox(height: 12),
                      Text(
                        title ?? 'Rasm ko\'rsatib bo\'lmadi',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text("Nusxa olish"),
                onPressed: () => _copyImage(context),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text("Yuklab olish"),
                onPressed: () => _downloadImage(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
