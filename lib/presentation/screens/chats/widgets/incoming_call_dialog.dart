import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/call_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/call_model.dart';
import 'call_overlay.dart';

class IncomingCallDialog extends StatelessWidget {
  final CallModel call;

  const IncomingCallDialog({
    super.key,
    required this.call,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = call.callType == CallType.video;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Caller Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: call.callerAvatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: call.callerAvatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
                      )
                    : _buildAvatarPlaceholder(),
              ),
            ),
            const SizedBox(height: 20),

            // Caller Name
            Text(
              call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Call Type Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isVideo ? 'Kiruvchi video qo\'ng\'iroq...' : 'Kiruvchi ovozli qo\'ng\'iroq...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Action Buttons (Reject / Accept)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        CallService.instance.rejectCall();
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Rad etish', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),

                // Accept Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        CallService.instance.acceptCall();
                        Navigator.of(context, rootNavigator: true).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallOverlay(
                              callId: call.id,
                              contactName: call.callerName,
                              contactAvatarUrl: call.callerAvatarUrl,
                              isVideoCall: isVideo,
                              chatId: call.chatId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Qabul qilish', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: AppTheme.primary,
      child: Center(
        child: Text(
          call.callerName.isNotEmpty ? call.callerName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
