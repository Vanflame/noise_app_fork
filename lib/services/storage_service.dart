import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyEspIp = 'esp_ip';
  static const String _keyWifiSsid = 'wifi_ssid';
  static const String _keyWifiPass = 'wifi_password';
  static const String _keyEspSetupDone = 'esp_setup_done';

  Future<String?> getEspIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEspIp);
  }

  Future<void> saveEspIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEspIp, ip);
  }

  Future<String?> getWifiSsid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWifiSsid);
  }

  Future<void> saveWifiSsid(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWifiSsid, ssid);
  }

  Future<String?> getWifiPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWifiPass);
  }

  Future<void> saveWifiPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWifiPass, password);
  }

  Future<bool> isEspSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEspSetupDone) ?? false;
  }

  Future<void> setEspSetupDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEspSetupDone, done);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEspIp);
    await prefs.remove(_keyWifiSsid);
    await prefs.remove(_keyWifiPass);
    await prefs.remove(_keyEspSetupDone);
  }
}