import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service managing microphone audio capture, live amplitude streaming, and M4A voice encoding.
class AudioRecordingService {
  final AudioRecorder _recorder;
  Timer? _amplitudeTimer;
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  AudioRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  /// Live normalized Decibel/Amplitude stream (0.0 to 1.0) for UI waveforms
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Starts recording voice note in lightweight AAC-LC format
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted / माइक्रोफोन अनुमति नहीं मिली');
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_voucher_${DateTime.now().millisecondsSinceEpoch}.m4a';

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 16000,
      bitRate: 32000,
      numChannels: 1,
    );

    await _recorder.start(config, path: filePath);

    // Poll amplitude at 60ms intervals for responsive waveform visualizer
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) async {
      final amp = await _recorder.getAmplitude();
      // Normalize dBFS (-60 dB to 0 dB) into [0.0, 1.0] range
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    });
  }

  /// Stops recording and returns the path to the recorded audio file
  Future<String?> stopRecording() async {
    _amplitudeTimer?.cancel();
    final path = await _recorder.stop();
    return path;
  }

  /// Cancels and deletes the in-progress recording
  Future<void> cancelRecording() async {
    _amplitudeTimer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Checks if currently recording
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
