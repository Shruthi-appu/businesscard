import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'ui/softxu_controls.dart';

class SoftxuApp extends ConsumerWidget {
  const SoftxuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    if (iphoneApp) {
      return CupertinoApp.router(
        title: 'Softxu',
        theme: const CupertinoThemeData(
          primaryColor: Color(0xFF0F6E56),
          scaffoldBackgroundColor: Color(0xFFF3EEE4),
          barBackgroundColor: Color(0xFFF7FFFB),
          applyThemeToAll: true,
        ),
        routerConfig: router,
      );
    }
    return MaterialApp.router(
      title: 'Softxu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6E56),
          primary: const Color(0xFF0F6E56),
          surface: const Color(0xFFF7FFFB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3EEE4),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7FFFB),
          foregroundColor: Color(0xFF0F0F0F),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F0F0F),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F6E56),
            foregroundColor: const Color(0xFFF7FFFB),
            minimumSize: const Size(64, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F6E56),
            minimumSize: const Size(64, 48),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      routerConfig: router,
    );
  }
}
