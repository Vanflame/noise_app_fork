import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/noise_event.dart';
import '../config/app_config.dart';

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final settings = data.settings;

    if (!auth.isAdmin) {
      return const Center(
        child: Text('Audio Evidence is admin-only.',
          style: TextStyle(color: Color(0xFF8b9cb3))),
      );
    }

    final clips = data.getRedAudioClips('admin', null);
    final retentionDays = settings['retentionDays'] ?? AppConfig.defaultSettings['retentionDays'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Policy banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF38bdf8).withValues(alpha: 0.08),
              border: Border.all(color: const Color(0xFF38bdf8).withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Official policy',
                  style: TextStyle(color: Color(0xFF38bdf8), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Audio from noise_events (audio_url). Event-triggered, short, access-controlled. No continuous recording.\n\n'
                  'RED only · ${clips.length} clip(s) with audio · Retention $retentionDays days',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (clips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No RED events with audio_url in noise_events.',
                style: TextStyle(color: Color(0xFF8b9cb3)))),
            )
          else
            ...clips.map((e) => _audioCard(context, e)),
        ],
      ),
    );
  }

  Widget _audioCard(BuildContext context, NoiseEvent e) {
    final recordingId = e.id.length > 8 ? e.id.substring(0, 8).toUpperCase() : e.id.toUpperCase();
    final audioLengthMax = 5; // default max

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.room,
            style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${e.date} ${e.time} · ${audioLengthMax}s · $recordingId',
            style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${e.db} dB',
                style: const TextStyle(color: Color(0xFFef4444), fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('RED',
                  style: TextStyle(color: Color(0xFFef4444), fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              if (e.warningLevel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(e.warningLevel,
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // In a real app, would open the audio URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio URL available')),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text('▶  ${audioLengthMax}s'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38bdf8),
                  foregroundColor: const Color(0xFF0f1419),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF243044),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CustomPaint(
                    painter: _WaveformPainter(const Color(0xFF2d3a4f)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Expires in ~11 days · Retention 14 days',
            style: TextStyle(color: const Color(0xFFeab308), fontSize: 10)),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 6) {
      final h = (x * 3).toInt() % 20 + 5;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}