import 'package:flutter/material.dart';

/// Ham renk paleti.
///
/// Şartname 5. bölüm: renkler dekorasyon değil, **durum göstergesidir**.
/// Bu yüzden palet dar tutulmuştur; her rengin operasyonel bir anlamı vardır.
abstract final class AppColorTokens {
  /// Kurumsal lacivert — birincil marka rengi.
  static const Color primary = Color(0xFF1B4B8F);
  static const Color primaryDark = Color(0xFF6FA8FF);

  /// Depo/lojistik çağrışımı taşıyan ikincil ton.
  static const Color secondary = Color(0xFF0F766E);
  static const Color secondaryDark = Color(0xFF4DD4C5);

  // --- Durum renkleri (açık tema) ---
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);
  static const Color info = Color(0xFF1D4ED8);
  static const Color transfer = Color(0xFF6D28D9);
  static const Color neutral = Color(0xFF475569);

  // --- Durum renkleri (koyu tema) ---
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color infoDark = Color(0xFF7DA7FF);
  static const Color transferDark = Color(0xFFC4A5FF);
  static const Color neutralDark = Color(0xFF94A3B8);

  // --- Yüzeyler ---
  static const Color lightBackground = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color darkBackground = Color(0xFF0E1420);
  static const Color darkSurface = Color(0xFF18202E);
  static const Color darkBorder = Color(0xFF2B3546);
}

/// Durum renklerini tema üzerinden taşıyan uzantı.
///
/// Widget'lar `Theme.of(context).status.critical` gibi okur; böylece açık ve
/// koyu temada aynı kod doğru kontrastı verir ve hiçbir ekranda sabit renk
/// yazılmaz.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.info,
    required this.infoContainer,
    required this.transfer,
    required this.transferContainer,
    required this.neutral,
    required this.neutralContainer,
    required this.border,
  });

  /// İşlem başarılı, stok normal, sipariş tamamlandı.
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Kritik stok, bekleyen iş, dikkat gerektiren durum.
  final Color warning;
  final Color warningContainer;

  /// Stok yok, iptal, hata, yetersiz miktar.
  final Color danger;
  final Color dangerContainer;

  /// Devam eden işlem, bilgilendirme.
  final Color info;
  final Color infoContainer;

  /// Lokasyonlar arası transfer hareketi.
  final Color transfer;
  final Color transferContainer;

  /// Pasif / nötr durum.
  final Color neutral;
  final Color neutralContainer;

  /// Kart ve ayırıcı kenarlığı.
  final Color border;

  factory AppStatusColors.light() => const AppStatusColors(
    success: AppColorTokens.success,
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: AppColorTokens.warning,
    warningContainer: Color(0xFFFEF3C7),
    danger: AppColorTokens.danger,
    dangerContainer: Color(0xFFFEE2E2),
    info: AppColorTokens.info,
    infoContainer: Color(0xFFDBEAFE),
    transfer: AppColorTokens.transfer,
    transferContainer: Color(0xFFEDE9FE),
    neutral: AppColorTokens.neutral,
    neutralContainer: Color(0xFFE9EEF5),
    border: AppColorTokens.lightBorder,
  );

  factory AppStatusColors.dark() => const AppStatusColors(
    success: AppColorTokens.successDark,
    successContainer: Color(0xFF14321F),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: AppColorTokens.warningDark,
    warningContainer: Color(0xFF3A2B0C),
    danger: AppColorTokens.dangerDark,
    dangerContainer: Color(0xFF3B1717),
    info: AppColorTokens.infoDark,
    infoContainer: Color(0xFF16233D),
    transfer: AppColorTokens.transferDark,
    transferContainer: Color(0xFF2A1F44),
    neutral: AppColorTokens.neutralDark,
    neutralContainer: Color(0xFF212B3B),
    border: AppColorTokens.darkBorder,
  );

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? info,
    Color? infoContainer,
    Color? transfer,
    Color? transferContainer,
    Color? neutral,
    Color? neutralContainer,
    Color? border,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      transfer: transfer ?? this.transfer,
      transferContainer: transferContainer ?? this.transferContainer,
      neutral: neutral ?? this.neutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      border: border ?? this.border,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferContainer: Color.lerp(transferContainer, other.transferContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      neutralContainer: Color.lerp(neutralContainer, other.neutralContainer, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// `Theme.of(context).status` kısayolu.
extension AppThemeStatusX on ThemeData {
  AppStatusColors get status =>
      extension<AppStatusColors>() ?? AppStatusColors.light();
}

/// `context.status` ve `context.colors` kısayolları.
extension AppContextColorsX on BuildContext {
  AppStatusColors get status => Theme.of(this).status;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
