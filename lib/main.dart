import 'dart:async';
import 'package:flutter/material.dart';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'utils/colors.dart';
import 'utils/text_scale_config.dart';
import 'screens/splash_screen.dart';
import 'providers/pos_provider.dart';
import 'providers/admin_provider.dart';
import 'services/database_helper.dart';
import 'services/speech_service.dart';
import 'services/notification_service.dart';
import 'screens/alarm_alert_screen.dart';
import 'widgets/time_lock_barrier.dart';
import 'providers/language_provider.dart';
import 'package:alarm/alarm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications & alarms
  await NotificationService().init();
  
  // Initialize the 'alarm' package (supports iOS, Android, and macOS)
  if (!Platform.isWindows && !Platform.isLinux) {
    try {
      await Alarm.init();
      await Alarm.setWarningNotificationOnKill(
        'Alarm reliability warning',
        'Please keep Pharmacy POS in recent apps for best alarm reliability.',
      );
    } catch (e) {
      developer.log("Alarm package init failed: $e");
    }
  }

  // Initialize FFI for desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Database opens from [SplashScreen] (or [DbLocationGateScreen] if init fails).

  // Warm up speech engine / request mic access at startup.
  // - On Android/iOS this will show the OS permission dialog once.
  // - On Windows this will just initialize; access is controlled by
  //   system privacy settings (no in-app dialog).
  if (!Platform.isLinux && !Platform.isMacOS) {
    await SpeechService.instance.requestPermission();
  }
  
  // Initialize date formatting for English and Bangla
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('bn', null);

  final clarityConfig = ClarityConfig(
    projectId: "w8wdu2sjar",
    logLevel: LogLevel.None,
  );

  runApp(ClarityWidget(
    clarityConfig: clarityConfig,
    app: const PharmacyPOSApp(),
  ));
}

class PharmacyPOSApp extends StatefulWidget {
  const PharmacyPOSApp({super.key});

  @override
  State<PharmacyPOSApp> createState() => _PharmacyPOSAppState();
}

class _PharmacyPOSAppState extends State<PharmacyPOSApp>
    with WidgetsBindingObserver {
  StreamSubscription? _ringingSubscription;
  bool _isPresentingAlarmScreen = false;
  int? _lastPresentedAlarmId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ringingSubscription = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isEmpty) return;
      final alarm = alarmSet.alarms.first;
      if (_isPresentingAlarmScreen && _lastPresentedAlarmId == alarm.id) {
        return;
      }
      final args = AlarmAlertArgs.fromPayload(alarm.payload)
          .copyWith(alarmId: alarm.id);
      final navigator = NotificationService.navigatorKey.currentState;
      if (navigator == null) return;
      _isPresentingAlarmScreen = true;
      _lastPresentedAlarmId = alarm.id;
      navigator
          .pushNamed(
            '/alarm_alert',
            arguments: args,
          )
          .whenComplete(() {
            _isPresentingAlarmScreen = false;
          });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringingSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      DatabaseHelper().syncRuntimeToAuthoritative();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(
          create: (context) => POSProvider(context.read<AdminProvider>()),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          final isBn = langProvider.isBangla;
          
          return MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            title: isBn ? langProvider.strings.appName : 'Pharmacy POS',
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
              textTheme: (isBn 
                ? GoogleFonts.notoSansBengaliTextTheme(Theme.of(context).textTheme)
                : GoogleFonts.interTextTheme(Theme.of(context).textTheme)
              ).copyWith(
                displayLarge: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.bold, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                displayMedium: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.bold, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                displaySmall: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.bold, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                headlineLarge: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.bold, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                headlineMedium: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.bold, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                headlineSmall: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.bold, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                titleLarge: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.w600, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                titleMedium: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.w600, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                titleSmall: isBn ? GoogleFonts.notoSansBengali(fontWeight: FontWeight.w600, color: AppColors.primaryDark) : GoogleFonts.lexend(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
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
                titleTextStyle: isBn 
                  ? GoogleFonts.notoSansBengali(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold)
                  : GoogleFonts.lexend(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
              // Ignore system font-size / accessibility text scale so layout matches
              // across devices. Clamp alone only helps when OS scale > 1.0; at 1.0
              // it looks unchanged. Use [kAppVisualTextScale] to tweak density app-wide.
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: appRootTextScaler()),
                child: TimeLockBarrier(child: child!),
              );
            },
            routes: {
              '/alarm_alert': (_) => const AlarmAlertScreen(),
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
