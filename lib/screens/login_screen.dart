import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import 'main_shell.dart';
import 'teacher_login_screen.dart';
import 'esp_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  final StorageService _storage = StorageService();
  bool _isDetecting = false;
  String? _detectedIp;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    // Pre-flight network check
    try {
      final result = await InternetAddress.lookup('dprqmezzvncftaoksauz.supabase.co');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        setState(() => _error = 'Network error: Cannot resolve Supabase server. Check your internet connection.');
        return;
      }
    } on SocketException catch (e) {
      setState(() => _error = 'Network error: ${e.message}. Check your internet connection and DNS settings.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      setState(() {
        _error = auth.error ?? 'Invalid email or password. Please check your credentials.';
      });
      setState(() {
        _error = auth.error ?? 'Invalid email or password. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0f1419),
              Color(0xFF0f1419),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2332),
                border: Border.all(color: const Color(0xFF2d3a4f)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 48,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Traffic light dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _trafficDot(const Color(0xFF22c55e)),
                        const SizedBox(width: 8),
                        _trafficDot(const Color(0xFFeab308)),
                        const SizedBox(width: 8),
                        _trafficDot(const Color(0xFFef4444)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: Color(0xFFe8edf4),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Administrator sign in — full system access',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration('Email'),
                      style: const TextStyle(color: Color(0xFFe8edf4)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || v.isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: _inputDecoration('Password'),
                      style: const TextStyle(color: Color(0xFFe8edf4)),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFef4444), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38bdf8),
                          foregroundColor: const Color(0xFF0f1419),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0f1419)),
                              )
                            : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
                        );
                      },
                      child: const Text(
                        'Are you a teacher? Go to Teacher Portal',
                        style: TextStyle(color: Color(0xFF38bdf8), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a2332),
                        border: Border.all(color: const Color(0xFF2d3a4f)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESP32 Device', style: TextStyle(color: Color(0xFFe8edf4), fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _detectedIp ?? 'Not detected',
                                  style: TextStyle(
                                    color: _detectedIp != null ? const Color(0xFF22c55e) : const Color(0xFF8b9cb3),
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              _isDetecting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38bdf8)))
                                  : TextButton(
                                      onPressed: _detectEsp,
                                      child: const Text('Detect', style: TextStyle(color: Color(0xFF38bdf8), fontSize: 12)),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const EspSetupScreen()),
                              );
                            },
                            child: const Text('ESP32 Device Setup', style: TextStyle(color: Color(0xFF38bdf8), fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _detectEsp() async {
    setState(() {
      _isDetecting = true;
      _detectedIp = null;
    });

    final candidates = <String>[
      'http://192.168.1.100',
      'http://192.168.1.101',
      'http://192.168.1.102',
      'http://192.168.0.100',
      'http://192.168.0.101',
      'http://10.0.2.100',
      'http://esp32.local',
      'http://noise-monitor.local',
    ];

    for (final url in candidates) {
      try {
        final uri = Uri.parse('$url/status');
        final res = await http.get(uri).timeout(const Duration(seconds: 1));
        if (res.statusCode == 200) {
          final ip = uri.host;
          setState(() => _detectedIp = ip);
          await _storage.saveEspIp(ip);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ESP32 detected at $ip'),
              backgroundColor: const Color(0xFF22c55e),
            ),
          );
          return;
        }
      } catch (_) {
        // continue
      }
    }

    setState(() => _isDetecting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No ESP32 device detected on this network'),
        backgroundColor: Color(0xFFef4444),
      ),
    );
  }

  Widget _trafficDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF243044),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2d3a4f)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2d3a4f)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF38bdf8)),
      ),
    );
  }
}