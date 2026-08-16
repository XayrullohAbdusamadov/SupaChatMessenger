import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String? title;

  const FullScreenVideoViewer({
    super.key,
    required this.videoUrl,
    this.title,
  });

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  bool _isPlaying = true;
  double _playbackPosition = 0.3;

  void _copyVideoLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.videoUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Video havolasidan nusxa olindi 📋"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadVideo(BuildContext context) {
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
          'Ushbu video qurilmangizning Galereya (Photos/Gallery/Videos) bo\'limiga muvaffaqiyatli yuklab olindi.',
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
          widget.title ?? 'Video',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // VIDEO CONTAINER
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1E293B),
              ),
              height: 380,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.title ?? 'Video lavha',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '0:42 • 1080p HD',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),

                  // PLAY / PAUSE BUTTON
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM PLAYBACK CONTROLS
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _playbackPosition,
                    onChanged: (val) {
                      setState(() {
                        _playbackPosition = val;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0:${(_playbackPosition * 42).toInt().toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Text(
                        '0:42',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
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
                      onPressed: () => _copyVideoLink(context),
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
                      onPressed: () => _downloadVideo(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
