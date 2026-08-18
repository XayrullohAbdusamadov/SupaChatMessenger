import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/call_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/chat_message.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../providers/chat_provider.dart';

class CallOverlay extends StatefulWidget {
  final String? callId;
  final String contactName;
  final String? contactAvatarUrl;
  final bool isVideoCall;
  final String chatId;
  final UserProfile? contact;

  const CallOverlay({
    super.key,
    this.callId,
    required this.contactName,
    this.contactAvatarUrl,
    required this.isVideoCall,
    required this.chatId,
    this.contact,
  });

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCallTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _handleEndCall() {
    _timer?.cancel();
    final durationStr = _formatCallTime(_seconds);

    // Call service end call
    CallService.instance.endCall();

    // Log call event in chat history
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final currentUserId = chatProvider.currentActiveUserId ?? 'user';
      final callTypeText = widget.isVideoCall ? 'Video qo\'ng\'iroq' : 'Ovozli qo\'ng\'iroq';

      chatProvider.sendMessage(
        senderId: currentUserId,
        content: '📞 $callTypeText — $durationStr',
        type: MessageType.text,
      );
    } catch (_) {}

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // BACKGROUND VIDEO OR CAMERA SIMULATION
            if (widget.isVideoCall && !_isVideoOff)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Stack(
                    children: [
                      Center(
                        child: widget.contactAvatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.contactAvatarUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorWidget: (context, url, error) => const Icon(Icons.person, size: 100, color: Colors.white24),
                              )
                            : const Icon(Icons.person, size: 100, color: Colors.white24),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.5)),

                      // Floating Self-Camera PiP Preview
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          width: 100,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Center(
                                  child: Icon(
                                    _isFrontCamera ? Icons.face_rounded : Icons.camera_alt_rounded,
                                    color: Colors.white38,
                                    size: 36,
                                  ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isFrontCamera = !_isFrontCamera;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // MAIN CALL CONTENT
            Column(
              children: [
                const SizedBox(height: 40),
                // HEADER CALL TYPE
                Text(
                  widget.isVideoCall ? 'SupaChat Video Qo\'ng\'iroq' : 'SupaChat Ovozli Qo\'ng\'iroq',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // TIMER / CONNECTING
                Text(
                  _seconds > 0 ? _formatCallTime(_seconds) : 'Ulanmoqda...',
                  style: TextStyle(
                    color: _seconds > 0 ? AppTheme.tertiary : Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),

                // AVATAR & NAME (Only if audio call or video is off)
                if (!widget.isVideoCall || _isVideoOff)
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primary, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: widget.contactAvatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: widget.contactAvatarUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
                                  )
                                : _buildAvatarPlaceholder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.contactName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (widget.contact != null)
                          Text(
                            '@${widget.contact!.username}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),

                const Spacer(),

                // CALL CONTROLS BAR
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // MUTE MIC
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        isActive: _isMuted,
                        activeColor: AppTheme.error,
                        tooltip: _isMuted ? 'Mikrofonni yoqish' : 'Mikrofonni o\'chirish',
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                        },
                      ),

                      // SPEAKER
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        isActive: _isSpeakerOn,
                        activeColor: AppTheme.primary,
                        tooltip: _isSpeakerOn ? 'Ovoz karnayda' : 'Oddiy ovoz',
                        onTap: () {
                          setState(() {
                            _isSpeakerOn = !_isSpeakerOn;
                          });
                        },
                      ),

                      // FLIP CAMERA (IF VIDEO CALL)
                      if (widget.isVideoCall)
                        _buildControlButton(
                          icon: Icons.flip_camera_ios_rounded,
                          isActive: false,
                          activeColor: AppTheme.primary,
                          tooltip: 'Kamerani almashtirish',
                          onTap: () {
                            setState(() {
                              _isFrontCamera = !_isFrontCamera;
                            });
                          },
                        ),

                      // VIDEO TOGGLE (IF VIDEO CALL)
                      if (widget.isVideoCall)
                        _buildControlButton(
                          icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          isActive: _isVideoOff,
                          activeColor: Colors.amber,
                          tooltip: _isVideoOff ? 'Kamerani yoqish' : 'Kamerani o\'chirish',
                          onTap: () {
                            setState(() {
                              _isVideoOff = !_isVideoOff;
                            });
                          },
                        ),

                      // END CALL (RED)
                      GestureDetector(
                        onTap: _handleEndCall,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
          widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
