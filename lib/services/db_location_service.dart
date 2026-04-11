import 'package:shared_preferences/shared_preferences.dart';

/// Persists where the local SQLite DB lives (user-chosen folder).
class DbLocationService {
  static const String _keyAndroidTreeUri = 'db_tree_uri';
  static const String _keyDesktopFolder = 'db_folder_path';

  Future<bool> isConfigured() async {
    final p = await SharedPreferences.getInstance();
    if (p.getString(_keyAndroidTreeUri)?.isNotEmpty == true) return true;
    if (p.getString(_keyDesktopFolder)?.isNotEmpty == true) return true;
    return false;
  }

  Future<String?> getAndroidTreeUri() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyAndroidTreeUri);
  }

  Future<void> setAndroidTreeUri(String uri) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyAndroidTreeUri, uri);
  }

  Future<void> clearAndroidTreeUri() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyAndroidTreeUri);
  }

  Future<String?> getDesktopFolderPath() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyDesktopFolder);
  }

  Future<void> setDesktopFolderPath(String path) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyDesktopFolder, path);
  }
}
