import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/user_profile.dart';

class CallOverlay extends StatefulWidget {
  final UserProfile contact;
  final bool isVideoCall;

  const CallOverlay({
    super.key,
    required this.contact,
    required this.isVideoCall,
  });

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoOff = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // BACKGROUND VIDEO OR PATTERN
            if (widget.isVideoCall && !_isVideoOff)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Stack(
                    children: [
                      Center(
                        child: widget.contact.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.contact.avatarUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : const Icon(Icons.person, size: 100, color: Colors.white24),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.6)),
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

                // AVATAR & NAME
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
                          child: widget.contact.avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.contact.avatarUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    widget.contact.fullName[0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.contact.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '@${widget.contact.username}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // MUTE MIC
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        isActive: _isMuted,
                        activeColor: Colors.red,
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
                        onTap: () {
                          setState(() {
                            _isSpeakerOn = !_isSpeakerOn;
                          });
                        },
                      ),

                      // VIDEO TOGGLE (IF VIDEO CALL)
                      if (widget.isVideoCall)
                        _buildControlButton(
                          icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          isActive: _isVideoOff,
                          activeColor: Colors.amber,
                          onTap: () {
                            setState(() {
                              _isVideoOff = !_isVideoOff;
                            });
                          },
                        ),

                      // END CALL (RED)
                      GestureDetector(
                        onTap: () {
                          _timer?.cancel();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Colors.red,
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
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
