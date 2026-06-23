import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/audit_log.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();

    if (!auth.isAdmin) {
      return const Center(
        child: Text('Audit trail is visible to administrators only.',
          style: TextStyle(color: Color(0xFF8b9cb3))),
      );
    }

    final logs = data.auditLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Policy banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF38bdf8).withValues(alpha: 0.08),
              border: Border.all(color: const Color(0xFF38bdf8).withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('audit_logs table',
                  style: TextStyle(color: Color(0xFF38bdf8), fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Threshold changes · Buzzer configuration · Audio access',
                  style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No rows in audit_logs yet.',
                style: TextStyle(color: Color(0xFF8b9cb3)))),
            )
          else
            ...logs.map((log) => _auditEntry(log)),
        ],
      ),
    );
  }

  Widget _auditEntry(AuditLog log) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2d3a4f))),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF8b9cb3)),
          children: [
            TextSpan(text: log.time, style: const TextStyle(color: Color(0xFF8b9cb3))),
            const TextSpan(text: ' — '),
            TextSpan(text: log.action,
              style: const TextStyle(color: Color(0xFFe8edf4), fontWeight: FontWeight.w600)),
            TextSpan(text: ' by ${log.user}: ${log.detail}'),
          ],
        ),
      ),
    );
  }
}