import 'dart:math';
import 'package:flutter/material.dart';
import '../models/noise_event.dart';
import '../models/audit_log.dart';
import '../services/supabase_service.dart';
import '../config/app_config.dart';

class DashboardStats {
  final int incidentsToday;
  final int redAlertsWeek;
  final String mostNoisyRoom;
  final int mostNoisyCount;
  final String peakTime;
  final List<ChartItem> chartByRoom;
  final List<DateTimeChartItem> chartByDateTime;

  DashboardStats({
    required this.incidentsToday,
    required this.redAlertsWeek,
    required this.mostNoisyRoom,
    required this.mostNoisyCount,
    required this.peakTime,
    required this.chartByRoom,
    required this.chartByDateTime,
  });
}

class ChartItem {
  final String room;
  final int count;
  ChartItem({required this.room, required this.count});
}

class DateTimeChartItem {
  final int ts;
  final String date;
  final String label;
  int count;
  DateTimeChartItem({
    required this.ts,
    required this.date,
    required this.label,
    required this.count,
  });
}

class HeatmapCell {
  final int day;
  final String dayLabel;
  final int hour;
  final int count;
  HeatmapCell({
    required this.day,
    required this.dayLabel,
    required this.hour,
    required this.count,
  });
}

class PaginationResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final int startIndex;
  final int endIndex;

  PaginationResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.startIndex,
    required this.endIndex,
  });
}

