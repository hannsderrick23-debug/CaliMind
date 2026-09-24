import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  bool get isRecording => _currentPath != null;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<String?> startRecording() async {
    try {
      final permitted = await hasPermission();
      if (!permitted) return null;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _currentPath = filePath;
      return filePath;
    } catch (e) {
      debugPrint('Audio recording start error: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _currentPath = null;
      return path;
    } catch (e) {
      debugPrint('Audio recording stop error: $e');
      _currentPath = null;
      return null;
    }
  }

  Future<void> cancel() async {
    try {
      await _recorder.cancel();
      if (_currentPath != null) {
        final f = File(_currentPath!);
        if (await f.exists()) {
          await f.delete();
        }
        _currentPath = null;
      }
    } catch (_) {}
  }
}
