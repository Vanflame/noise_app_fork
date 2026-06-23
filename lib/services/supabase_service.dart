import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/noise_event.dart';
import '../models/audit_log.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  String get _url => AppConfig.supabaseUrl;
  String get _anonKey => AppConfig.supabaseAnonKey;

  Map<String, String> _headers() => {
    'apikey': _anonKey,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Prefer': 'return=representation',
  };

  Map<String, String> _authHeaders(String token) => {
    'apikey': _anonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Prefer': 'return=representation',
  };

  String _urlFor(String table, {String? query}) {
    final q = query != null ? (query.startsWith('?') ? query : '?$query') : '';
    return '$_url/rest/v1/$table$q';
  }

  Future<dynamic> _get(String table, {String? query, Map<String, String>? headers}) async {
    final h = headers ?? _headers();
    final res = await http.get(Uri.parse(_urlFor(table, query: query)), headers: h);
    if (res.statusCode >= 400) throw Exception('$table: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body);
  }

  Future<dynamic> _post(String table, dynamic body, {Map<String, String>? headers}) async {
    final h = headers ?? _headers();
    final res = await http.post(Uri.parse(_urlFor(table)), headers: h, body: jsonEncode(body));
    if (res.statusCode >= 400) throw Exception('$table: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body);
  }

  Future<dynamic> _patch(String table, String query, dynamic body, {Map<String, String>? headers}) async {
    final h = headers ?? _headers();
    final res = await http.patch(Uri.parse(_urlFor(table, query: query)), headers: h, body: jsonEncode(body));
    if (res.statusCode >= 400) throw Exception('$table: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body);
  }

  Future<dynamic> _delete(String table, String query, {Map<String, String>? headers}) async {
    final h = headers ?? _headers();
    final res = await http.delete(Uri.parse(_urlFor(table, query: query)), headers: h);
    if (res.statusCode >= 400) throw Exception('$table: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body);
  }

  // ─── Auth (GoTrue) ───
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_url/auth/v1/token?grant_type=password'),
      headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(data['msg'] ?? data['error_description'] ?? data['error'] ?? 'Auth failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_url/auth/v1/signup'),
      headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(data['msg'] ?? data['error_description'] ?? data['error'] ?? 'Auth failed');
    }
    return data;
  }

  Future<void> signOut(String token) async {
    final res = await http.post(
      Uri.parse('$_url/auth/v1/logout'),
      headers: {'apikey': _anonKey, 'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (res.statusCode >= 400) {
      throw Exception('Sign out: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getUser(String token) async {
    final res = await http.get(
      Uri.parse('$_url/auth/v1/user'),
      headers: {'apikey': _anonKey, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 400) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  }

  // ─── Profiles ───
  Future<Map<String, dynamic>?> getProfile(String id) async {
    try {
      final list = await _get('profiles', query: 'id=eq.$id&select=*') as List;
      return list.isNotEmpty ? list[0] as Map<String, dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertProfile(String id, Map<String, dynamic> updates) async {
    final existing = await getProfile(id);
    updates['updated_at'] = DateTime.now().toIso8601String();
    if (existing != null) {
      await _patch('profiles', 'id=eq.$id', updates);
    } else {
      updates['id'] = id;
      updates['created_at'] = DateTime.now().toIso8601String();
      await _post('profiles', updates);
    }
  }

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    final result = await _get('profiles', query: 'select=*&order=full_name.asc');
    return (result as List).cast<Map<String, dynamic>>();
  }

  // ─── Noise Events ───
  Future<List<NoiseEvent>> fetchNoiseEvents({
    int? limit,
    String? room,
    String? deviceId,
    String? severity,
    bool? audioOnly,
    String? from,
    String? to,
  }) async {
    final params = <String>['select=*', 'order=created_at.desc'];
    if (limit != null) params.add('limit=$limit');
    if (room != null && room.isNotEmpty) params.add('room=eq.$room');
    if (deviceId != null && deviceId.isNotEmpty) params.add('device_id=eq.$deviceId');
    if (severity != null && severity.isNotEmpty) params.add('warning_color=eq.${severity.toUpperCase()}');
    if (audioOnly == true) {
      params.add('audio_recorded=eq.true');
      params.add('audio_url=not.is.null');
      params.add('warning_color=eq.RED');
    }
    if (from != null && from.isNotEmpty) params.add('created_at=gte.${from}T00:00:00');
    if (to != null && to.isNotEmpty) params.add('created_at=lte.${to}T23:59:59');

    final query = params.join('&');
    final result = await _get('noise_events', query: query);
    return (result as List).map((row) => NoiseEvent.fromJson(row as Map<String, dynamic>)).toList();
  }

  // ─── Classrooms ───
  Future<List<Map<String, dynamic>>> fetchClassrooms() async {
    final result = await _get('classrooms', query: 'select=*&order=name.asc');
    return (result as List).cast<Map<String, dynamic>>();
  }

  // ─── Audit Logs ───
  Future<List<AuditLog>> fetchAuditLogs({int limit = 50}) async {
    final result = await _get('audit_logs', query: 'select=*&order=created_at.desc&limit=$limit');
    return (result as List).map((row) => AuditLog.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> insertAuditLog(Map<String, dynamic> record) async {
    await _post('audit_logs', record);
  }

  // ─── System Settings ───
  Future<Map<String, dynamic>?> fetchSystemSettings() async {
    try {
      final list = await _get('system_settings', query: 'select=*&limit=1') as List;
      return list.isNotEmpty ? list[0] as Map<String, dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSystemSettings(Map<String, dynamic> settings) async {
    final existing = await fetchSystemSettings();
    settings['updated_at'] = DateTime.now().toIso8601String();
    if (existing != null && existing['id'] != null) {
      await _patch('system_settings', 'id=eq.${existing['id']}', settings);
    } else {
      settings['created_at'] = DateTime.now().toIso8601String();
      await _post('system_settings', settings);
    }
  }

  // ─── Teacher Classrooms ───
  Future<List<Map<String, dynamic>>> fetchTeacherClassrooms(String teacherId) async {
    final query = 'select=classrooms!inner(name,id)&teacher_id=eq.$teacherId';
    final result = await _get('teacher_classrooms', query: query);
    return (result as List).map((r) => (r as Map<String, dynamic>)['classrooms'] as Map<String, dynamic>).toList();
  }

  // ─── Classroom helpers ───
  Future<Map<String, dynamic>> createClassroom(String name) async {
    final result = await _post('classrooms', {'name': name});
    if (result is List && result.isNotEmpty) {
      return result[0] as Map<String, dynamic>;
    }
    return result as Map<String, dynamic>;
  }

  Future<void> linkTeacherClassroom(String teacherId, String classroomId) async {
    await _post('teacher_classrooms', {
      'teacher_id': teacherId,
      'classroom_id': classroomId,
    });
  }

  // Public wrappers for schedule CRUD
  Future<void> insertRecord(String table, Map<String, dynamic> data) async {
    await _post(table, data);
  }

  Future<void> updateRecord(String table, String query, Map<String, dynamic> data) async {
    await _patch(table, query, data);
  }

  Future<void> deleteRecord(String table, String query) async {
    await _delete(table, query);
  }

  // ─── Teacher Schedules ───
  Future<List<Map<String, dynamic>>> fetchTeacherSchedules(String teacherId) async {
    final result = await _get('teacher_schedules', query: 'teacher_id=eq.$teacherId&order=day.asc,start_time.asc');
    return (result as List).cast<Map<String, dynamic>>();
  }
}