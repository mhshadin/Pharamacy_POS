import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'utils/colors.dart';
import 'screens/splash_screen.dart';
import 'providers/pos_provider.dart';
import 'providers/admin_provider.dart';
import 'services/database_helper.dart';
import 'services/speech_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize the database (creates tables + seeds on first launch)
  await DatabaseHelper().database;

  // Warm up speech engine / request mic access at startup.
  // - On Android/iOS this will show the OS permission dialog once.
  // - On Windows this will just initialize; access is controlled by
  //   system privacy settings (no in-app dialog).
  if (!Platform.isLinux && !Platform.isMacOS) {
    await SpeechService.instance.requestPermission();
  }

  runApp(const PharmacyPOSApp());
}

class PharmacyPOSApp extends StatelessWidget {
  const PharmacyPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => POSProvider()..loadProducts()),
        ChangeNotifierProvider(create: (_) => AdminProvider()..loadData()),
      ],
      child: MaterialApp(
        title: 'Pharmacy POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: false,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primaryDark,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryDark,
            secondary: AppColors.secondaryAccent,
            surface: AppColors.white,
            error: AppColors.error,
          ),
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme)
              .apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryDark,
            elevation: 4,
            centerTitle: true,
            iconTheme: IconThemeData(color: AppColors.white),
            titleTextStyle: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
