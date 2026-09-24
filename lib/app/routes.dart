/// Uygulamadaki tüm rota yolları.
///
/// Ekranlar `'/products/p-01'` gibi metinleri elle yazmaz; buradaki
/// yardımcıları çağırır. Böylece bir yol değiştiğinde derleyici tüm çağrı
/// yerlerini gösterir.
///
/// Mock bildirimlerin `targetRoute` değerleri de bu yollarla eşleşir
/// (şartname 20. bölüm): kullanıcı bildirime dokunduğunda ilgili kayda gider.
abstract final class AppRoutes {
  // --- Açılış ---
  static const String splash = '/splash';

  // --- Bottom navigation sekmeleri (şartname 6. bölüm) ---
  static const String dashboard = '/dashboard';
  static const String stock = '/stock';
  static const String orders = '/orders';
  static const String scan = '/scan';
  static const String profile = '/profile';

  // --- Ürünler (şartname 8. bölüm) ---
  static const String products = '/products';
  static String productDetail(String productId) => '/products/$productId';

  // --- Mal kabul ve yerleştirme (şartname 11-12. bölümler) ---
  static const String receiving = '/receiving';
  static String receiptDetail(String receiptId) => '/receiving/$receiptId';
  static String putaway(String receiptId) => '/receiving/$receiptId/putaway';

  // --- Sipariş ve toplama (şartname 13-14. bölümler) ---
  static String orderDetail(String orderId) => '/orders/$orderId';
  static String picking(String orderId) => '/orders/$orderId/picking';

  // --- Transfer (şartname 15. bölüm) ---
  static const String transfer = '/transfer';

  /// Ürün detayından gelindiğinde ürün önceden seçili açılır.
  static String transferForProduct(String productId) =>
      '/transfer?productId=$productId';

  // --- Sayım (şartname 16. bölüm) ---
  static const String counts = '/counts';
  static String countDetail(String countId) => '/counts/$countId';

  // --- Sevkiyat (şartname 17. bölüm) ---
  static const String shipments = '/shipments';
  static String shipmentDetail(String shipmentId) => '/shipments/$shipmentId';

  // --- Lokasyonlar (şartname 18. bölüm) ---
  static const String locations = '/locations';
  static String locationDetail(String locationId) => '/locations/$locationId';

  // --- Hareketler ve bildirimler (şartname 19-20. bölümler) ---
  static const String movements = '/movements';

  /// Tek bir ürünün hareketleri.
  static String movementsForProduct(String productId) =>
      '/movements?productId=$productId';

  static const String notifications = '/notifications';

  // --- Raporlar (şartname 22. bölüm) ---
  static const String reports = '/reports';
}

/// Rota adları — `context.goNamed` kullanan yerler için.
abstract final class AppRouteNames {
  static const String splash = 'splash';
  static const String dashboard = 'dashboard';
  static const String stock = 'stock';
  static const String orders = 'orders';
  static const String scan = 'scan';
  static const String profile = 'profile';
  static const String products = 'products';
  static const String productDetail = 'productDetail';
  static const String receiving = 'receiving';
  static const String receiptDetail = 'receiptDetail';
  static const String putaway = 'putaway';
  static const String orderDetail = 'orderDetail';
  static const String picking = 'picking';
  static const String transfer = 'transfer';
  static const String counts = 'counts';
  static const String countDetail = 'countDetail';
  static const String shipments = 'shipments';
  static const String shipmentDetail = 'shipmentDetail';
  static const String locations = 'locations';
  static const String locationDetail = 'locationDetail';
  static const String movements = 'movements';
  static const String notifications = 'notifications';
  static const String reports = 'reports';
}
