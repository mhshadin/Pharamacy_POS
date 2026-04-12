import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests OS storage / media permissions before opening the DB on Android.
/// (Downloads + MediaStore sync paths need broad file access on many OEMs.)
Future<void> requestStorageAccessBeforeDatabaseOpen() async {
  if (!Platform.isAndroid) return;
  final info = await DeviceInfoPlugin().androidInfo;
  if (info.version.sdkInt >= 33) {
    await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();
  } else {
    await Permission.storage.request();
  }
}
