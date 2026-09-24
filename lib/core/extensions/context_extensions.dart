import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Ekranlarda sık tekrarlanan `Theme.of(context)` / `MediaQuery.of(context)`
/// çağrılarını kısaltan yardımcılar.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;

  /// Koyu tema aktif mi — ikon/görsel varyantı seçmek için.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Size get screenSize => MediaQuery.sizeOf(this);

  /// Dar telefon ekranı — kart ızgarası sütun sayısını buna göre ayarlarız.
  bool get isCompactWidth => MediaQuery.sizeOf(this).width < 380;

  /// Tablet/geniş ekran — özet kartları 3 sütuna çıkar (şartname 3. bölüm,
  /// "responsive ve farklı ekran boyutlarına uyumlu").
  bool get isWide => MediaQuery.sizeOf(this).width >= 600;

  /// Başarı bildirimi. Yeşil ikon + metin, mevcut snackbar'ı iptal eder.
  void showSuccessSnack(String message) =>
      _showSnack(message, Icons.check_circle_rounded, theme.status.success);

  /// Hata/uyarı bildirimi — validation ve iş kuralı ihlallerinde.
  void showErrorSnack(String message) =>
      _showSnack(message, Icons.error_rounded, theme.status.danger);

  /// Nötr bilgilendirme.
  void showInfoSnack(String message) =>
      _showSnack(message, Icons.info_rounded, theme.status.info);

  void _showSnack(String message, IconData icon, Color accent) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
