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
import 'services/notification_service.dart';
import 'widgets/time_lock_barrier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService().init();

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
        ChangeNotifierProvider(create: (_) => AdminProvider()..loadData()),
        ChangeNotifierProvider(
          create: (context) =>
              POSProvider(context.read<AdminProvider>())..loadProducts(),
        ),
      ],
      child: MaterialApp(
        title: 'Pharmacy POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primaryDark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryDark,
            primary: AppColors.primaryDark,
            secondary: AppColors.secondaryAccent,
            surface: AppColors.white,
            error: AppColors.error,
            onPrimary: AppColors.white,
          ),
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).copyWith(
            displayLarge: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            displayMedium: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            displaySmall: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            headlineLarge: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            headlineMedium: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            headlineSmall: GoogleFonts.lexend(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            titleLarge: GoogleFonts.lexend(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
            titleMedium: GoogleFonts.lexend(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
            titleSmall: GoogleFonts.lexend(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ).apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.primaryDark,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: AppColors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: AppColors.white),
            titleTextStyle: GoogleFonts.lexend(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.divider, width: 1),
            ),
            color: AppColors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.white,
              minimumSize: const Size(88, 48), // Good touch targets
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        builder: (context, child) {
          return TimeLockBarrier(child: child!);
        },
        home: const SplashScreen(),
      ),
    );
  }
}
