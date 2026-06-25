import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/noise_event.dart';
import '../config/app_config.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  int _currentPage = 1;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final settings = data.settings;

    if (!auth.isAdmin) {
      return const Center(
        child: Text(
          'Audio Evidence is admin-only.',
          style: TextStyle(color: Color(0xFF8b9cb3)),
        ),
      );
    }

    final allClips = data.getRedAudioClips('admin', null);
    final retentionDays =
        settings['retentionDays'] ?? AppConfig.defaultSettings['retentionDays'];
    final totalPages = (allClips.length / AppConfig.logsPageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final start = (safePage - 1) * AppConfig.logsPageSize;
    final end = min(start + AppConfig.logsPageSize, allClips.length);
    final clips = allClips.length > 0
        ? allClips.sublist(start, end)
        : <NoiseEvent>[];

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
              border: Border.all(
                color: const Color(0xFF38bdf8).withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Official policy',
                  style: TextStyle(
                    color: Color(0xFF38bdf8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Audio from noise_events (audio_url). Event-triggered, short, access-controlled. No continuous recording.\n\n'
                  'RED only · ${allClips.length} clip(s) with audio · Retention $retentionDays days',
                  style: const TextStyle(
                    color: Color(0xFF8b9cb3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (clips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No RED events with audio_url in noise_events.',
                  style: TextStyle(color: Color(0xFF8b9cb3)),
                ),
              ),
            )
          else
            ...clips.map((e) => _audioCard(context, e)),

          // Pagination
          if (totalPages > 1)
            _buildPagination(allClips.length, safePage, totalPages),
        ],
      ),
    );
  }

  Widget _audioCard(BuildContext context, NoiseEvent e) {
    final recordingId = e.id.length > 8
        ? e.id.substring(0, 8).toUpperCase()
        : e.id.toUpperCase();
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
          Text(
            e.room,
            style: const TextStyle(
              color: Color(0xFFe8edf4),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${e.date} ${e.time} · ${audioLengthMax}s · $recordingId',
            style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${e.db} dB',
                style: const TextStyle(
                  color: Color(0xFFef4444),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'RED',
                  style: TextStyle(
                    color: Color(0xFFef4444),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (e.warningLevel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  e.warningLevel,
                  style: const TextStyle(
                    color: Color(0xFF8b9cb3),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: e.audioUrl != null && e.audioUrl!.isNotEmpty
                    ? () => _playAudio(e)
                    : null,
                icon: Icon(
                  _currentlyPlayingId == e.id ? Icons.stop : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(
                  _currentlyPlayingId == e.id
                      ? 'Stop'
                      : '▶  ${audioLengthMax}s',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38bdf8),
                  foregroundColor: const Color(0xFF0f1419),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
          Text(
            'Expires in ~11 days · Retention 14 days',
            style: TextStyle(color: const Color(0xFFeab308), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _playAudio(NoiseEvent e) async {
    if (_currentlyPlayingId == e.id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
      return;
    }

    try {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = e.id);

      if (e.audioUrl != null && e.audioUrl!.isNotEmpty) {
        await _audioPlayer.play(UrlSource(e.audioUrl!));

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _currentlyPlayingId = null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: const Color(0xFFef4444),
          ),
        );
        setState(() => _currentlyPlayingId = null);
      }
    }
  }

  Widget _buildPagination(int total, int current, int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(current - 1) * AppConfig.logsPageSize + 1}–${min(current * AppConfig.logsPageSize, total)} of $total',
            style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
          ),
          Row(
            children: [
              _pageBtn(
                '← Prev',
                current > 1,
                () => setState(() => _currentPage--),
              ),
              const SizedBox(width: 8),
              Text(
                'Page $current / $totalPages',
                style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 12),
              ),
              const SizedBox(width: 8),
              _pageBtn(
                'Next →',
                current < totalPages,
                () => setState(() => _currentPage++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn(String label, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF2d3a4f)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled
                  ? const Color(0xFFe8edf4)
                  : const Color(0xFF8b9cb3).withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ),
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
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
