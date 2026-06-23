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
    final dayCtrl = TextEditingController(text: schedule?['day'] ?? 'Monday');
    final startCtrl = TextEditingController(text: schedule?['start_time'] ?? '08:00');
    final endCtrl = TextEditingController(text: schedule?['end_time'] ?? '09:00');
    final subjectCtrl = TextEditingController(text: schedule?['subject'] ?? '');
    final roomCtrl = TextEditingController(text: schedule?['room'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a2332),
        title: Text(isEdit ? 'Edit Schedule' : 'New Schedule',
          style: const TextStyle(color: Color(0xFFe8edf4))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Day (e.g. Monday)', dayCtrl),
              _field('Start time (HH:MM)', startCtrl),
              _field('End time (HH:MM)', endCtrl),
              _field('Subject (optional)', subjectCtrl),
              _field('Room (optional)', roomCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newSchedule = {
                'teacher_id': teacherId,
                'day': dayCtrl.text.trim(),
                'start_time': startCtrl.text.trim(),
                'end_time': endCtrl.text.trim(),
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
    );
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
}