class DataProvider extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  List<NoiseEvent> _events = [];
  List<Map<String, dynamic>> _classrooms = [];
  List<AuditLog> _auditLogs = [];
  Map<String, dynamic> _settings = Map<String, dynamic>.from(AppConfig.defaultSettings);
  List<Map<String, dynamic>> _schedules = [];
  String _currentTeacherId = '';
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;
  int _supabaseErrorCount = 0;
  int _apiFailCount = 0;

  List<NoiseEvent> get events => _events;
  List<Map<String, dynamic>> get classrooms => _classrooms;
  List<AuditLog> get auditLogs => _auditLogs;
  Map<String, dynamic> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get supabaseErrorCount => _supabaseErrorCount;
  int get apiFailCount => _apiFailCount;

  List<String> get roomList {
    final fromLogs = _events.map((e) => e.room).where((r) => r.isNotEmpty && r != '—').toSet();
    final fromDb = _classrooms
        .map((c) => c['name']?.toString() ?? c['room_name']?.toString() ?? c['room']?.toString() ?? '')
        .where((r) => r.isNotEmpty)
        .toSet();
    return {...fromLogs, ...fromDb}.toList()..sort();
  }

  Future<void> loadAllData({bool force = false}) async {
    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inSeconds < 5) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _supabase.fetchNoiseEvents();
      _classrooms = await _supabase.fetchClassrooms();
      _lastFetch = DateTime.now();
      _supabaseErrorCount = 0;
    } catch (e) {
      _error = e.toString();
      _supabaseErrorCount++;
      _apiFailCount++;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshEvents() async {
    try {
      _events = await _supabase.fetchNoiseEvents();
      _lastFetch = DateTime.now();
      _supabaseErrorCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _supabaseErrorCount++;
      _apiFailCount++;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    try {
      final dbSettings = await _supabase.fetchSystemSettings();
      if (dbSettings != null) {
        _settings = {
          'thresholdGreen': dbSettings['threshold_green'] ?? AppConfig.defaultSettings['thresholdGreen'],
          'thresholdYellow': dbSettings['threshold_yellow'] ?? AppConfig.defaultSettings['thresholdYellow'],
          'thresholdRed': dbSettings['threshold_red'] ?? AppConfig.defaultSettings['thresholdRed'],
          'buzzerEnabled': dbSettings['buzzer_enabled'] ?? AppConfig.defaultSettings['buzzerEnabled'],
          'maxBeeps': dbSettings['max_beeps'] ?? AppConfig.defaultSettings['maxBeeps'],
          'buzzerCooldown': dbSettings['buzzer_cooldown'] ?? AppConfig.defaultSettings['buzzerCooldown'],
          'audioLengthMin': dbSettings['audio_length_min'] ?? AppConfig.defaultSettings['audioLengthMin'],
          'audioLengthMax': dbSettings['audio_length_max'] ?? AppConfig.defaultSettings['audioLengthMax'],
          'alertCooldown': dbSettings['alert_cooldown'] ?? AppConfig.defaultSettings['alertCooldown'],
          'retentionDays': dbSettings['retention_days'] ?? AppConfig.defaultSettings['retentionDays'],
          'teacherAccessHours': dbSettings['teacher_access_hours'] ?? AppConfig.defaultSettings['teacherAccessHours'],
        };
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> saveSettings(Map<String, dynamic> newSettings) async {
    await _supabase.saveSystemSettings(newSettings);
    _settings = Map<String, dynamic>.from(newSettings);
    notifyListeners();
  }

  Future<void> loadAuditLogs() async {
    try {
      _auditLogs = await _supabase.fetchAuditLogs();
      notifyListeners();
    } catch (_) {}
  }

  // ─── Filter helpers ───
  List<NoiseEvent> filterEvents({
    String? room,
    String? severity,
    String? from,
    String? to,
    String? subject,
  }) {
    var filtered = List<NoiseEvent>.from(_events);
    if (from != null && from.isNotEmpty) {
      filtered = filtered.where((e) => e.date.compareTo(from) >= 0).toList();
    }
    if (to != null && to.isNotEmpty) {
      filtered = filtered.where((e) => e.date.compareTo(to) <= 0).toList();
    }
    if (room != null && room.isNotEmpty) {
      filtered = filtered.where((e) => e.room == room).toList();
    }
    if (severity != null && severity.isNotEmpty) {
      filtered = filtered.where((e) => e.status == severity).toList();
    }
    if (subject != null && subject.isNotEmpty) {
      final q = subject.toLowerCase();
      filtered = filtered.where((e) =>
          e.subject.toLowerCase().contains(q) ||
          e.teacher.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  List<NoiseEvent> filterForRole(String role, String? assignedDeviceId) {
    if (role == 'teacher') {
      final schedules = _schedules;
      if (schedules.isEmpty && assignedDeviceId != null) {
        return _events.where((e) => e.deviceId == assignedDeviceId).toList();
      }
      if (schedules.isNotEmpty) {
        return _events.where((e) => _matchesTeacherSchedule(e, schedules)).toList();
      }
    }
    return _events;
  }

  bool _matchesTeacherSchedule(NoiseEvent event, List<Map<String, dynamic>> schedules) {
    final eventDateTime = DateTime.tryParse(event.datetime);
    if (eventDateTime == null) return false;

    final eventDay = _dayName(eventDateTime.weekday);
    final eventTime = TimeOfDay(hour: eventDateTime.hour, minute: eventDateTime.minute);

    for (final schedule in schedules) {
      final scheduleDay = schedule['day']?.toString() ?? '';

      if (eventDay != scheduleDay) continue;

      final startParts = (schedule['start_time']?.toString() ?? '00:00').split(':');
      final endParts = (schedule['end_time']?.toString() ?? '23:59').split(':');
      final startTime = TimeOfDay(
        hour: int.tryParse(startParts[0]) ?? 0,
        minute: int.tryParse(startParts[1]) ?? 0,
      );
      final endTime = TimeOfDay(
        hour: int.tryParse(endParts[0]) ?? 23,
        minute: int.tryParse(endParts[1]) ?? 59,
      );

      if (_isTimeInRange(eventTime, startTime, endTime)) {
        return true;
      }
    }
    return false;
  }

  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final totalMinutes = (TimeOfDay t) => t.hour * 60 + t.minute;
    final t = totalMinutes(time);
    final s = totalMinutes(start);
    final e = totalMinutes(end);
    return t >= s && t <= e;
  }

  String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  PaginationResult<NoiseEvent> paginate(List<NoiseEvent> items, int page) {
    final total = items.length;
    final totalPages = max(1, (total / AppConfig.logsPageSize).ceil());
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * AppConfig.logsPageSize;
    final end = min(start + AppConfig.logsPageSize, total);

    return PaginationResult(
      items: items.sublist(start, end),
      page: safePage,
      pageSize: AppConfig.logsPageSize,
      total: total,
      totalPages: totalPages,
      startIndex: total == 0 ? 0 : start + 1,
      endIndex: end,
    );
  }

  // ─── Dashboard stats ───
  DashboardStats getDashboardStats(String role, String? assignedDeviceId) {
    final filtered = filterForRole(role, assignedDeviceId);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    final todayLogs = filtered.where((e) => e.date == today).toList();
    final weekRed = filtered.where((e) =>
        e.status == 'red' && DateTime.tryParse(e.datetime) != null && DateTime.parse(e.datetime).isAfter(weekAgo));

    // Room counts
    final roomCounts = <String, int>{};
    for (final e in filtered.where((e) => e.status != 'green')) {
      roomCounts[e.room] = (roomCounts[e.room] ?? 0) + 1;
    }
    String mostNoisyRoom = '—';
    int mostNoisyCount = 0;
    for (final entry in roomCounts.entries) {
      if (entry.value > mostNoisyCount) {
        mostNoisyCount = entry.value;
        mostNoisyRoom = entry.key;
      }
    }

    // Peak hour
    final hourCounts = <int, int>{};
    for (final e in filtered) {
      final d = DateTime.tryParse(e.datetime);
      if (d != null) {
        hourCounts[d.hour] = (hourCounts[d.hour] ?? 0) + 1;
      }
    }
    int peakHour = 10;
    int peakCount = 0;
    for (final entry in hourCounts.entries) {
      if (entry.value > peakCount) {
        peakCount = entry.value;
        peakHour = entry.key;
      }
    }

    return DashboardStats(
      incidentsToday: todayLogs.where((e) => e.status != 'green').length,
      redAlertsWeek: weekRed.length,
      mostNoisyRoom: mostNoisyRoom,
      mostNoisyCount: mostNoisyCount,
      peakTime: '${peakHour.toString().padLeft(2, '0')}:00–${(peakHour + 1).toString().padLeft(2, '0')}:00',
      chartByRoom: _aggregateByRoom(filtered),
      chartByDateTime: _aggregateByDateTime(filtered),
    );
  }

  List<ChartItem> _aggregateByRoom(List<NoiseEvent> logs) {
    final counts = <String, int>{};
    for (final e in logs.where((e) => e.status != 'green')) {
      final key = e.room.isNotEmpty && e.room != '—' ? e.room : e.deviceId.isNotEmpty ? e.deviceId : 'Unknown';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => ChartItem(room: e.key, count: e.value)).toList();
  }

  List<DateTimeChartItem> _aggregateByDateTime(List<NoiseEvent> logs, {int dayWindow = 14}) {
    final cutoff = DateTime.now().subtract(Duration(days: dayWindow));
    final buckets = <int, DateTimeChartItem>{};

    for (final e in logs.where((e) => e.status != 'green')) {
      final d = DateTime.tryParse(e.datetime);
      if (d == null || d.isBefore(cutoff)) continue;
      final bucket = DateTime(d.year, d.month, d.day, d.hour);
      final key = bucket.millisecondsSinceEpoch;
      if (!buckets.containsKey(key)) {
        buckets[key] = DateTimeChartItem(
          ts: key,
          date: bucket.toIso8601String().substring(0, 10),
          label: '${_monthAbbr(bucket.month)} ${bucket.day}, ${bucket.hour}:00',
          count: 0,
        );
      }
      buckets[key]!.count += 1;
    }

    var series = buckets.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    if (series.isEmpty) {
      for (int i = dayWindow - 1; i >= 0; i--) {
        final d = DateTime.now().subtract(Duration(days: i));
        series.add(DateTimeChartItem(
          ts: d.millisecondsSinceEpoch,
          date: d.toIso8601String().substring(0, 10),
          label: '${_monthAbbr(d.month)} ${d.day}, 12:00',
          count: 0,
        ));
      }
    }
    return series.sublist(0, min(series.length, 36));
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ─── Audio clips helper ───
  List<NoiseEvent> getRedAudioClips(String role, String? assignedDeviceId) {
    var clips = _events.where((e) =>
        e.status == 'red' &&
        e.audioRecorded &&
        e.audioUrl != null &&
        (e.warningColor.toUpperCase() == 'RED'));

    if (role == 'teacher' && assignedDeviceId != null) {
      clips = clips.where((e) => e.deviceId == assignedDeviceId);
    }
    return clips.toList();
  }

  // ─── Heatmap ───
  List<HeatmapCell> buildHeatmap({List<NoiseEvent>? events}) {
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const hours = [7, 8, 9, 10, 11, 12, 13, 14];
    final grid = <String, int>{};

    final source = events ?? _events;
    for (final e in source.where((e) => e.status == 'red')) {
      final d = DateTime.tryParse(e.datetime);
      if (d != null) {
        final key = '${d.weekday}-${d.hour}';
        grid[key] = (grid[key] ?? 0) + 1;
      }
    }

    final cells = <HeatmapCell>[];
    for (int d = 1; d <= 5; d++) {
      for (final h in hours) {
        cells.add(HeatmapCell(
          day: d,
          dayLabel: dayLabels[d],
          hour: h,
          count: grid['$d-$h'] ?? 0,
        ));
      }
    }
    return cells;
  }

  // ─── Schedules ───
  Future<void> loadSchedules(String teacherId) async {
    try {
      _currentTeacherId = teacherId;
      _schedules = await _supabase.fetchTeacherSchedules(teacherId);
      notifyListeners();
    } catch (_) {}
  }

  List<Map<String, dynamic>> getTeacherSchedules(String teacherId) {
    return _schedules.where((s) => s['teacher_id'] == teacherId).toList();
  }

  Future<void> addSchedule(Map<String, dynamic> schedule) async {
    try {
      await _supabase.insertRecord('teacher_schedules', schedule);
      if (_currentTeacherId.isNotEmpty) await loadSchedules(_currentTeacherId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateSchedule(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.updateRecord('teacher_schedules', 'id=eq.$id', updates);
      if (_currentTeacherId.isNotEmpty) await loadSchedules(_currentTeacherId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _supabase.deleteRecord('teacher_schedules', 'id=eq.$id');
      if (_currentTeacherId.isNotEmpty) await loadSchedules(_currentTeacherId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Teacher─weekly events ───
  Map<String, dynamic> getTeacherWeeklyEvents({int days = 7}) {
    final end = DateTime.now();
    final start = DateTime.now().subtract(Duration(days: days - 1));

    final inWindow = _events.where((e) {
      final d = DateTime.tryParse(e.datetime);
      return d != null && !d.isBefore(start) && !d.isAfter(end) && e.status != 'green';
    }).toList();

    final teacherMap = <String, List<NoiseEvent>>{};
    for (final e in inWindow) {
      final name = (e.teacher.isNotEmpty && e.teacher != '—') ? e.teacher : 'Unknown';
      teacherMap.putIfAbsent(name, () => []);
      teacherMap[name]!.add(e);
    }

    final dates = <String>[];
    for (int i = 0; i < days; i++) {
      final d = DateTime.now().subtract(Duration(days: days - 1 - i));
      dates.add(d.toIso8601String().substring(0, 10));
    }

    return {
      'dates': dates,
      'teachers': teacherMap.entries.map((e) => {'teacher': e.key, 'events': e.value}).toList(),
    };
  }
}