import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecordingService {
  static final VoiceRecordingService instance = VoiceRecordingService._internal();
  VoiceRecordingService._internal();

  AudioRecorder? _audioRecorder;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) return true;

      _audioRecorder ??= AudioRecorder();
      return await _audioRecorder!.hasPermission();
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    try {
      final hasPerm = await requestPermission();
      if (!hasPerm) {
        debugPrint('Microphone permission not granted');
        return false;
      }

      _audioRecorder ??= AudioRecorder();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/voice_recording_$timestamp.m4a';
      _currentRecordingPath = filePath;

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder!.start(config, path: filePath);
      _recordingStartTime = DateTime.now();
      _isRecording = true;
      debugPrint('Voice recording started at: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<({String? path, int durationSeconds})> stopRecording() async {
    if (!_isRecording || _audioRecorder == null) {
      return (path: null, durationSeconds: 0);
    }

    try {
      final path = await _audioRecorder!.stop();
      _isRecording = false;

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;

      final recordedPath = path ?? _currentRecordingPath;
      final finalDuration = duration > 0 ? duration : 1;

      if (recordedPath != null && File(recordedPath).existsSync()) {
        debugPrint('Voice recording stopped. Path: $recordedPath, Duration: ${finalDuration}s');
        return (path: recordedPath, durationSeconds: finalDuration);
      }
      return (path: null, durationSeconds: 0);
    } catch (e) {
      debugPrint('Error stopping voice recording: $e');
      _isRecording = false;
      return (path: null, durationSeconds: 0);
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording || _audioRecorder == null) return;
    try {
      final path = await _audioRecorder!.stop();
      _isRecording = false;
      _recordingStartTime = null;

      final targetPath = path ?? _currentRecordingPath;
      if (targetPath != null) {
        final file = File(targetPath);
        if (file.existsSync()) {
          await file.delete();
          debugPrint('Cancelled and deleted voice recording: $targetPath');
        }
      }
    } catch (e) {
      debugPrint('Error cancelling voice recording: $e');
      _isRecording = false;
    }
  }

  void dispose() {
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
