import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'status_tone_colors.dart';

/// Kullanıcının tema tercihini tutar ve cihazda saklar.
///
/// Tercih profil ekranından değiştirilir. Varsayılan [ThemeMode.system]
/// olduğu için uygulama ilk açılışta cihazın moduna uyar.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String _prefsKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    // Kayıtlı tercih asenkron okunur; gelene kadar sistem modu kullanılır.
    // Bu sayede MaterialApp'i bir FutureBuilder'a sarmak gerekmez.
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_prefsKey);
      if (saved == null) return;
      final ThemeMode restored = ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
      if (restored != state) state = restored;
    } on Object {
      // Tercih okunamazsa sessizce sistem modunda kalırız; bu bir demo
      // uygulaması ve tema tercihi kritik veri değil.
    }
  }

  /// Tercihi değiştirir ve kalıcı olarak saklar.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } on Object {
      // Saklanamadıysa tercih bu oturum için yine de geçerli.
    }
  }

  /// Açık ve koyu tema arasında geçiş yapar.
  ///
  /// Sistem modundayken, o an görünen temanın tersine geçer.
  Future<void> toggle({required bool currentlyDark}) {
    return setMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Aktif tema modu.
final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Tema modunun Türkçe etiketi — profil ekranında gösterilir.
extension ThemeModeLabelX on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => 'Sistem',
    ThemeMode.light => 'Açık',
    ThemeMode.dark => 'Koyu',
  };

  IconData get icon => switch (this) {
    ThemeMode.system => AppIcons.themeSystem,
    ThemeMode.light => AppIcons.themeLight,
    ThemeMode.dark => AppIcons.themeDark,
  };
}
