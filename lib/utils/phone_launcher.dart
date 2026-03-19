import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'colors.dart';

Future<bool> tryDialPhone(BuildContext context, String phone) async {
  final trimmed = phone.trim();
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (trimmed.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Supplier phone number is missing.'),
        backgroundColor: AppColors.error,
      ),
    );
    return false;
  }

  final uri = Uri(scheme: 'tel', path: trimmed);

  try {
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Phone calls are not supported on this device.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Could not open the dialer.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return ok;
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Could not open the dialer.'),
        backgroundColor: AppColors.error,
      ),
    );
    return false;
  }
}

