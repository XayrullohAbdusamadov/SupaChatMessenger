import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';

class VoiceMessagePlayer extends StatelessWidget {
  final String messageId;
  final int durationSeconds;
  final bool isPlaying;
  final double progress;
  final bool isMe;
  final DateTime createdAt;
  final VoidCallback onPlayToggle;

  const VoiceMessagePlayer({
    super.key,
    required this.messageId,
    required this.durationSeconds,
    required this.isPlaying,
    required this.progress,
    required this.isMe,
    required this.createdAt,
    required this.onPlayToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isMe ? Colors.white70 : (isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary);

    // Generate static waveform bar heights
    final random = Random(messageId.hashCode);
    final List<double> barHeights = List.generate(24, (index) {
      return 6.0 + (random.nextDouble() * 20.0);
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play/Pause Button
              GestureDetector(
                onTap: onPlayToggle,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Audio Waveform
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(barHeights.length, (index) {
                      final barProgress = index / barHeights.length;
                      final isPlayed = isPlaying && barProgress <= progress;

                      Color barColor;
                      if (isMe) {
                        barColor = isPlayed ? Colors.white : Colors.white.withValues(alpha: 0.4);
                      } else {
                        barColor = isPlayed ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.25);
                      }

                      return Container(
                        width: 3,
                        height: barHeights[index],
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormatter.formatDuration(durationSeconds),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: secondaryColor,
                ),
              ),
              Text(
                DateFormatter.formatMessageTime(createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
