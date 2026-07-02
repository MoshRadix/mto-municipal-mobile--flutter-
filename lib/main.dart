import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/auth_provider.dart';
import 'providers/issue_provider.dart';
import 'providers/language_provider.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'views/splash_screen.dart';

const String backgroundSyncTask = 'municipalIssueBackgroundSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await DatabaseService.init();
    final apiService = ApiService();
    final syncService = SyncService(
      apiService: apiService,
      dbService: DatabaseService(),
    );
    await syncService.syncNow();
    return true;
  });
}

Future<void> _configureBackgroundSync() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    backgroundSyncTask,
    backgroundSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize local database (Hive)
  final dbService = DatabaseService();
  await DatabaseService.init();

  // 2. Initialize api service
  final apiService = ApiService();

  // 3. Initialize background synchronization
  final syncService = SyncService(apiService: apiService, dbService: dbService);
  syncService.initMonitoring(); // Start listening for online connection status

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(dbService: dbService),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(apiService: apiService),
        ),
        ChangeNotifierProvider<IssueProvider>(
          create: (_) => IssueProvider(
            apiService: apiService,
            dbService: dbService,
            syncService: syncService,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
  unawaited(_configureBackgroundSync());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    const primary = Color(0xFF087F8C);
    const ink = Color(0xFF16323A);
    const canvas = Color(0xFFF3F7F8);
    final baseTextTheme = ThemeData.light().textTheme.apply(
      fontFamily: languageProvider.isRtl ? 'Faruma' : 'sans-serif',
      fontFamilyFallback: const ['Faruma'],
      bodyColor: ink,
      displayColor: ink,
    );

    return MaterialApp(
      title: 'Nala Addu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: const Color(0xFFFF8A5B),
          surface: Colors.white,
        ),
        textTheme: baseTextTheme,
        scaffoldBackgroundColor: canvas,
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2EBED)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7FAFA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E4E6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E4E6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.8),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
