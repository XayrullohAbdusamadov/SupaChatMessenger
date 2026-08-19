import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal();

  AudioPlayer? _audioPlayer;
  AudioPlayer? _voiceAudioPlayer;
  Uint8List? _cachedSentWavBytes;
  Uint8List? _cachedIncomingWavBytes;

  void init() {
    _audioPlayer ??= AudioPlayer();
    _voiceAudioPlayer ??= AudioPlayer();
    _cachedSentWavBytes ??= _generateSentWavBytes();
    _cachedIncomingWavBytes ??= _generateIncomingWavBytes();
  }

  /// Plays a warm, crisp Telegram/iOS-style "pop" sound when sending a message
  Future<void> playSentSound() async {
    try {
      init();
      if (_cachedSentWavBytes != null) {
        await _audioPlayer?.stop();
        await _audioPlayer?.play(BytesSource(_cachedSentWavBytes!));
      }
    } catch (e) {
      debugPrint('Error playing sent sound: $e');
    }
  }

  /// Plays a pleasant soft double-bell chime when receiving a message
  Future<void> playIncomingSound() async {
    try {
      init();
      if (_cachedIncomingWavBytes != null) {
        await _audioPlayer?.stop();
        await _audioPlayer?.play(BytesSource(_cachedIncomingWavBytes!));
      }
    } catch (e) {
      debugPrint('Error playing incoming sound: $e');
    }
  }

  /// Legacy alias: plays sent or incoming notification sound
  Future<void> playTiqSound() async {
    await playSentSound();
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

  /// Generates a modern, satisfying Telegram-style message sent "pop" sound
  static Uint8List _generateSentWavBytes() {
    const sampleRate = 44100;
    const durationMs = 110; // 110ms snappy, pleasing bubble-pop
    final numSamples = (sampleRate * durationMs ~/ 1000);
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);

    // ── RIFF Header ───────────────────────────────────────────────
    bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46); // 'RIFF'
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45); // 'WAVE'

    // ── fmt subchunk ──────────────────────────────────────────────
    bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20); // 'fmt '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    bytes.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    bytes.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    bytes.setUint32(24, sampleRate, Endian.little); // SampleRate (44100)
    bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (44100 * 2)
    bytes.setUint16(32, 2, Endian.little);  // BlockAlign
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample

    // ── data subchunk ─────────────────────────────────────────────
    bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61); // 'data'
    bytes.setUint32(40, dataSize, Endian.little);

    // ── Synthesis: Sweet ascending bubble pop with warm harmonics ──
    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate; // Time in seconds
      final progress = i / numSamples;

      // Frequency rises gently from 680Hz to 1120Hz (creates that bubbly upward pop)
      final freq = 680.0 + (440.0 * (1.0 - exp(-t * 40.0)));
      phase += 2 * pi * freq / sampleRate;

      // Envelope: Soft 4ms attack, smooth exponential decay
      double envelope;
      if (t < 0.005) {
        envelope = t / 0.005; // Quick linear fade-in to prevent initial click
      } else {
        envelope = exp(-(t - 0.005) * 28.0);
      }

      // End fade-out (last 5%) to guarantee zero pop
      if (progress > 0.9) {
        envelope *= (1.0 - (progress - 0.9) / 0.1);
      }

      // Warm harmonic combination: Fundamental + gentle 2nd harmonic
      final sample = (sin(phase) * 0.75 + sin(phase * 2.0) * 0.25) * envelope;
      final sampleVal = (sample * 24000).toInt().clamp(-32768, 32767);

      bytes.setInt16(44 + (i * 2), sampleVal, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  /// Generates a pleasant, soft double-bell chime for incoming messages
  static Uint8List _generateIncomingWavBytes() {
    const sampleRate = 44100;
    const durationMs = 180; // 180ms subtle marimba double-chime
    final numSamples = (sampleRate * durationMs ~/ 1000);
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);

    // RIFF Header
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

    // Note 1: 784Hz (G5), Note 2 (starting at 60ms): 1175Hz (D6)
    double phase1 = 0.0;
    double phase2 = 0.0;
    const note2StartMs = 55;
    final note2StartSample = (sampleRate * note2StartMs ~/ 1000);

    for (int i = 0; i < numSamples; i++) {
      final t1 = i / sampleRate;
      phase1 += 2 * pi * 784.0 / sampleRate;
      final env1 = (t1 < 0.005 ? (t1 / 0.005) : exp(-(t1 - 0.005) * 22.0));

      double sample = sin(phase1) * env1 * 0.55;

      if (i >= note2StartSample) {
        final t2 = (i - note2StartSample) / sampleRate;
        phase2 += 2 * pi * 1175.0 / sampleRate;
        final env2 = (t2 < 0.005 ? (t2 / 0.005) : exp(-(t2 - 0.005) * 18.0));
        sample += (sin(phase2) * 0.7 + sin(phase2 * 2.0) * 0.15) * env2 * 0.65;
      }

      final progress = i / numSamples;
      if (progress > 0.9) {
        sample *= (1.0 - (progress - 0.9) / 0.1);
      }

      final sampleVal = (sample * 22000).toInt().clamp(-32768, 32767);
      bytes.setInt16(44 + (i * 2), sampleVal, Endian.little);
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
