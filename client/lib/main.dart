import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_theme_controller.dart';
import 'firebase_options.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/service_public_page_screen.dart';
import 'services/gig_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedThemeMode();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GiggoApp());
}

class GiggoApp extends StatefulWidget {
  const GiggoApp({super.key, this.homeOverride});

  final Widget? homeOverride;

  @override
  State<GiggoApp> createState() => _GiggoAppState();
}

class _GiggoAppState extends State<GiggoApp> {
  late final GigRepository _repository = GigRepository();

  @override
  Widget build(BuildContext context) {
    const oceanBlue = Color(0xFF0A84FF);
    const deepOcean = Color(0xFF053B70);
    const seaFoam = Color(0xFFF3FAFF);
    const cyanGlow = Color(0xFF49D6FF);
    const ink = Color(0xFF102A43);
    const darkSurface = Color(0xFF121212);
    const darkPanel = Color(0xFF1E1E1E);
    const darkText = Color(0xFFE5E7EB);

    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: oceanBlue,
        primary: oceanBlue,
        secondary: cyanGlow,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: seaFoam,
      textTheme: ThemeData.light().textTheme.copyWith(
            headlineSmall: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -0.2,
            ),
            titleLarge: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -0.1,
            ),
            titleMedium: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ink,
            ),
            bodyMedium: const TextStyle(
              height: 1.35,
              color: Color(0xFF243B53),
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepOcean,
        foregroundColor: Colors.white,
        centerTitle: true,
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
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: oceanBlue, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: oceanBlue.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? deepOcean : const Color(0xFF486581),
          );
        }),
      ),
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: oceanBlue,
        brightness: Brightness.dark,
        primary: cyanGlow,
        secondary: oceanBlue,
        surface: darkPanel,
      ),
      scaffoldBackgroundColor: darkSurface,
      textTheme: ThemeData.dark().textTheme.copyWith(
            headlineSmall: const TextStyle(
              fontWeight: FontWeight.w800,
              color: darkText,
              letterSpacing: -0.2,
            ),
            titleLarge: const TextStyle(
              fontWeight: FontWeight.w800,
              color: darkText,
              letterSpacing: -0.1,
            ),
            titleMedium: const TextStyle(
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
            bodyMedium: const TextStyle(
              height: 1.35,
              color: Color(0xFFD1D5DB),
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: cyanGlow,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanGlow,
          foregroundColor: Colors.black,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cyanGlow,
          side: const BorderSide(color: cyanGlow),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkPanel,
        selectedColor: cyanGlow.withValues(alpha: 0.20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cyanGlow.withValues(alpha: 0.35)),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: darkPanel,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkPanel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cyanGlow, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF181818),
        indicatorColor: cyanGlow.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? cyanGlow : Colors.white70);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? cyanGlow : Colors.white70,
          );
        }),
      ),
      useMaterial3: true,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Giggo',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: widget.homeOverride ?? _AppEntryScreen(repository: _repository),
        );
      },
    );
  }
}

class _AppEntryScreen extends StatelessWidget {
  const _AppEntryScreen({required this.repository});

  final GigRepository repository;

  @override
  Widget build(BuildContext context) {
    final fragment = Uri.base.fragment;
    if (fragment.startsWith('/service/')) {
      final slug = fragment.replaceFirst('/service/', '').trim();
      if (slug.isNotEmpty) {
        return ServicePublicPageScreen(
          repository: repository,
          shareSlug: slug,
          showNavigationBar: true,
        );
      }
    }

    return AuthGateScreen(repository: repository);
  }
}
