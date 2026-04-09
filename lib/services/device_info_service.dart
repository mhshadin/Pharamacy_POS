import 'dart:io';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';

/// Model string + human-readable device name for backend `devices` table.
class DeviceDescriptor {
  const DeviceDescriptor({
    required this.model,
    required this.displayName,
  });

  final String model;
  final String displayName;
}

class DeviceInfoService {
  DeviceInfoService._();
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  static String _stableHash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static Future<DeviceDescriptor> getDescriptor() async {
    try {
      if (Platform.isAndroid) {
        final a = await _plugin.androidInfo;
        final model = '${a.manufacturer} ${a.model}'.trim();
        final display = a.model.isNotEmpty ? a.model : model;
        return DeviceDescriptor(model: model, displayName: display);
      }
      if (Platform.isIOS) {
        final i = await _plugin.iosInfo;
        final model = i.utsname.machine;
        final display = i.name.isNotEmpty ? i.name : model;
        return DeviceDescriptor(model: model, displayName: display);
      }
      if (Platform.isWindows) {
        final w = await _plugin.windowsInfo;
        return DeviceDescriptor(
          model: w.computerName,
          displayName: w.computerName,
        );
      }
      if (Platform.isMacOS) {
        final m = await _plugin.macOsInfo;
        final name = m.computerName.isNotEmpty ? m.computerName : m.model;
        return DeviceDescriptor(model: m.model, displayName: name);
      }
      if (Platform.isLinux) {
        final l = await _plugin.linuxInfo;
        return DeviceDescriptor(
          model: l.prettyName,
          displayName: l.name,
        );
      }
    } catch (_) {
      /* fall through */
    }
    return const DeviceDescriptor(model: 'Unknown', displayName: 'POS Device');
  }

  /// Release-canonical hardware UID (debug mismatch is intentionally ignored).
  static Future<String> resolveStableHardwareUid() async {
    try {
      if (Platform.isAndroid) {
        final a = await _plugin.androidInfo;
        final androidId = a.id.trim();
        if (androidId.isNotEmpty) {
          return 'android_$androidId';
        }
        final fallbackSource =
            '${a.manufacturer}|${a.model}|${a.brand}|${a.hardware}|${a.fingerprint}';
        return 'android_fallback_${_stableHash(fallbackSource).substring(0, 24)}';
      }

      if (Platform.isIOS) {
        final i = await _plugin.iosInfo;
        final vendorId = (i.identifierForVendor ?? '').trim();
        if (vendorId.isNotEmpty) {
          return 'ios_$vendorId';
        }
        final fallbackSource =
            '${i.utsname.machine}|${i.name}|${i.systemVersion}|${i.model}';
        return 'ios_fallback_${_stableHash(fallbackSource).substring(0, 24)}';
      }
    } catch (_) {
      // Fall through to generic fallback.
    }

    final descriptor = await getDescriptor();
    final generic =
        '${Platform.operatingSystem}|${descriptor.model}|${descriptor.displayName}';
    return 'generic_${_stableHash(generic).substring(0, 24)}';
  }
}
