import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  Map<String, dynamic>? _authData;
  Map<String, dynamic>? _profile;
  String _role = '';
  String _name = '';
  String _email = '';
  String _userId = '';
  String _accessToken = '';
  DateTime? _loginAt;
  DateTime? _lastActivity;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get authData => _authData;
  Map<String, dynamic>? get profile => _profile;
  String get role => _role;
  String get name => _name;
  String get email => _email;
  String get userId => _userId;
  String get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get remainingSessionMs {
    if (_lastActivity == null) return 0;
    return (AppConfig.sessionTimeoutMs - DateTime.now().difference(_lastActivity!).inMilliseconds)
        .clamp(0, AppConfig.sessionTimeoutMs);
  }

  void touchSession() {
    _lastActivity = DateTime.now();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authData = await _supabase.signIn(email, password);
      final accessToken = authData['access_token']?.toString() ?? '';
      final user = authData['user'] as Map<String, dynamic>?;

      if (accessToken.isEmpty || user == null) {
        _error = 'Invalid email or password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _authData = authData;
      _accessToken = accessToken;
      _userId = user['id']?.toString() ?? '';
      _email = user['email']?.toString() ?? email;

      // Load profile
      final profile = await _supabase.getProfile(_userId);
      if (profile != null) {
        _profile = profile;
        _role = profile['role']?.toString() ?? 'admin';
        _name = profile['full_name']?.toString() ?? _email;
      } else {
        // Create default profile
        await _supabase.upsertProfile(_userId, {
          'role': 'admin',
          'full_name': _email,
        });
        _role = 'admin';
        _name = _email;
        _profile = {'role': 'admin', 'full_name': _name};
      }

      _loginAt = DateTime.now();
      _lastActivity = DateTime.now();

      // Log audit
      try {
        await _supabase.insertAuditLog({
          'action': 'Admin login',
          'detail': '$_email signed in',
          'actor_id': _userId,
        });
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final errStr = e.toString();
      // Provide more helpful error messages
      if (errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
        _error = 'Network error: Cannot reach Supabase. Check your internet connection and DNS settings.';
      } else if (errStr.contains('Invalid login credentials')) {
        _error = 'Invalid email or password. Please check your credentials.';
      } else if (errStr.contains('Email not confirmed')) {
        _error = 'Email not confirmed. Please check your email and confirm your account.';
      } else if (errStr.contains('Too many requests')) {
        _error = 'Too many login attempts. Please wait a few minutes and try again.';
      } else {
        _error = 'Login failed: $errStr';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (_accessToken.isNotEmpty) {
      try {
        await _supabase.insertAuditLog({
          'action': 'Admin logout',
          'detail': '$_email signed out',
          'actor_id': _userId,
        });
      } catch (_) {}
      try {
        await _supabase.signOut(_accessToken);
      } catch (_) {}
    }

    _authData = null;
    _profile = null;
    _role = '';
    _name = '';
    _email = '';
    _userId = '';
    _accessToken = '';
    _loginAt = null;
    _lastActivity = null;
    notifyListeners();
  }

  Future<bool> signupTeacher({
    required String name,
    required String email,
    required String password,
    required String room,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authData = await _supabase.signUp(email, password);
      final user = authData['user'] as Map<String, dynamic>?;
      if (user == null) {
        _error = 'Signup failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userId = user['id']?.toString() ?? '';
      await _supabase.upsertProfile(userId, {
        'role': 'teacher',
        'full_name': name,
      });

      // Create classroom if needed
      try {
        final classrooms = await _supabase.fetchClassrooms();
        final existing = classrooms.where((c) => c['name'] == room).toList();
        String classroomId;
        if (existing.isNotEmpty) {
          classroomId = existing.first['id'].toString();
        } else {
          final newClassroom = await _supabase.createClassroom(room);
          classroomId = newClassroom['id'].toString();
        }

        await _supabase.linkTeacherClassroom(userId, classroomId);
      } catch (e) {
        // Non-critical
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}