import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';

/// Animated equalizer waveform visualizer reacting to microphone audio amplitude.
class AudioWaveformVisualizer extends StatelessWidget {
  final Stream<double> amplitudeStream;
  final bool isRecording;

  const AudioWaveformVisualizer({
    super.key,
    required this.amplitudeStream,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: amplitudeStream,
      initialData: 0.1,
      builder: (context, snapshot) {
        final double currentAmp = snapshot.data ?? 0.1;

        return SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (index) {
              // Create dynamic wave curve offset
              final double factor = (index < 12 ? (index + 1) / 12 : (24 - index) / 12);
              final double barHeight = isRecording
                  ? (12 + (currentAmp * 50 * factor)).clamp(8.0, 64.0)
                  : 8.0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 70),
                width: 4,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isRecording ? LedgifyColors.primaryBlue : LedgifyColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
