import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_router.dart';

void main() {
  MalinovkaBinding();
  runApp(const ProviderScope(child: MainApp()));
}

class MalinovkaBinding extends WidgetsFlutterBinding {
  @override
  void initMouseTracker([MouseTracker? tracker]) {
    // Flutter Windows debug builds can recursively update MouseTracker while
    // routes rebuild under the cursor. The app does not rely on hover effects,
    // so keep pointer clicks intact and disable hover tracking globally.
    // ignore: invalid_use_of_visible_for_testing_member
    super.initMouseTracker(_NoOpMouseTracker());
  }
}

class _NoOpMouseTracker extends MouseTracker {
  _NoOpMouseTracker() : super((position, viewId) => HitTestResult());

  @override
  void updateWithEvent(PointerEvent event, HitTestResult? hitTestResult) {}

  @override
  void updateAllDevices() {}
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFEA6228);
    return MaterialApp.router(
      title: 'Malinovka Smart Home',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          primary: accent,
          secondary: accent,
          surface: const Color(0xFF1E222B),
        ),
        scaffoldBackgroundColor: const Color(0xFF151922),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF262B35),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2D3340),
          selectedColor: accent,
          labelStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          side: BorderSide.none,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF202631),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
