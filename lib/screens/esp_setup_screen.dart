import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/storage_service.dart';

class EspSetupScreen extends StatefulWidget {
  const EspSetupScreen({super.key});

  @override
  State<EspSetupScreen> createState() => _EspSetupScreenState();
}

class _EspSetupScreenState extends State<EspSetupScreen> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _status;
  List<Map<String, dynamic>> _wifiNetworks = [];
  bool _isScanning = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _scanWifi();
  }

  Future<void> _loadSavedCredentials() async {
    final ssid = await _storage.getWifiSsid();
    final pass = await _storage.getWifiPassword();
    if (ssid != null && mounted) {
      setState(() => _ssidCtrl.text = ssid);
    }
    if (pass != null && mounted) {
      setState(() => _passCtrl.text = pass);
    }
  }

  Future<void> _scanWifi() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      // Try ESP32 AP first
      final espUrl = 'http://192.168.4.1';
      final res = await http.get(Uri.parse('$espUrl/scan')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List<dynamic> networks = json.decode(res.body);
        setState(() {
          _wifiNetworks = networks.map((n) => Map<String, dynamic>.from(n)).toList();
          _isScanning = false;
        });
        return;
      }
    } catch (e) {
      // ESP32 not reachable, use manual entry
    }

    // Fallback: show manual entry only
    setState(() {
      _wifiNetworks = [];
      _isScanning = false;
    });
  }

  Future<void> _connectToWifi() async {
    final ssid = _ssidCtrl.text.trim();
    final password = _passCtrl.text;
    if (ssid.isEmpty) {
      setState(() => _error = 'SSID is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _status = 'Connecting to ESP32...';
    });

    try {
      // Try to reach ESP32 AP (default IP)
      final espUrl = 'http://192.168.4.1';
      final statusRes = await http.get(Uri.parse('$espUrl/status')).timeout(const Duration(seconds: 3));
      if (statusRes.statusCode != 200) {
        throw Exception('Cannot reach ESP32. Make sure you are connected to the ESP32 Wi-Fi (Classroom-Noise-Setup).');
      }

      setState(() => _status = 'Saving Wi-Fi credentials...');

      // Send Wi-Fi credentials to ESP32
      // Note: ESP32's /save handler returns 303 redirect (not 200/204)
      final form = http.Request('POST', Uri.parse('$espUrl/save'));
      form.bodyFields = {'ssid': ssid, 'password': password};
      form.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      final streamed = await http.Client().send(form).timeout(const Duration(seconds: 5));
      final saveRes = await http.Response.fromStream(streamed);

      // ESP32 /save returns 303 redirect on success — accept 200, 204, or 303
      if (saveRes.statusCode == 200 || saveRes.statusCode == 204 || saveRes.statusCode == 303) {
        // Save credentials locally
        await _storage.saveWifiSsid(ssid);
        await _storage.saveWifiPassword(password);
        await _storage.setEspSetupDone(true);

        setState(() => _status = 'Wi-Fi saved! Waiting for ESP32 to connect...');

        // Poll the ESP32's /status endpoint (still reachable at AP IP 192.168.4.1
        // during the grace period) until it reports a valid STA IP.
        String? staIp;
        for (int attempt = 0; attempt < 20; attempt++) {
          await Future.delayed(const Duration(seconds: 2));
          try {
            final statusRes = await http.get(Uri.parse('$espUrl/status')).timeout(const Duration(seconds: 2));
            if (statusRes.statusCode == 200) {
              final data = json.decode(statusRes.body) as Map<String, dynamic>;
              final ip = (data['ip'] ?? '').toString();
              final connected = data['connected'] == true;
              if (ip.isNotEmpty && connected) {
                staIp = ip;
                break;
              }
            }
          } catch (_) {
            // ESP32 may be momentarily unreachable during network switch — keep trying
          }
        }

        if (staIp != null && staIp.isNotEmpty) {
          await _storage.saveEspIp(staIp);
          setState(() {
            _status = '✓ ESP32 connected to Wi-Fi!\n'
                'IP address: $staIp\n\n'
                'Next steps:\n'
                '1. Connect your phone to "$ssid"\n'
                '2. Open the app — the device config will auto-load the IP';
          });
          // Show a success dialog with the STA IP
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1a2332),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF2d3a4f)),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF22c55e), size: 28),
                    const SizedBox(width: 12),
                    const Text('Connected!',
                      style: TextStyle(color: Color(0xFFe8edf4), fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ESP32 is now connected to your Wi-Fi network.',
                      style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 13)),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF243044),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2d3a4f)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Device IP Address',
                            style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 11)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.wifi, color: Color(0xFF22c55e), size: 16),
                              const SizedBox(width: 8),
                              Text(staIp!,
                                style: const TextStyle(
                                  color: Color(0xFF38bdf8),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Network: $ssid',
                      style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done', style: TextStyle(color: Color(0xFF38bdf8), fontSize: 14)),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _status = '✓ Wi-Fi credentials saved!\n'
                'The ESP32 is connecting to your network.\n\n'
                'Next steps:\n'
                '1. Connect your phone to "$ssid"\n'
                '2. Open Device Config and tap "Connect" to detect the IP';
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(staIp != null
                  ? '✓ ESP32 connected — IP: $staIp'
                  : '✓ Wi-Fi saved — connect phone to $ssid'),
              backgroundColor: const Color(0xFF22c55e),
            ),
          );
        }
      } else {
        throw Exception('Failed to save Wi-Fi: ${saveRes.body}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Connection failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFef4444),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2332),
        elevation: 0,
        title: const Text('ESP32 Setup', style: TextStyle(color: Color(0xFFe8edf4))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2332),
                border: Border.all(color: const Color(0xFF2d3a4f)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Device Setup', style: TextStyle(color: Color(0xFFe8edf4), fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Connect your ESP32 to your Wi-Fi network.',
                    style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('1. Connect your phone to the ESP32 Wi-Fi:', style: TextStyle(color: Color(0xFFe8edf4), fontSize: 12)),
                  const Text('   SSID: Classroom-Noise-Setup', style: TextStyle(color: Color(0xFF38bdf8), fontSize: 12)),
                  const SizedBox(height: 12),
                  const Text('2. Enter your home/office Wi-Fi credentials below:',
                    style: TextStyle(color: Color(0xFFe8edf4), fontSize: 12)),
                  const SizedBox(height: 12),
                  if (_wifiNetworks.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF243044),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2d3a4f)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Available Networks', style: TextStyle(color: Color(0xFF38bdf8), fontSize: 12, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (_isScanning)
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38bdf8)))
                              else
                                IconButton(
                                  onPressed: _scanWifi,
                                  icon: const Icon(Icons.refresh, color: Color(0xFF38bdf8), size: 18),
                                  tooltip: 'Refresh',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._wifiNetworks.map((network) {
                            final ssid = network['ssid'] ?? 'Unknown';
                            final rssi = network['rssi'] ?? -50;
                            final secure = network['secure'] ?? false;
                            return InkWell(
                              onTap: () {
                                setState(() => _ssidCtrl.text = ssid);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1a2332),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      secure ? Icons.lock : Icons.lock_open,
                                      color: const Color(0xFF8b9cb3),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ssid,
                                        style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '$rssi dBm',
                                      style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _ssidCtrl,
                    style: const TextStyle(color: Color(0xFFe8edf4)),
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi SSID',
                      labelStyle: TextStyle(color: Color(0xFF8b9cb3)),
                      filled: true,
                      fillColor: Color(0xFF243044),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2d3a4f))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Color(0xFFe8edf4)),
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi Password',
                      labelStyle: TextStyle(color: Color(0xFF8b9cb3)),
                      filled: true,
                      fillColor: Color(0xFF243044),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2d3a4f))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFef4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFef4444)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFef4444), fontSize: 12)),
                    ),
                  if (_status != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22c55e).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF22c55e)),
                      ),
                      child: Text(_status!, style: const TextStyle(color: Color(0xFF22c55e), fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _connectToWifi,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38bdf8),
                        foregroundColor: const Color(0xFF0f1419),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0f1419)))
                          : const Text('Connect ESP32 to Wi-Fi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}