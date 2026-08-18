import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/voice_recording_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/chat_message.dart';
import 'sticker_picker_sheet.dart';

class ChatInputBar extends StatefulWidget {
  final ChatMessage? replyingTo;
  final ChatMessage? editingMessage;
  final bool isBlocked;
  final VoidCallback? onUnblock;
  final VoidCallback onCancelReplyOrEdit;
  final Function(String text) onSendText;
  final Function(String path, Uint8List? bytes, String name, int size, MessageType type) onSendMedia;
  final Function(String filePath, int durationSeconds) onSendVoice;

  const ChatInputBar({
    super.key,
    this.replyingTo,
    this.editingMessage,
    this.isBlocked = false,
    this.onUnblock,
    required this.onCancelReplyOrEdit,
    required this.onSendText,
    required this.onSendMedia,
    required this.onSendVoice,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VoiceRecordingService _voiceService = VoiceRecordingService.instance;
  bool _hasText = false;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  double _dragOffset = 0.0;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    // Keyboard Enter to send message on Desktop / Computer (Shift+Enter for newline)
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
        if (!isShiftPressed) {
          _handleSend();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null && widget.editingMessage != oldWidget.editingMessage) {
      _textController.text = widget.editingMessage!.content;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
      _focusNode.requestFocus();
    }
  }

  void _onTextChanged() {
    final hasContent = _textController.text.trim().isNotEmpty;
    if (hasContent != _hasText) {
      setState(() {
        _hasText = hasContent;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendText(text);
    _textController.clear();
  }

  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StickerPickerSheet(
        onStickerSelected: (sticker) {
          Navigator.pop(ctx);
          widget.onSendText(sticker);
        },
        onEmojiSelected: (emoji) {
          _textController.text = '${_textController.text}$emoji';
        },
      ),
    );
  }

  void _showAttachmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Text(
                  'Fayl yoki media biriktirish',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.image_rounded,
                      color: const Color(0xFF3B82F6),
                      label: 'Rasm',
                      onTap: () async {
                        Navigator.pop(ctx);
                        _pickImage();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.videocam_rounded,
                      color: const Color(0xFF8B5CF6),
                      label: 'Video',
                      onTap: () async {
                        Navigator.pop(ctx);
                        _pickVideo();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFFEF4444),
                      label: 'Hujjat',
                      onTap: () async {
                        Navigator.pop(ctx);
                        _pickDocument();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.mic_rounded,
                      color: const Color(0xFF10B981),
                      label: 'Ovoz',
                      onTap: () {
                        Navigator.pop(ctx);
                        _startVoiceRecording();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.onSendMedia(
          picked.path,
          bytes,
          picked.name,
          bytes.length,
          MessageType.image,
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.onSendMedia(
          picked.path,
          bytes,
          picked.name,
          bytes.length,
          MessageType.video,
        );
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'zip', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        widget.onSendMedia(
          file.path ?? file.name,
          bytes,
          file.name,
          bytes.length,
          MessageType.doc,
        );
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _startVoiceRecording() async {
    final started = await _voiceService.startRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mikrofon ruxsati berilmadi. Sozlamalardan mikrofonni yoqing.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
      _dragOffset = 0.0;
      _isCancelled = false;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecordingVoice) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  Future<void> _finishVoiceRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecordingVoice) return;

    final result = await _voiceService.stopRecording();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _dragOffset = 0.0;
      _isCancelled = false;
    });

    if (result.path != null && result.durationSeconds > 0) {
      HapticFeedback.lightImpact();
      widget.onSendVoice(result.path!, result.durationSeconds);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _voiceService.cancelRecording();
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _dragOffset = 0.0;
      _isCancelled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // IF BLOCKED: SHOW UNBLOCK BANNER
    if (widget.isBlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        child: SafeArea(
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: AppTheme.error, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Foydalanuvchi bloklangan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.error),
                ),
              ),
              if (widget.onUnblock != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onUnblock,
                  child: const Text('Blokdan chiqarish'),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // REPLY / EDIT BANNER
            if (widget.replyingTo != null || widget.editingMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.bgDark : AppTheme.inputBgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: widget.editingMessage != null ? AppTheme.warning : AppTheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.editingMessage != null ? Icons.edit_rounded : Icons.reply_rounded,
                      size: 18,
                      color: widget.editingMessage != null ? AppTheme.warning : AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.editingMessage != null ? "Xabarni tahrirlash" : "Javob qaytarilmoqda",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.editingMessage != null ? AppTheme.warning : AppTheme.primary,
                            ),
                          ),
                          Text(
                            (widget.editingMessage ?? widget.replyingTo)?.content ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: widget.onCancelReplyOrEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // RECORDING VOICE BAR OR NORMAL INPUT BAR
            if (_isRecordingVoice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isCancelled
                      ? Colors.grey.withValues(alpha: 0.15)
                      : AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isCancelled ? Colors.grey : AppTheme.error.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Flashing red recording dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '0:${_recordingSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Slide to cancel hint with animated chevron
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                          ),
                          Text(
                            'Bekor qilish uchun suring',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cancel button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 22),
                      tooltip: 'Bekor qilish',
                      onPressed: _cancelVoiceRecording,
                    ),

                    // Send / Stop button
                    GestureDetector(
                      onTap: _finishVoiceRecording,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  // Attachment button (+)
                  GestureDetector(
                    onTap: _showAttachmentSheet,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.inputBgDark : AppTheme.inputBgLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.inputBgDark : AppTheme.inputBgLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Xabar yozing...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.sentiment_satisfied_alt_rounded, size: 22),
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textLightSecondary,
                            onPressed: _showStickerSheet,
                          ),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mic / Send Action Circle Button with Press & Hold + Slide-to-cancel gestures
                  GestureDetector(
                    onTap: _hasText ? _handleSend : _startVoiceRecording,
                    onLongPressStart: _hasText
                        ? null
                        : (_) {
                            _startVoiceRecording();
                          },
                    onLongPressMoveUpdate: _hasText
                        ? null
                        : (details) {
                            if (!_isRecordingVoice) return;
                            _dragOffset = details.offsetFromOrigin.dx;
                            if (details.offsetFromOrigin.dx < -70 && !_isCancelled) {
                              setState(() {
                                _isCancelled = true;
                              });
                              HapticFeedback.mediumImpact();
                            }
                          },
                    onLongPressEnd: _hasText
                        ? null
                        : (_) {
                            if (_isCancelled || _dragOffset < -70) {
                              _cancelVoiceRecording();
                            } else {
                              _finishVoiceRecording();
                            }
                          },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _hasText ? Icons.send_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
