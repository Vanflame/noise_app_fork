import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';
import 'audio_screen.dart';
import 'reports_screen.dart';
import 'audit_screen.dart';
import 'schedule_screen.dart';
import 'device_config_screen.dart';
import 'esp_setup_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    final data = context.read<DataProvider>();
    await Future.wait([
      data.loadAllData(force: true),
      data.loadSettings(),
      if (auth.role == 'teacher') data.loadSchedules(auth.userId),
    ]);
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
      return const SizedBox.shrink();
    }

    final data = context.watch<DataProvider>();
    final screens = isAdmin
        ? <Widget>[
            const DashboardScreen(),
            const LogsScreen(),
            const AudioScreen(),
            const ReportsScreen(),
            const AuditScreen(),
            const ScheduleScreen(),
            const DeviceConfigScreen(isAdmin: true),
          ]
        : <Widget>[
            const DashboardScreen(),
            const LogsScreen(),
            const ReportsScreen(),
            const ScheduleScreen(),
            const DeviceConfigScreen(isAdmin: false),
          ];
    final titles = isAdmin
        ? <String>['Dashboard', 'Noise Logs', 'Audio Evidence', 'Reports', 'Audit Trail', 'My Schedule', 'Device Config']
        : <String>['Dashboard', 'Noise Logs', 'Reports', 'My Schedule', 'Device Config'];
    final keywords = isAdmin
        ? <String>[
            'At-a-glance monitoring',
            'Primary system records — noise_events',
            'RED events with audio',
            'Evaluation & decision support',
            'audit_logs table',
            'Manage your teaching schedule',
            'ESP32 hardware — thresholds, monitor & logs',
          ]
        : <String>[
            'At-a-glance monitoring',
            'Primary system records — noise_events',
            'Evaluation & decision support',
            'Manage your teaching schedule',
            'ESP32 hardware configuration',
          ];

    return Scaffold(
      backgroundColor: const Color(0xFF0f1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2332),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_currentIndex],
              style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              keywords[_currentIndex],
              style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (auth.isLoggedIn)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${auth.name}',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8b9cb3)),
            onPressed: () {
              data.refreshEvents();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, auth, isAdmin, titles),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38bdf8)))
          : RefreshIndicator(
              onRefresh: () => data.refreshEvents(),
              child: screens[_currentIndex],
            ),
      bottomNavigationBar: _buildBottomNav(isAdmin),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider auth, bool isAdmin, List<String> titles) {
    return Drawer(
      backgroundColor: const Color(0xFF1a2332),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2d3a4f))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Noise Monitor',
                    style: TextStyle(color: Color(0xFFe8edf4), fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Traffic-light IoT system',
                    style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 11)),
                  const SizedBox(height: 16),
                  Text('Signed in as',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  Text(auth.name,
                    style: const TextStyle(color: Color(0xFFe8edf4), fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFFef4444).withValues(alpha: 0.2)
                          : const Color(0xFF22c55e).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      auth.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isAdmin ? const Color(0xFFfca5a5) : const Color(0xFF86efac),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _drawerItem(1, Icons.list_alt_rounded, 'Noise Logs'),
                  if (isAdmin) _drawerItem(2, Icons.mic_rounded, 'Audio Evidence'),
                  _drawerItem(3, Icons.bar_chart_rounded, 'Reports'),
                  if (isAdmin) _drawerItem(4, Icons.history_rounded, 'Audit Trail'),
                  _drawerItem(titles.length - 2, Icons.calendar_today_rounded, 'My Schedule'),
                  _drawerItem(titles.length - 1, Icons.settings_ethernet_rounded, 'Device Config'),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2d3a4f), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, size: 16, color: Color(0xFF8b9cb3)),
                  label: const Text('Sign out', style: TextStyle(color: Color(0xFF8b9cb3))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2d3a4f)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF38bdf8) : const Color(0xFF8b9cb3), size: 20),
      title: Text(title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF38bdf8) : const Color(0xFF8b9cb3),
          fontSize: 14,
        )),
      selected: isSelected,
      selectedTileColor: const Color(0xFF38bdf8).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildBottomNav(bool isAdmin) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      const BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Logs'),
      if (isAdmin)
        const BottomNavigationBarItem(icon: Icon(Icons.mic_rounded), label: 'Audio'),
      const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
      if (isAdmin) ...[
        const BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Audit'),
      ],
      const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Schedule'),
      const BottomNavigationBarItem(icon: Icon(Icons.settings_ethernet_rounded), label: 'Device'),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2d3a4f))),
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFF1a2332),
        selectedItemColor: const Color(0xFF38bdf8),
        unselectedItemColor: const Color(0xFF8b9cb3),
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex.clamp(0, items.length - 1),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (i) => setState(() => _currentIndex = i),
        items: items,
      ),
    );
  }
}