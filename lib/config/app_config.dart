class AppConfig {
  static const String supabaseUrl = 'https://dprqmezzvncftaoksauz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwcnFtZXp6dm5jZnRhb2tzYXV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkzMDkxODIsImV4cCI6MjA3NDg4NTE4Mn0.wzT5ZkCoINaaGSEMXna0fW2Yv04s6DkCKVb5qk5s4G8';

  static const int sessionTimeoutMs = 30 * 60 * 1000;
  static const int autoRefreshInterval = 10000;
  static const int logsPageSize = 15;

  static const Map<String, Map<String, String>> routes = {
    'dashboard': {
      'title': 'Dashboard',
      'keyword': 'At-a-glance monitoring',
    },
    'logs': {
      'title': 'Noise Logs',
      'keyword': 'Primary system records — noise_events',
    },
    'audio': {
      'title': 'Audio Evidence',
      'keyword': 'RED events with audio — noise_events',
    },
    'settings': {
      'title': 'System Settings',
      'keyword': 'Admin — thresholds & alerts',
    },
    'reports': {
      'title': 'Reports & Analytics',
      'keyword': 'Evaluation & decision support',
    },
    'audit': {
      'title': 'Audit Trail',
      'keyword': 'audit_logs table',
    },
  };

  static const Map<String, dynamic> defaultSettings = {
    'thresholdGreen': 60,
    'thresholdYellow': 74,
    'thresholdRed': 75,
    'buzzerEnabled': true,
    'maxBeeps': 3,
    'buzzerCooldown': 10,
    'audioLengthMin': 3,
    'audioLengthMax': 5,
    'alertCooldown': 30,
    'retentionDays': 14,
    'teacherAccessHours': 48,
  };
}