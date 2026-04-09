import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';

class TimeService {
  static final TimeService _instance = TimeService._internal();
  factory TimeService() => _instance;
  TimeService._internal();

  final _storage = const FlutterSecureStorage();
  
  static const _keyLastServerTime = 'last_known_server_time';
  static const _keyLastDeviceTime = 'last_known_device_time';
  static const _keyLastWarningDate = 'last_sub_warning_date';

  /// Fetches current server time from the backend
  Future<DateTime?> fetchServerTime() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return null;

      final response = await http.get(Uri.parse('$apiBaseUrl/get_time.php'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final serverTime = DateTime.parse(data['server_time']);
          await _saveTimeSync(serverTime);
          return serverTime;
        }
      }
    } catch (e) {
      developer.log("Error fetching server time: $e");
    }
    return null;
  }

  /// Saves the last known good time sync
  Future<void> _saveTimeSync(DateTime serverTime) async {
    await _storage.write(key: _keyLastServerTime, value: serverTime.toIso8601String());
    await _storage.write(key: _keyLastDeviceTime, value: DateTime.now().toIso8601String());
  }

  /// Checks if the device time has been tampered with (moved backward)
  Future<bool> isTimeTampered() async {
    final lastDeviceTimeStr = await _storage.read(key: _keyLastDeviceTime);
    if (lastDeviceTimeStr == null) return false;

    final lastDeviceTime = DateTime.parse(lastDeviceTimeStr);
    final currentDeviceTime = DateTime.now();

    // If current device time is earlier than the last known device time, it's tampered
    if (currentDeviceTime.isBefore(lastDeviceTime.subtract(const Duration(seconds: 10)))) {
       return true;
    }
    return false;
  }

  /// Checks if there's a significant drift (> 5 mins) between device and server
  bool isTimeDrifted(DateTime serverTime) {
    final deviceTime = DateTime.now();
    final difference = deviceTime.difference(serverTime).inMinutes.abs();
    return difference > 5;
  }

  /// Gets the last date a subscription warning was shown
  Future<String?> getLastWarningDate() async {
    return await _storage.read(key: _keyLastWarningDate);
  }

  /// Saves the current date as the last warning date
  Future<void> saveWarningDate(String dateStr) async {
    await _storage.write(key: _keyLastWarningDate, value: dateStr);
  }

  /// Returns a tamper-resistant estimate of the current time.
  ///
  /// When online, call [fetchServerTime] first so the cache is fresh.
  /// When offline, this method reads the last cached server/device time pair
  /// from [FlutterSecureStorage] and adds the elapsed device time since that
  /// sync. If the device clock was wound backward the elapsed value is negative
  /// and is clamped to zero — the method then returns the cached server time
  /// itself, which is the most conservative (earliest safe) value.
  Future<DateTime> getReliableNow() async {
    final rawServer = await _storage.read(key: _keyLastServerTime);
    final rawDevice = await _storage.read(key: _keyLastDeviceTime);
    if (rawServer == null || rawDevice == null) return DateTime.now();

    final serverTime = DateTime.tryParse(rawServer);
    final deviceTime = DateTime.tryParse(rawDevice);
    if (serverTime == null || deviceTime == null) return DateTime.now();

    final elapsed = DateTime.now().difference(deviceTime);
    final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    return serverTime.add(safeElapsed);
  }

  /// Helper to force update the "last known" time if server validates it
  Future<void> forceResync() async {
    final serverTime = await fetchServerTime();
    if (serverTime != null) {
      await _saveTimeSync(serverTime);
    }
  }
}
