import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../providers/pos_provider.dart';
import '../services/database_helper.dart';
import '../services/db_location_service.dart';
import '../utils/colors.dart';
import 'splash_screen.dart';

/// Shown until the user picks a folder for [pharmacy.db] (required before SQLite opens).
class DbLocationGateScreen extends StatefulWidget {
  const DbLocationGateScreen({super.key});

  @override
  State<DbLocationGateScreen> createState() => _DbLocationGateScreenState();
}

class _DbLocationGateScreenState extends State<DbLocationGateScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryEnterIfConfigured());
  }

  Future<void> _tryEnterIfConfigured() async {
    if (!mounted || _busy) return;
    if (!await DbLocationService().isConfigured()) return;
    await _openDatabaseAndGo();
  }

  Future<void> _openDatabaseAndGo() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final admin = context.read<AdminProvider>();
      final pos = context.read<POSProvider>();
      await DatabaseHelper().ensureDatabaseReady();
      if (!mounted) return;
      await admin.loadData();
      await pos.loadProducts();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    } on DatabaseLocationNotConfigured {
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (Platform.isAndroid) {
        final uri = await DatabaseHelper().pickAndroidDocumentTree();
        if (uri == null || uri.isEmpty) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        await DbLocationService().setAndroidTreeUri(uri);
      } else {
        final path = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Choose folder for pharmacy.db',
        );
        if (path == null || path.isEmpty) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        await DbLocationService().setDesktopFolderPath(path);
      }
      await DatabaseHelper().resetConnection();
      await _openDatabaseAndGo();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Database folder',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                Platform.isAndroid
                    ? 'Choose a folder on this device. The app will store pharmacy.db there. '
                        'After reinstall, use the system folder picker and select the same folder to load your data.'
                    : 'Choose a folder where pharmacy.db will be stored.',
                style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _pickFolder,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_busy ? 'Please wait…' : 'Choose folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
