import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

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
}
