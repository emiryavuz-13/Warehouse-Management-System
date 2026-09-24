import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

/// Uygulamanın kökü.
///
/// Tek sorumluluğu tema, dil ve navigasyonu kurmak; hiçbir iş mantığı
/// içermez.
class WarehouseApp extends ConsumerWidget {
  const WarehouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,

      // Uygulama tamamen Türkçedir; Material bileşenlerinin (tarih seçici,
      // metin alanı menüleri vb.) de Türkçe görünmesi için gereklidir.
      locale: const Locale('tr', 'TR'),
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Operasyonel ekranlarda okunabilirlik önemli: cihazın yazı tipi
      // ölçeği çok büyükse kartlardaki sayılar ve etiketler taşar.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
