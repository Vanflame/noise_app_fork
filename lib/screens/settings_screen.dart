import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _greenCtrl;
  late TextEditingController _yellowCtrl;
  late TextEditingController _redCtrl;
  late TextEditingController _maxBeepsCtrl;
  late TextEditingController _cooldownCtrl;
  late TextEditingController _alertCooldownCtrl;
  late TextEditingController _retentionCtrl;
  late TextEditingController _teacherAccessCtrl;
  bool _buzzerEnabled = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<DataProvider>();
    final s = data.settings;
    _greenCtrl = TextEditingController(text: '${s['thresholdGreen'] ?? 60}');
    _yellowCtrl = TextEditingController(text: '${s['thresholdYellow'] ?? 74}');
    _redCtrl = TextEditingController(text: '${s['thresholdRed'] ?? 75}');
    _maxBeepsCtrl = TextEditingController(text: '${s['maxBeeps'] ?? 3}');
    _cooldownCtrl = TextEditingController(text: '${s['buzzerCooldown'] ?? 10}');
    _alertCooldownCtrl = TextEditingController(text: '${s['alertCooldown'] ?? 30}');
    _retentionCtrl = TextEditingController(text: '${s['retentionDays'] ?? 14}');
    _teacherAccessCtrl = TextEditingController(text: '${s['teacherAccessHours'] ?? 48}');
    _buzzerEnabled = s['buzzerEnabled'] == true;
  }

  @override
  void dispose() {
    _greenCtrl.dispose();
    _yellowCtrl.dispose();
    _redCtrl.dispose();
    _maxBeepsCtrl.dispose();
    _cooldownCtrl.dispose();
    _alertCooldownCtrl.dispose();
    _retentionCtrl.dispose();
    _teacherAccessCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final data = context.read<DataProvider>();
    final newSettings = {
      'threshold_green': int.tryParse(_greenCtrl.text) ?? 60,
      'threshold_yellow': int.tryParse(_yellowCtrl.text) ?? 74,
      'threshold_red': int.tryParse(_redCtrl.text) ?? 75,
      'buzzer_enabled': _buzzerEnabled,
      'max_beeps': int.tryParse(_maxBeepsCtrl.text) ?? 3,
      'buzzer_cooldown': int.tryParse(_cooldownCtrl.text) ?? 10,
      'audio_length_min': 3,
      'audio_length_max': 5,
      'alert_cooldown': int.tryParse(_alertCooldownCtrl.text) ?? 30,
      'retention_days': int.tryParse(_retentionCtrl.text) ?? 14,
      'teacher_access_hours': int.tryParse(_teacherAccessCtrl.text) ?? 48,
    };
    await data.saveSettings(newSettings);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return const Center(
        child: Text('System settings are restricted to administrators.',
          style: TextStyle(color: Color(0xFF8b9cb3))),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroup('Noise thresholds (dB)', [
            _row('Green (below)', _greenCtrl, 40, 90),
            _row('Yellow (up to)', _yellowCtrl, 50, 95),
            _row('Red (from)', _redCtrl, 55, 100),
          ]),
          const SizedBox(height: 12),
          _buildGroup('Buzzer behavior', [
            SwitchListTile(
              title: const Text('Enable buzzer',
                style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14)),
              value: _buzzerEnabled,
              activeColor: const Color(0xFF22c55e),
              onChanged: (v) => setState(() => _buzzerEnabled = v),
            ),
            _row('Max beeps per event', _maxBeepsCtrl, 1, 5),
            _row('Cooldown (seconds)', _cooldownCtrl, 5, 120),
          ]),
          const SizedBox(height: 12),
          _buildGroup('Audio & alerts', [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Recording length: 3–5 sec',
                style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14)),
            ),
            _row('Alert cooldown (sec)', _alertCooldownCtrl, 10, 300),
            _row('Retention (days)', _retentionCtrl, 7, 14),
            _row('Teacher access (hours)', _teacherAccessCtrl, 24, 48),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38bdf8),
                foregroundColor: const Color(0xFF0f1419),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save configuration', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ),
          if (_saved) ...[
            const SizedBox(height: 8),
            const Text('Settings saved to database.',
              style: TextStyle(color: Color(0xFF22c55e), fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(color: Color(0xFF38bdf8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, TextEditingController ctrl, int min, int max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13)),
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF243044),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF2d3a4f)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}