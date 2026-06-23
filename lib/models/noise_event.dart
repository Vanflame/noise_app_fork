class NoiseEvent {
  final String id;
  final String date;
  final String time;
  final String datetime;
  final String room;
  final String deviceId;
  final double db;
  final String status;
  final String warningColor;
  final String warningLevel;
  final bool buzzer;
  final bool audioRecorded;
  final String? audioUrl;
  final int durationSec;
  final String subject;
  final String teacher;
  final String? classroomId;
  final String? eventGroupId;
  final String createdAt;

  NoiseEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.datetime,
    required this.room,
    required this.deviceId,
    required this.db,
    required this.status,
    required this.warningColor,
    required this.warningLevel,
    required this.buzzer,
    required this.audioRecorded,
    this.audioUrl,
    required this.durationSec,
    required this.subject,
    required this.teacher,
    this.classroomId,
    this.eventGroupId,
    required this.createdAt,
  });

  factory NoiseEvent.fromJson(Map<String, dynamic> row) {
    final dt = row['event_time_utc'] ?? row['created_at'] ?? '';
    final d = DateTime.tryParse(dt.toString()) ?? DateTime.now();
    final color = (row['warning_color'] ?? 'RED').toString().toLowerCase();
    String status = 'red';
    if (color == 'green' || color == 'yellow') status = color;
    else if (color == 'red') status = 'red';

    return NoiseEvent(
      id: row['id']?.toString() ?? '',
      date: d.toIso8601String().substring(0, 10),
      time: '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
      datetime: dt.toString(),
      room: row['room']?.toString() ?? row['device_id']?.toString() ?? '—',
      deviceId: row['device_id']?.toString() ?? '',
      db: (row['decibel'] is num) ? (row['decibel'] as num).toDouble() : 0.0,
      status: status,
      warningColor: row['warning_color']?.toString() ?? '',
      warningLevel: row['warning_level']?.toString() ?? '',
      buzzer: row['buzzer_triggered'] == true,
      audioRecorded: row['audio_recorded'] == true,
      audioUrl: row['audio_url']?.toString(),
      durationSec: (row['duration_seconds'] is num) ? (row['duration_seconds'] as num).toInt() : 0,
      subject: row['subject']?.toString() ?? '—',
      teacher: row['teacher_name']?.toString() ?? '—',
      classroomId: row['classroom_id']?.toString(),
      eventGroupId: row['event_group_id']?.toString(),
      createdAt: row['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'time': time,
    'datetime': datetime,
    'room': room,
    'device_id': deviceId,
    'decibel': db,
    'status': status,
    'warning_color': warningColor,
    'warning_level': warningLevel,
    'buzzer_triggered': buzzer,
    'audio_recorded': audioRecorded,
    'audio_url': audioUrl,
    'duration_seconds': durationSec,
    'subject': subject,
    'teacher_name': teacher,
    'classroom_id': classroomId,
    'event_group_id': eventGroupId,
    'created_at': createdAt,
  };
}