import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacherId = context.read<AuthProvider>().userId;
      if (teacherId.isNotEmpty) {
        context.read<DataProvider>().loadSchedules(teacherId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final schedules = data.getTeacherSchedules(auth.userId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Schedule',
                style: TextStyle(color: Color(0xFFe8edf4), fontSize: 18, fontWeight: FontWeight.w600)),
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(context, data, auth.userId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38bdf8),
                  foregroundColor: const Color(0xFF0f1419),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No schedules yet.\nTap "Add" to create one.',
                style: TextStyle(color: Color(0xFF8b9cb3)), textAlign: TextAlign.center)),
            )
          else
            ...schedules.map((s) => _scheduleCard(context, s, data, auth.userId)),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, Map<String, dynamic> s, DataProvider data, String teacherId) {
    final day = s['day'] ?? '—';
    final start = s['start_time'] ?? '--:--';
    final end = s['end_time'] ?? '--:--';
    final subject = s['subject'] ?? '';
    final room = s['room'] ?? '';
    final id = s['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Day badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF38bdf8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(day.substring(0, 3).toUpperCase(),
                style: const TextStyle(color: Color(0xFF38bdf8), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject.isNotEmpty)
                  Text(subject,
                    style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
                if (subject.isNotEmpty) const SizedBox(height: 2),
                Text('$start – $end',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
                if (room.isNotEmpty)
                  Text('Room: $room',
                    style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11)),
              ],
            ),
          ),
          // Actions
          IconButton(
            onPressed: () => _showEditDialog(context, data, teacherId, schedule: s),
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF38bdf8)),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1a2332),
                  title: const Text('Delete schedule?', style: TextStyle(color: Color(0xFFe8edf4))),
                  content: const Text('This action cannot be undone.', style: TextStyle(color: Color(0xFF8b9cb3))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFef4444)))),
                  ],
                ),
              );
              if (confirm == true && id.isNotEmpty) {
                await data.deleteSchedule(id);
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFef4444)),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, DataProvider data, String teacherId, {Map<String, dynamic>? schedule}) async {
    final isEdit = schedule != null;
    String selectedDay = schedule?['day'] ?? 'Monday';
    TimeOfDay? startTimeOfDay = _parseTime(schedule?['start_time'] ?? '08:00');
    TimeOfDay? endTimeOfDay = _parseTime(schedule?['end_time'] ?? '09:00');
    final subjectCtrl = TextEditingController(text: schedule?['subject'] ?? '');
    final roomCtrl = TextEditingController(text: schedule?['room'] ?? '');

    String _formatTime(TimeOfDay? time) {
      if (time == null) return 'Not set';
      final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
    }

    String _timeTo24Hour(TimeOfDay? time) {
      if (time == null) return '00:00';
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a2332),
          title: Text(isEdit ? 'Edit Schedule' : 'New Schedule',
            style: const TextStyle(color: Color(0xFFe8edf4))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: _inputDeco('Day'),
                  dropdownColor: const Color(0xFF243044),
                  style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                    DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                    DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                    DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                    DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                    DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                    DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedDay = v ?? 'Monday'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Start Time', style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
                  trailing: Text(_formatTime(startTimeOfDay), style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 14)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: startTimeOfDay ?? const TimeOfDay(hour: 8, minute: 0),
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
                      setDialogState(() => startTimeOfDay = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('End Time', style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
                  trailing: Text(_formatTime(endTimeOfDay), style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 14)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: endTimeOfDay ?? const TimeOfDay(hour: 9, minute: 0),
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
                      setDialogState(() => endTimeOfDay = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _field('Subject (optional)', subjectCtrl),
                const SizedBox(height: 12),
                _field('Room (optional)', roomCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final start24 = _timeTo24Hour(startTimeOfDay);
                final end24 = _timeTo24Hour(endTimeOfDay);
                
                // Check for conflicts
                final hasConflict = await _checkTimeConflict(data, teacherId, selectedDay, start24, end24, isEdit ? (schedule?['id']?.toString() ?? '') : '');
                if (hasConflict) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This time slot conflicts with another schedule.'), backgroundColor: Color(0xFFef4444)),
                    );
                  }
                  return;
                }

                final newSchedule = {
                  'teacher_id': teacherId,
                  'day': selectedDay,
                  'start_time': start24,
                  'end_time': end24,
                  'subject': subjectCtrl.text.trim(),
                  'room': roomCtrl.text.trim(),
                };
                if (isEdit && schedule['id'] != null) {
                  await data.updateSchedule(schedule['id'].toString(), newSchedule);
                } else {
                  await data.addSchedule(newSchedule);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38bdf8), foregroundColor: const Color(0xFF0f1419)),
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkTimeConflict(DataProvider data, String teacherId, String day, String startTime, String endTime, String? excludeId) async {
    final allSchedules = data.getTeacherSchedules(teacherId);
    final newStart = _timeToMinutes(startTime);
    final newEnd = _timeToMinutes(endTime);

    for (final s in allSchedules) {
      if (excludeId != null && s['id']?.toString() == excludeId) continue;
      if (s['day']?.toString() != day) continue;

      final existingStart = _timeToMinutes(s['start_time']?.toString() ?? '00:00');
      final existingEnd = _timeToMinutes(s['end_time']?.toString() ?? '23:59');

      // Check if time ranges overlap
      if (newStart < existingEnd && newEnd > existingStart) {
        return true;
      }
    }
    return false;
  }

  TimeOfDay? _parseTime(String time24h) {
    final parts = time24h.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Color(0xFFe8edf4)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8b9cb3)),
          filled: true,
          fillColor: const Color(0xFF243044),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2d3a4f))),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8b9cb3)),
      filled: true,
      fillColor: const Color(0xFF243044),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2d3a4f))),
    );
  }
}