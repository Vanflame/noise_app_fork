import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class DeviceConfigScreen extends StatefulWidget {
  final bool isAdmin;
  const DeviceConfigScreen({super.key, required this.isAdmin});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen> {
  final _espIpCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _status;
  Timer? _monitorTimer;
  String _monitorText = 'Connect to ESP32 to see live state';
  String _eventsText = 'Connect to ESP32 to see event logs';
  bool _monitorConnected = false;

  // Collapsible sections for admin-only
  bool _monitorExpanded = true;
  bool _eventsExpanded = true;

  // Local editable state
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _yellowCtrl = TextEditingController();
  final _redCtrl = TextEditingController();
  final _majMinCtrl = TextEditingController();
  final _silSecCtrl = TextEditingController();
  final _firstSecCtrl = TextEditingController();
  final _secondSecCtrl = TextEditingController();
  final _majorSecCtrl = TextEditingController();
  bool _speakerEnabled = true;
  bool _noiseLedsEnabled = true;
  bool _micEnabled = true;
  bool _serialLogging = true;
  final _dbSampCtrl = TextEditingController();
  final _dbThrCtrl = TextEditingController();
  final _dbHbCtrl = TextEditingController();
  final _dbUpCtrl = TextEditingController();
  double _volume = 30;

  final StorageService _storage = StorageService();
  bool _ipLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final savedIp = await _storage.getEspIp();
    if (savedIp != null && mounted) {
      setState(() {
        _espIpCtrl.text = savedIp;
        _ipLoaded = true;
      });
    }
    // Auto-detect ESP32 on local network
    if (mounted) {
      _autoDetectEsp();
    }
  }

  Future<void> _autoDetectEsp() async {
    setState(() => _isLoading = true);
    final candidates = <String>[];

    // 1) Try saved IP first
    final saved = _espIpCtrl.text.trim();
    if (saved.isNotEmpty) candidates.add(saved);

    // 2) Try mDNS hostnames commonly used by ESP32
    candidates.addAll(['http://esp32.local', 'http://noise-monitor.local', 'http://classroom-noise.local']);

    // 3) Try common LAN IPs (adjust subnet if needed)
    candidates.addAll([
      'http://192.168.1.1',
      'http://192.168.1.100',
      'http://192.168.1.101',
      'http://192.168.1.102',
      'http://192.168.1.103',
      'http://192.168.1.104',
      'http://192.168.1.105',
      'http://192.168.1.106',
      'http://192.168.1.107',
      'http://192.168.1.108',
      'http://192.168.1.109',
      'http://192.168.1.110',
      'http://192.168.0.100',
      'http://192.168.0.101',
      'http://192.168.0.102',
      'http://10.0.2.100',
      'http://10.0.2.101',
    ]);

    for (final url in candidates) {
      try {
        final uri = Uri.parse('$url/status');
        final res = await http.get(uri).timeout(const Duration(seconds: 1));
        if (res.statusCode == 200) {
          String detectedIp = uri.host;
          try {
            final data = json.decode(res.body) as Map<String, dynamic>;
            final staIp = (data['ip'] ?? '').toString();
            if (staIp.isNotEmpty) {
              detectedIp = staIp;
            }
          } catch (_) {}
          if (mounted) {
            setState(() {
              _espIpCtrl.text = detectedIp;
              _ipLoaded = true;
            });
            await _storage.saveEspIp(detectedIp);
            await _fetchStatus();
          }
          return;
        }
      } catch (_) {
        // continue scanning
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _espIpCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _yellowCtrl.dispose();
    _redCtrl.dispose();
    _majMinCtrl.dispose();
    _silSecCtrl.dispose();
    _firstSecCtrl.dispose();
    _secondSecCtrl.dispose();
    _majorSecCtrl.dispose();
    _dbSampCtrl.dispose();
    _dbThrCtrl.dispose();
    _dbHbCtrl.dispose();
    _dbUpCtrl.dispose();
    super.dispose();
  }

  String get _ip => _espIpCtrl.text.trim();

  bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) return val == 'true' || val == '1';
    return false;
  }

  Future<void> _fetchStatus() async {
    if (_ip.isEmpty) return;
    setState(() => _error = null);
    try {
      final res = await http.get(Uri.parse('http://$_ip/status')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        setState(() {
          _status = data;
          _monitorConnected = true;
          _ssidCtrl.text = (data['ssid'] ?? '').toString();
          _yellowCtrl.text = (data['yellow'] ?? 65).toString();
          _redCtrl.text = (data['red'] ?? 70).toString();
          _majMinCtrl.text = (data['maj_int'] ?? 3).toString();
          _silSecCtrl.text = (data['sil_sec'] ?? 15).toString();
          _firstSecCtrl.text = (data['first_sec'] ?? 5).toString();
          _secondSecCtrl.text = (data['second_sec'] ?? 30).toString();
          _majorSecCtrl.text = (data['major_sec'] ?? 60).toString();
          _speakerEnabled = _parseBool(data['speaker']);
          _noiseLedsEnabled = _parseBool(data['nleden']);
          _micEnabled = _parseBool(data['micen']);
          _serialLogging = _parseBool(data['serlog']);
          _volume = double.tryParse((data['mp3vol'] ?? 30).toString()) ?? 30;
          _dbSampCtrl.text = (data['db_samp'] ?? 100).toString();
          _dbThrCtrl.text = (data['db_thr'] ?? 1.0).toString();
          _dbHbCtrl.text = (data['db_hb'] ?? 8).toString();
          _dbUpCtrl.text = (data['db_up'] ?? 60).toString();
        });
        _showSnack('Status loaded', true);
        _startMonitorPolling();
      } else {
        setState(() => _error = 'Failed to fetch status: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Cannot reach ESP32: $e');
      _monitorConnected = false;
      _monitorTimer?.cancel();
    }
  }

  Future<void> _saveIp() async {
    if (_ip.isEmpty) return;
    await _storage.saveEspIp(_ip);
    _showSnack('IP saved', true);
  }

  void _startMonitorPolling() {
    _monitorTimer?.cancel();
    _pollMonitor();
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollMonitor());
  }

  Future<void> _pollMonitor() async {
    if (!_monitorConnected) return;
    try {
      final res = await http.get(Uri.parse('http://$_ip/status')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final now = DateTime.now().toIso8601String().substring(11, 19);
        final state = [
          '[$now] === LIVE STATE ===',
          'WiFi: ${data['ssid'] ?? '?'}',
          'IP: ${data['ip'] ?? '?'}',
          'Yellow: ${data['yellow'] ?? '?'} dB',
          'Red: ${data['red'] ?? '?'} dB',
          'Current dB: ${data['current_db'] ?? '?'}',
          'LED: ${data['current_state'] ?? '?'}',
          'Speaker: ${_parseBool(data['speaker']) ? "ON" : "OFF"}',
          'Noise LEDs: ${_parseBool(data['nleden']) ? "ON" : "OFF"}',
          'Mic: ${_parseBool(data['micen']) ? "ON" : "OFF"}',
          'Serial: ${_parseBool(data['serlog']) ? "ON" : "OFF"}',
          'Volume: ${data['mp3vol'] ?? '?'}',
        ].join('\n');
        if (state != _monitorText) {
          setState(() => _monitorText = state);
        }
      }
    } catch (_) {}
    try {
      final res = await http.get(Uri.parse('http://$_ip/events')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200 && res.body != _eventsText) {
        setState(() => _eventsText = res.body.length > 500 ? res.body.substring(0, 500) : res.body);
      }
    } catch (_) {}
  }

  Future<void> _send(String path, Map<String, String> params) async {
    final uri = Uri.parse('http://$_ip/$path').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> _forgetNetwork() async {
    try {
      await _send('disconnect', {});
      _showSnack('Wi-Fi forgotten. ESP32 is now in AP mode.', true);
      setState(() {
        _ssidCtrl.text = '';
        _passCtrl.text = '';
      });
    } catch (e) {
      _showSnack('Failed to forget network: $e', false);
    }
  }

  Future<void> _saveWifi() async {
    await _send('save', {'ssid': _ssidCtrl.text.trim(), 'password': _passCtrl.text});
    _showSnack('Wi-Fi saved', true);
  }

  Future<void> _saveThresholds() async {
    await _send('setThresholds', {'yellow': _yellowCtrl.text.trim(), 'red': _redCtrl.text.trim()});
    _showSnack('Thresholds saved', true);
  }

  Future<void> _saveAlertTimers() async {
    await _send('setAlertConfig', {
      'maj_min': _majMinCtrl.text.trim(), 'sil_sec': _silSecCtrl.text.trim(),
      'first_sec': _firstSecCtrl.text.trim(), 'second_sec': _secondSecCtrl.text.trim(),
      'major_sec': _majorSecCtrl.text.trim(),
    });
    _showSnack('Alert timers saved', true);
  }

  Future<void> _saveToggles() async {
    try {
      await _send('setSpeaker', {'enabled': _speakerEnabled ? '1' : '0'});
      await _send('setNoiseLedsEnabled', {'enabled': _noiseLedsEnabled ? '1' : '0'});
      await _send('setMicEnabled', {'enabled': _micEnabled ? '1' : '0'});
      await _send('setSerialLogging', {'enabled': _serialLogging ? '1' : '0'});
      _showSnack('Toggles saved', true);
    } catch (e) {
      _showSnack('Toggle failed: $e', false);
    }
  }

  Future<void> _saveDbConfig() async {
    final thr10 = (double.tryParse(_dbThrCtrl.text.trim()) ?? 1.0) * 10;
    await _send('setDbLogConfig', {
      'samp': _dbSampCtrl.text.trim(),
      'thr10': thr10.round().toString(),
      'hb': (int.tryParse(_dbHbCtrl.text.trim()) ?? 8).toString(),
      'up': (int.tryParse(_dbUpCtrl.text.trim()) ?? 60).toString(),
    });
    _showSnack('DB log config saved', true);
  }

  Future<void> _saveVolume() async {
    await _send('setMp3Volume', {'vol': _volume.round().toString()});
    _showSnack('Volume saved', true);
  }

  Future<void> _playMp3(String track) async {
    await _send(track, {});
    _showSnack('Playing $track', false);
  }

  Future<void> _stopMp3() async {
    await _send('stopMp3', {});
    _showSnack('Stopped', false);
  }

  Future<void> _testLed(String color) async {
    await _send('testNoiseLed', {'c': color});
    _showSnack('Testing $color LED', false);
  }

  void _showSnack(String msg, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isSuccess ? "✓" : "•"} $msg'),
        backgroundColor: isSuccess ? const Color(0xFF22c55e) : const Color(0xFFef4444),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2332),
        elevation: 0,
        title: const Text('Device Configuration', style: TextStyle(color: Color(0xFFe8edf4))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionBar(),
            if (_error != null) _buildErrorBanner(),
            if (_status != null) ...[
              const SizedBox(height: 16),
              _section('Wi-Fi / AP Settings', [
                _row(['SSID', _ssidCtrl], _saveWifi),
                _row(['Password', _passCtrl], _saveWifi),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _forgetNetwork,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444), foregroundColor: const Color(0xFF0f1419)),
                    child: const Text('Forget Network (Disconnect Wi-Fi)'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _section('Thresholds', [
                _row(['Yellow Threshold', _yellowCtrl], _saveThresholds),
                _row(['Red Threshold', _redCtrl], null),
              ]),
              const SizedBox(height: 12),
              _section('Alert Timers', [
                _row(['Major Repeat (min)', _majMinCtrl], _saveAlertTimers),
                _row(['Silence Reset (sec)', _silSecCtrl], null),
                _row(['First Warning (sec)', _firstSecCtrl], null),
                _row(['Second Warning (sec)', _secondSecCtrl], null),
                _row(['Major Warning (sec)', _majorSecCtrl], null),
              ]),
              const SizedBox(height: 12),
              _section('Toggles', [
                _toggleRow('Speaker', _speakerEnabled, (v) => setState(() => _speakerEnabled = v)),
                _toggleRow('Noise LEDs', _noiseLedsEnabled, (v) => setState(() => _noiseLedsEnabled = v)),
                _toggleRow('Microphone', _micEnabled, (v) => setState(() => _micEnabled = v)),
                _toggleRow('Serial Logging', _serialLogging, (v) => setState(() => _serialLogging = v)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveToggles,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38bdf8), foregroundColor: const Color(0xFF0f1419)),
                    child: const Text('Save Toggles'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _section('Volume', [
                Row(
                  children: [
                    const Text('MP3 Volume', style: TextStyle(color: Color(0xFFe8edf4), fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        min: 0,
                        max: 30,
                        divisions: 30,
                        activeColor: const Color(0xFF38bdf8),
                        inactiveColor: const Color(0xFF2d3a4f),
                        label: _volume.round().toString(),
                        onChanged: (v) => setState(() => _volume = v),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('${_volume.round()}', style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13)),
                    ),
                    IconButton(
                      onPressed: _saveVolume,
                      icon: const Icon(Icons.save, color: Color(0xFF38bdf8), size: 18),
                      tooltip: 'Save Volume',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(flex: 1, child: ElevatedButton(onPressed: () => _playMp3('playTest001'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a2332), foregroundColor: const Color(0xFFe8edf4), padding: EdgeInsets.zero), child: const Text('01'))),
                  const SizedBox(width: 6),
                  Expanded(flex: 1, child: ElevatedButton(onPressed: () => _playMp3('playTest002'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a2332), foregroundColor: const Color(0xFFe8edf4), padding: EdgeInsets.zero), child: const Text('02'))),
                  const SizedBox(width: 6),
                  Expanded(flex: 1, child: ElevatedButton(onPressed: () => _playMp3('playTest003'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a2332), foregroundColor: const Color(0xFFe8edf4), padding: EdgeInsets.zero), child: const Text('03'))),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _stopMp3, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444), foregroundColor: const Color(0xFF0f1419)), child: const Text('Stop MP3'))),
              ]),
              const SizedBox(height: 12),
              _section('DB Log Config', [
                _row(['Sample Interval (ms)', _dbSampCtrl], _saveDbConfig),
                _row(['dB Change Threshold', _dbThrCtrl], null),
                _row(['Heartbeat (ms)', _dbHbCtrl], null),
                _row(['Upload Interval (min)', _dbUpCtrl], _saveDbConfig),
              ]),
              const SizedBox(height: 12),
              _section('LED Test', [
                Row(children: [
                  Expanded(flex: 1, child: ElevatedButton(onPressed: () => _testLed('green'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22c55e), foregroundColor: const Color(0xFF0f1419), padding: EdgeInsets.zero), child: const Text('Green'))),
                  const SizedBox(width: 6),
                  Expanded(flex: 1, child: ElevatedButton(onPressed: () => _testLed('yellow'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFeab308), foregroundColor: const Color(0xFF0f1419), padding: EdgeInsets.zero), child: const Text('Yellow'))),
                  const SizedBox(width: 6),
                  Expanded(flex: 1, child: ElevatedButton(onPressed: () => _testLed('red'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444), foregroundColor: const Color(0xFF0f1419), padding: EdgeInsets.zero), child: const Text('Red'))),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _testLed('off'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a2332), foregroundColor: const Color(0xFFe8edf4)), child: const Text('LED Off'))),
              ]),
              if (widget.isAdmin) ...[
                const SizedBox(height: 12),
                _collapsibleSection('Live Monitor', _monitorExpanded, () {
                  setState(() => _monitorExpanded = !_monitorExpanded);
                }, [
                  Container(
                    width: double.infinity,
                    height: 160,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060a13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2d3a4f)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _monitorText,
                        style: const TextStyle(color: Color(0xFF86efac), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _collapsibleSection('Event Log', _eventsExpanded, () {
                  setState(() => _eventsExpanded = !_eventsExpanded);
                }, [
                  Container(
                    width: double.infinity,
                    height: 160,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060a13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2d3a4f)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _eventsText,
                        style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _espIpCtrl,
              style: const TextStyle(color: Color(0xFFe8edf4)),
              decoration: InputDecoration(
                labelText: _ipLoaded ? 'ESP32 IP (saved)' : 'ESP32 IP Address',
                labelStyle: const TextStyle(color: Color(0xFF8b9cb3)),
                filled: true,
                fillColor: const Color(0xFF243044),
                border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2d3a4f))),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchStatus,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38bdf8), foregroundColor: const Color(0xFF0f1419)),
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0f1419)))
                : const Text('Connect'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _saveIp,
            icon: const Icon(Icons.save, color: Color(0xFF38bdf8), size: 18),
            tooltip: 'Save IP',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFef4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFef4444)),
        ),
        child: Text(_error!, style: const TextStyle(color: Color(0xFFef4444), fontSize: 12)),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
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
          Text(title, style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _collapsibleSection(String title, bool expanded, VoidCallback onToggle, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF8b9cb3)),
                ],
              ),
            ),
          ),
          if (expanded) Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(List<dynamic> parts, VoidCallback? onSave) {
    final label = parts[0] as String;
    final ctrl = parts[1] as TextEditingController;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: Color(0xFFe8edf4)),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Color(0xFF8b9cb3)),
                filled: true,
                fillColor: const Color(0xFF243044),
                border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2d3a4f))),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          if (onSave != null) ...[
            const SizedBox(width: 8),
            IconButton(onPressed: onSave, icon: const Icon(Icons.save, color: Color(0xFF38bdf8), size: 18), tooltip: 'Save'),
          ],
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF38bdf8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}