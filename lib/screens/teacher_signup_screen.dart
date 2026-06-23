import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class TeacherSignupScreen extends StatefulWidget {
  const TeacherSignupScreen({super.key});

  @override
  State<TeacherSignupScreen> createState() => _TeacherSignupScreenState();
}

class _TeacherSignupScreenState extends State<TeacherSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _roomController = TextEditingController();
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _error = null; _success = false; });

    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final result = await auth.signupTeacher(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      room: _roomController.text.trim(),
    );

    if (!mounted) return;

    if (result) {
      setState(() => _success = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() => _error = auth.error ?? 'Signup failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0f1419), Color(0xFF0f1419)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2332),
                border: Border.all(color: const Color(0xFF2d3a4f)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 48, offset: const Offset(0, 24),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(const Color(0xFF22c55e)), const SizedBox(width: 8),
                        _dot(const Color(0xFFeab308)), const SizedBox(width: 8),
                        _dot(const Color(0xFFef4444)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Create Teacher Account',
                      style: TextStyle(color: Color(0xFFe8edf4), fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Register for read-only access to your assigned classroom',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    const SizedBox(height: 24),
                    _buildField('Full name', _nameController),
                    const SizedBox(height: 12),
                    _buildField('Email', _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildField('Password', _passwordController, obscure: true),
                    const SizedBox(height: 12),
                    _buildField('Confirm password', _confirmController, obscure: true),
                    const SizedBox(height: 12),
                    _buildField('Assigned classroom', _roomController, hint: 'e.g. ICT Lab 2'),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Color(0xFFef4444), fontSize: 12)),
                    ],
                    if (_success) ...[
                      const SizedBox(height: 8),
                      const Text('Account created! Redirecting to login…',
                        style: TextStyle(color: Color(0xFF22c55e), fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38bdf8),
                          foregroundColor: const Color(0xFF0f1419),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create account', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Already registered? Sign in',
                        style: TextStyle(color: Color(0xFF38bdf8), fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF243044),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Access policy\nTeachers get limited, read-only access to short RED-level audio clips from their own class only. Access is time-bound (24–48 hours) and logged.',
                        style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
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

  Widget _dot(Color c) => Container(
    width: 14, height: 14,
    decoration: BoxDecoration(
      color: c, borderRadius: BorderRadius.circular(7),
      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 12)],
    ),
  );

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, bool obscure = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFe8edf4)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF5a6b82), fontSize: 12),
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
      ),
      validator: (v) => v == null || v.isEmpty ? '$label is required' : null,
    );
  }
}