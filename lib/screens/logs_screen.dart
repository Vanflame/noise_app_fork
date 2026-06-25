import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/noise_event.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _roomFilter = '';
  String _severityFilter = '';
  String _subjectFilter = '';
  int _currentPage = 1;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();

    final assignedDeviceId = auth.profile?['device_id']?.toString();
    final roleFiltered = data.filterForRole(auth.role, assignedDeviceId);
    final fromStr = _fromDate != null
        ? '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}'
        : '';
    final toStr = _toDate != null
        ? '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}'
        : '';
    final filtered = data
        .filterEvents(
          room: _roomFilter,
          severity: _severityFilter,
          from: fromStr,
          to: toStr,
          subject: _subjectFilter,
        )
        .where((e) => roleFiltered.contains(e))
        .toList();
    final pagination = data.paginate(filtered, _currentPage);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          _buildFilters(data),
          const SizedBox(height: 12),

          // Count
          Text(
            '${pagination.total} record(s) from noise_events · Page ${pagination.page} of ${pagination.totalPages}',
            style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
          ),

          if (pagination.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No records match your filters.',
                  style: TextStyle(color: Color(0xFF8b9cb3)),
                ),
              ),
            )
          else
            ...pagination.items.map((e) => _buildEventCard(e, auth.isAdmin)),

          // Pagination
          if (pagination.totalPages > 1) _buildPagination(pagination),
        ],
      ),
    );
  }

  Widget _buildFilters(DataProvider data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dateFilterField(
                  'From',
                  _fromDate,
                  (d) => setState(() {
                    _fromDate = d;
                    _currentPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateFilterField(
                  'To',
                  _toDate,
                  (d) => setState(() {
                    _toDate = d;
                    _currentPage = 1;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _roomFilter.isEmpty ? null : _roomFilter,
                  decoration: _inputDeco('Room / Device'),
                  dropdownColor: const Color(0xFF243044),
                  style: const TextStyle(
                    color: Color(0xFFe8edf4),
                    fontSize: 13,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'All',
                        style: TextStyle(color: Color(0xFFe8edf4)),
                      ),
                    ),
                    ...data.roomList.map(
                      (r) => DropdownMenuItem(value: r, child: Text(r)),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _roomFilter = v ?? '';
                    _currentPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _severityFilter.isEmpty ? null : _severityFilter,
                  decoration: _inputDeco('Severity'),
                  dropdownColor: const Color(0xFF243044),
                  style: const TextStyle(
                    color: Color(0xFFe8edf4),
                    fontSize: 13,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        'All',
                        style: TextStyle(color: Color(0xFFe8edf4)),
                      ),
                    ),
                    DropdownMenuItem(value: 'green', child: Text('Green')),
                    DropdownMenuItem(value: 'yellow', child: Text('Yellow')),
                    DropdownMenuItem(value: 'red', child: Text('Red')),
                  ],
                  onChanged: (v) => setState(() {
                    _severityFilter = v ?? '';
                    _currentPage = 1;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: _inputDeco('Subject / Teacher'),
                  style: const TextStyle(
                    color: Color(0xFFe8edf4),
                    fontSize: 13,
                  ),
                  onChanged: (v) => setState(() {
                    _subjectFilter = v;
                    _currentPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                    _roomFilter = '';
                    _severityFilter = '';
                    _subjectFilter = '';
                    _currentPage = 1;
                  });
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Color(0xFF38bdf8), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateFilterField(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF38bdf8),
                  surface: Color(0xFF1a2332),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF243044),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2d3a4f)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Color(0xFF8b9cb3),
            ),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                  : label,
              style: TextStyle(
                color: date != null
                    ? const Color(0xFFe8edf4)
                    : const Color(0xFF8b9cb3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF243044),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2d3a4f)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2d3a4f)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF38bdf8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildEventCard(NoiseEvent e, bool isAdmin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF243044),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${e.date} ${e.time}',
                  style: const TextStyle(
                    color: Color(0xFFe8edf4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusPill(e.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _field('Room', e.room),
              const SizedBox(width: 16),
              _field('Noise', '${e.db} dB'),
              const SizedBox(width: 16),
              _field('Level', e.warningLevel.isNotEmpty ? e.warningLevel : '—'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _field('Duration', e.durationSec > 0 ? '${e.durationSec}s' : '—'),
              const SizedBox(width: 16),
              _boolField('Buzzer', e.buzzer),
              const SizedBox(width: 16),
              _boolField('Audio', e.audioRecorded),
              const Spacer(),
              if (e.status == 'red' && e.audioRecorded && e.audioUrl != null)
                TextButton.icon(
                  onPressed: () => _playAudio(e),
                  icon: Icon(
                    _currentlyPlayingId == e.id ? Icons.stop : Icons.play_arrow,
                    size: 16,
                    color: Color(0xFF38bdf8),
                  ),
                  label: Text(
                    _currentlyPlayingId == e.id ? 'Stop' : 'Play Clip',
                    style: TextStyle(color: Color(0xFF38bdf8), fontSize: 11),
                  ),
                ),
            ],
          ),
          if (e.subject != '—' || e.teacher != '—') ...[
            const SizedBox(height: 4),
            Text(
              '${e.subject} · ${e.teacher}',
              style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 9),
        ),
        Text(
          value,
          style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 12),
        ),
      ],
    );
  }

  Widget _boolField(String label, bool value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 9),
        ),
        Text(
          value ? 'Yes' : 'No',
          style: TextStyle(
            color: value ? const Color(0xFF22c55e) : const Color(0xFF8b9cb3),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String status) {
    Color color;
    switch (status) {
      case 'green':
        color = const Color(0xFF22c55e);
        break;
      case 'yellow':
        color = const Color(0xFFeab308);
        break;
      default:
        color = const Color(0xFFef4444);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPagination(PaginationResult<NoiseEvent> pag) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${pag.startIndex}–${pag.endIndex} of ${pag.total}',
            style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
          ),
          Row(
            children: [
              _pageBtn(
                '← Prev',
                _currentPage > 1,
                () => setState(() => _currentPage--),
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${pag.page} / ${pag.totalPages}',
                style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 12),
              ),
              const SizedBox(width: 8),
              _pageBtn(
                'Next →',
                _currentPage < pag.totalPages,
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
            color: enabled ? null : Colors.transparent,
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

        // Listen for playback completion
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _currentlyPlayingId = null);
          }
        });

        // Errors are handled by the try/catch block below
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio'),
            backgroundColor: Color(0xFFef4444),
          ),
        );
        setState(() => _currentlyPlayingId = null);
      }
    }
  }

  @override
  void deactivate() {
    // Stop audio when leaving the screen
    _audioPlayer.stop();
    super.deactivate();
  }
}
