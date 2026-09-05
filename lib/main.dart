import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/app_router.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'data/history_service.dart';
import 'data/settings_service.dart';

import 'data/api/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.initGlobal();
  await SettingsService().init();
  await HistoryService().init();
  runApp(
    const ProviderScope(
      child: BitChordApp(),
    ),
  );
}

class BitChordApp extends StatelessWidget {
  const BitChordApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: Colors.black,
      surface: const Color(0xFF121212),
      surfaceContainerHighest: const Color(0xFF282828),
    );

    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        ThemeMode currentThemeMode;
        switch (settings.theme) {
          case 'Light':
            currentThemeMode = ThemeMode.light;
            break;
          case 'System':
            currentThemeMode = ThemeMode.system;
            break;
          case 'Dark':
          case 'Dynamic':
          case 'Shuffle Dynamic':
          default:
            currentThemeMode = ThemeMode.dark;
            break;
        }

        return MaterialApp.router(
          title: 'SillyGoose',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black,
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.black,
              indicatorColor: Colors.white.withOpacity(0.15),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Colors.white);
                }
                return const IconThemeData(color: Colors.grey);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold);
                }
                return const TextStyle(color: Colors.grey, fontSize: 12);
              }),
            ),
          ),
          themeMode: currentThemeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
