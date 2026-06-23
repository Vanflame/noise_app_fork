class AuditLog {
  final String action;
  final String user;
  final String time;
  final String detail;

  AuditLog({
    required this.action,
    required this.user,
    required this.time,
    required this.detail,
  });

  factory AuditLog.fromJson(Map<String, dynamic> row) {
    final time = row['created_at'] != null
        ? _formatDateTime(row['created_at'].toString())
        : row['time']?.toString() ?? '—';
    return AuditLog(
      action: row['action']?.toString() ?? row['event_type']?.toString() ?? 'Event',
      user: row['user_name']?.toString() ?? row['username']?.toString() ?? row['user_id']?.toString() ?? 'system',
      time: time,
      detail: row['detail']?.toString() ?? row['description']?.toString() ?? row['metadata']?.toString() ?? '—',
    );
  }

  static String _formatDateTime(String dt) {
    final d = DateTime.tryParse(dt);
    if (d == null) return dt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}