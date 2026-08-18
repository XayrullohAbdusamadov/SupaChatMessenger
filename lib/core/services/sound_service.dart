import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal();

  AudioPlayer? _audioPlayer;
  AudioPlayer? _voiceAudioPlayer;
  Uint8List? _cachedTiqWavBytes;

  void init() {
    _audioPlayer ??= AudioPlayer();
    _voiceAudioPlayer ??= AudioPlayer();
    _cachedTiqWavBytes ??= _generateTiqWavBytes();
  }

  Future<void> playTiqSound() async {
    try {
      init();
      if (_cachedTiqWavBytes != null) {
        await _audioPlayer?.stop();
        await _audioPlayer?.play(BytesSource(_cachedTiqWavBytes!));
      }
    } catch (e) {
      debugPrint('Error playing notification tiq sound: $e');
    }
  }

  Future<void> playVoiceTone(int durationSeconds) async {
    try {
      init();
      final wavBytes = _generateVoiceWavBytes(durationSeconds);
      await _voiceAudioPlayer?.stop();
      await _voiceAudioPlayer?.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint('Error playing voice tone: $e');
    }
  }

  Future<void> stopVoicePlayback() async {
    try {
      await _voiceAudioPlayer?.stop();
    } catch (e) {
      debugPrint('Error stopping voice playback: $e');
    }
  }

  /// Generates a short, pleasant "tiq" notification click WAV audio buffer
  static Uint8List _generateTiqWavBytes() {
    const sampleRate = 22050;
    const durationMs = 60; // 60ms subtle click/pop tone
    final numSamples = (sampleRate * durationMs ~/ 1000);
    final dataSize = numSamples * 2; // 16-bit samples
    final fileSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57);  // 'W'
    bytes.setUint8(9, 0x41);  // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    bytes.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    bytes.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    bytes.setUint32(24, sampleRate, Endian.little); // SampleRate
    bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    bytes.setUint16(32, 2, Endian.little);  // BlockAlign
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);

    // Write PCM 16-bit sine pop with fast exponential decay
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final frequency = 1200.0 - (i * 8.0);
      final decay = exp(-i / (numSamples * 0.25));
      final sampleVal = (sin(2 * pi * frequency * t) * decay * 24000).toInt();
      final clamped = sampleVal.clamp(-32768, 32767);
      bytes.setInt16(44 + (i * 2), clamped, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  /// Generates a pleasant voice-like speech harmonic WAV buffer
  static Uint8List _generateVoiceWavBytes(int durationSeconds) {
    const sampleRate = 22050;
    final dur = durationSeconds.clamp(1, 30);
    final numSamples = (sampleRate * dur);
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;
    final bytes = ByteData(44 + dataSize);

    // RIFF header
    bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46);
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45);

    // fmt subchunk
    bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20);
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);

    // data subchunk
    bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61);
    bytes.setUint32(40, dataSize, Endian.little);

    // Human-like vocal formants harmonics
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final f0 = 240.0 + sin(2 * pi * 3.5 * t) * 35.0; // Vocal pitch contour
      final harmonic1 = sin(2 * pi * f0 * t) * 0.5;
      final harmonic2 = sin(2 * pi * f0 * 2.0 * t) * 0.3;
      final harmonic3 = sin(2 * pi * f0 * 3.0 * t) * 0.2;
      final modulation = 0.5 + 0.5 * sin(2 * pi * 4.2 * t); // Speech syllable rhythm
      final sampleVal = ((harmonic1 + harmonic2 + harmonic3) * modulation * 18000).toInt();
      final clamped = sampleVal.clamp(-32768, 32767);
      bytes.setInt16(44 + (i * 2), clamped, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _voiceAudioPlayer?.dispose();
    _voiceAudioPlayer = null;
  }
}
