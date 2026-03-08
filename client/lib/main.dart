import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth_gate_screen.dart';
import 'services/gig_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GiggoApp());
}

class GiggoApp extends StatelessWidget {
  const GiggoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = GigRepository();
    const oceanBlue = Color(0xFF0A84FF);
    const deepOcean = Color(0xFF053B70);
    const seaFoam = Color(0xFFF3FAFF);
    const cyanGlow = Color(0xFF49D6FF);

    return MaterialApp(
      title: 'Giggo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: oceanBlue,
          primary: oceanBlue,
          secondary: cyanGlow,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: seaFoam,
        appBarTheme: const AppBarTheme(
          backgroundColor: deepOcean,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: oceanBlue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: oceanBlue,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: deepOcean,
            side: const BorderSide(color: oceanBlue),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: oceanBlue.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: oceanBlue.withValues(alpha: 0.4)),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        useMaterial3: true,
      ),
      home: AuthGateScreen(repository: repository),
    );
  }
}
