import 'package:flutter/widgets.dart';

/// Uygulama genelinde kullanılan boşluk, yarıçap ve boyut sabitleri.
///
/// Ekranlarda `16`, `24` gibi sabit sayılar yazmak yerine buradaki değerler
/// kullanılır; böylece tüm modüllerde aynı ritim korunur (şartname 32. bölüm).
abstract final class AppSpacing {
  /// 4 — ikon ile metin arası gibi çok küçük aralıklar.
  static const double xs = 4;

  /// 8 — chip'lerin iç boşluğu, satır içi ayrımlar.
  static const double sm = 8;

  /// 12 — kart içi elemanlar arası.
  static const double md = 12;

  /// 16 — ekran kenar boşluğu ve kart iç boşluğu (varsayılan).
  static const double lg = 16;

  /// 24 — bölümler arası ayrım.
  static const double xl = 24;

  /// 32 — sayfa başı/sonu nefes alanı.
  static const double xxl = 32;

  /// Ekranların sol/sağ kenar boşluğu.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg);

  /// Kartların iç boşluğu.
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Liste ekranlarının alt boşluğu — son eleman FAB altında kalmasın diye.
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(
    lg,
    lg,
    lg,
    xxl * 3,
  );
}

/// Köşe yarıçapları. Kurumsal his için yumuşak ama abartısız değerler.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  static const double xl = 24;
}

/// Dokunma hedefleri ve ikon boyutları.
///
/// Depo çalışanı eldivenli olabilir veya cihazı tek elle kullanır; bu yüzden
/// operasyonel butonlar Material'ın 48dp minimumunun üzerinde tutulur.
abstract final class AppSizes {
  /// Birincil operasyon butonlarının yüksekliği.
  static const double buttonHeight = 52;

  /// İkincil / satır içi butonların yüksekliği.
  static const double compactButtonHeight = 44;

  /// Minimum dokunma alanı.
  static const double minTouchTarget = 48;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  /// Ürün kartlarındaki görsel/placeholder karesi.
  static const double productThumb = 56;
}
