import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

/// Uygulamanın kökü.
///
/// Tek sorumluluğu tema, dil ve navigasyonu kurmak; hiçbir iş mantığı
/// içermez. Navigasyon 5. commit'te `router.dart` ile buraya bağlanacak.
class WarehouseApp extends ConsumerWidget {
  const WarehouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,

      // Uygulama tamamen Türkçedir; Material bileşenlerinin (tarih seçici,
      // metin alanı menüleri vb.) de Türkçe görünmesi için gereklidir.
      locale: const Locale('tr', 'TR'),
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const _ThemePreviewPage(),
    );
  }
}

/// Geçici açılış sayfası.
///
/// Temanın kurulduğunu doğrulamak için vardır; 5. commit'te `AppRouter` ile
/// değiştirilecektir.
class _ThemePreviewPage extends StatelessWidget {
  const _ThemePreviewPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Center(
        child: Text(
          'Altyapı hazır.\nEkranlar sıradaki commitlerde eklenecek.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
