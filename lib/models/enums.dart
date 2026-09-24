/// Uygulamadaki tüm operasyonel durumlar.
///
/// Model katmanı bilinçli olarak Flutter'dan bağımsızdır: burada renk değil
/// [StatusTone] tutulur. Rengi tema katmanı seçer (`status_tone_colors.dart`).
/// Böylece aynı durum açık ve koyu temada doğru kontrastı alır, iş mantığı
/// ise UI'dan tamamen ayrık kalır.
library;

/// Bir durumun görsel tonu. Tema bunu somut renge çevirir.
enum StatusTone {
  /// Her şey yolunda: normal stok, tamamlanmış iş.
  success,

  /// Dikkat: kritik stok, bekleyen iş, sayım farkı.
  warning,

  /// Sorun: stok yok, iptal, yetersiz miktar.
  danger,

  /// Süreç devam ediyor: toplanıyor, kabul ediliyor.
  info,

  /// Lokasyonlar arası hareket.
  transfer,

  /// Pasif / bilgi amaçlı.
  neutral,
}

/// Bir ürünün bir lokasyondaki ya da toplamdaki stok durumu.
///
/// Şartname 26. bölüm: durum, miktarın minimum stok değeriyle
/// karşılaştırılmasından türetilir — elle atanmaz.
enum StockStatus {
  normal('Normal', StatusTone.success),
  critical('Kritik', StatusTone.warning),
  outOfStock('Stok Yok', StatusTone.danger);

  const StockStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  /// Miktar ve minimum stok değerinden durumu hesaplar.
  ///
  /// - 0 ve altı → Stok Yok
  /// - minimum stok seviyesinde veya altında → Kritik
  /// - diğer → Normal
  static StockStatus fromQuantity(int quantity, int minStock) {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= minStock) return StockStatus.critical;
    return StockStatus.normal;
  }
}

/// Sipariş yaşam döngüsü (şartname 13. bölüm).
///
/// Sıra: yeni → toplanıyor → toplandı → hazır → sevk edildi.
/// [cancelled] her aşamadan sonra gelebilir.
enum OrderStatus {
  newOrder('Yeni', StatusTone.info),
  picking('Toplanıyor', StatusTone.warning),
  picked('Toplandı', StatusTone.success),
  ready('Hazır', StatusTone.success),
  shipped('Sevk Edildi', StatusTone.neutral),
  cancelled('İptal', StatusTone.danger);

  const OrderStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  /// Bu siparişten yeni bir toplama görevi başlatılabilir mi?
  bool get canStartPicking =>
      this == OrderStatus.newOrder || this == OrderStatus.picking;

  /// Sevkiyata hazır mı? (şartname 26: picking tamamlanmadan sevk edilemez)
  bool get canShip => this == OrderStatus.picked || this == OrderStatus.ready;

  /// İşlem yapılamaz son durumlar.
  bool get isClosed =>
      this == OrderStatus.shipped || this == OrderStatus.cancelled;
}

/// Siparişin aciliyeti. Liste filtrelerinde kullanılır.
enum OrderPriority {
  low('Düşük', StatusTone.neutral),
  normal('Normal', StatusTone.info),
  high('Yüksek', StatusTone.warning),
  urgent('Acil', StatusTone.danger);

  const OrderPriority(this.label, this.tone);

  final String label;
  final StatusTone tone;
}

/// Stok hareketinin türü (şartname 19. bölüm).
enum MovementType {
  goodsReceipt('Mal Kabul', StatusTone.success, MovementDirection.inbound),
  putaway('Yerleştirme', StatusTone.info, MovementDirection.internal),
  pick('Sipariş Çıkışı', StatusTone.warning, MovementDirection.outbound),
  transfer('Transfer', StatusTone.transfer, MovementDirection.internal),
  countAdjustment(
    'Sayım Düzeltmesi',
    StatusTone.info,
    MovementDirection.adjustment,
  ),
  shipment('Sevkiyat', StatusTone.neutral, MovementDirection.outbound),
  returned('İade', StatusTone.success, MovementDirection.inbound);

  const MovementType(this.label, this.tone, this.direction);

  final String label;
  final StatusTone tone;
  final MovementDirection direction;
}

/// Hareketin stok üzerindeki net etkisi.
///
/// Raporlamada "7 günlük giriş / çıkış" grafikleri bu ayrıma dayanır.
enum MovementDirection {
  /// Depoya giriş — toplam stok artar.
  inbound,

  /// Depodan çıkış — toplam stok azalır.
  outbound,

  /// Depo içi taşıma — toplam stok değişmez, lokasyon değişir.
  internal,

  /// Sayım düzeltmesi — artı ya da eksi olabilir.
  adjustment,
}

/// Mal kabul kaydının durumu (şartname 11. bölüm).
enum ReceiptStatus {
  pending('Bekliyor', StatusTone.info),
  receiving('Kabul Ediliyor', StatusTone.warning),
  completed('Tamamlandı', StatusTone.success);

  const ReceiptStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  bool get isCompleted => this == ReceiptStatus.completed;
}

/// Toplama görevinin durumu (şartname 14. bölüm).
enum PickingStatus {
  pending('Bekliyor', StatusTone.info),
  inProgress('Devam Ediyor', StatusTone.warning),
  completed('Tamamlandı', StatusTone.success);

  const PickingStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  bool get isCompleted => this == PickingStatus.completed;
}

/// Sayım kaydının durumu (şartname 16. bölüm).
enum CountStatus {
  pending('Bekliyor', StatusTone.info),
  inProgress('Devam Ediyor', StatusTone.warning),
  completed('Tamamlandı', StatusTone.success);

  const CountStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  bool get isCompleted => this == CountStatus.completed;
}

/// Sevkiyat durumu (şartname 17. bölüm).
enum ShipmentStatus {
  preparing('Hazırlanıyor', StatusTone.warning),
  ready('Sevke Hazır', StatusTone.info),
  shipped('Sevk Edildi', StatusTone.success),
  delivered('Teslim Edildi', StatusTone.neutral);

  const ShipmentStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  /// Şartname 26: sevk edilen sipariş yeniden sevk edilemez.
  bool get isShipped =>
      this == ShipmentStatus.shipped || this == ShipmentStatus.delivered;
}

/// Depo lokasyonunun işlevi (şartname 18. bölüm).
enum LocationType {
  storage('Raf'),
  receiving('Mal Kabul Alanı'),
  shipping('Sevkiyat Alanı'),
  quarantine('Karantina');

  const LocationType(this.label);

  final String label;
}

/// Kullanıcı rolü (şartname 21. bölüm).
enum UserRole {
  admin('Admin'),
  supervisor('Depo Sorumlusu'),
  operator('Depo Personeli');

  const UserRole(this.label);

  final String label;
}

/// Bildirim kategorisi (şartname 20. bölüm).
enum NotificationType {
  criticalStock('Kritik Stok', StatusTone.warning),
  newTask('Yeni Görev', StatusTone.info),
  goodsReceipt('Mal Kabul', StatusTone.success),
  inventoryCount('Sayım', StatusTone.info),
  shipment('Sevkiyat', StatusTone.neutral);

  const NotificationType(this.label, this.tone);

  final String label;
  final StatusTone tone;
}
