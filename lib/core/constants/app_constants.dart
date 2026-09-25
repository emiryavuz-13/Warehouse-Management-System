/// Uygulama genelinde tekrar eden sabit değerler.
///
/// Şartname 32. bölüm: "Hardcoded tekrar eden değerler constants/theme
/// içerisine alınmalı."
abstract final class AppConstants {
  /// Uygulama adı.
  ///
  /// *İstif* deponun kendi sözcüğü: malı rafa düzenli biçimde yerleştirmek.
  /// Marka işareti için [IstifMark].
  static const String appName = 'İstif';

  /// Adın altında duran açıklama — açılış ve profil ekranında.
  static const String appTagline = 'Depo Yönetim Sistemi';

  /// Uygulama sürümü — profil ekranının alt bilgisi.
  static const String appVersion = '1.0.0';

  /// Mock repository'lerin taklit ettiği ağ gecikmesi.
  ///
  /// Sıfır olmaması önemli: loading state'lerin gerçekten görünmesini sağlar
  /// (şartname 25. bölüm), ama demo akışını yavaşlatmayacak kadar kısadır.
  static const Duration mockLatency = Duration(milliseconds: 280);

  /// Ağır listelerde (hareketler, ürünler) kullanılan daha uzun gecikme.
  static const Duration mockLatencyLong = Duration(milliseconds: 420);

  /// Yazma işlemlerinden sonraki gecikme — onay ekranı anlık kapanmasın.
  static const Duration mockWriteLatency = Duration(milliseconds: 500);

  /// Arama kutusunun tetiklenmeden önce beklediği süre.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Dashboard grafiklerinin kapsadığı gün sayısı (şartname 22. bölüm).
  static const int reportDayRange = 7;

  /// Dashboard "Son Hareketler" bölümünde gösterilen kayıt sayısı.
  static const int dashboardRecentMovementCount = 5;

  /// Ürün detayında gösterilen son hareket sayısı.
  static const int productRecentMovementCount = 6;

  /// Dashboard kritik stok bölümünde gösterilen ürün sayısı.
  static const int dashboardCriticalStockCount = 4;
}

/// Şartname 10. bölümündeki demo barkodları.
///
/// Kamera kullanılamadığında (emülatör, izin reddi, masaüstü) tarayıcı ekranı
/// bu listeyi gösterir ve seçilen barkod gerçekten taranmış gibi işlenir.
abstract final class DemoBarcodes {
  /// Tarayıcı ekranında listelenecek barkodlar; mock ürünlerle eşleşir.
  static const List<String> featured = <String>[
    '8691234567890', // iPhone 15 128GB Siyah
    '8691234567891', // MacBook Air M3 13"
    '8691234567892', // USB-C Kablo 2m
    '8691234567893', // Logitech MX Master 3S
  ];
}
