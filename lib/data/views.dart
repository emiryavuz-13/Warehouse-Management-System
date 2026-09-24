/// Repository'lerin döndürdüğü birleşik okuma modelleri.
///
/// Ekranların çoğu tek bir model yerine birkaçının birleşimine ihtiyaç duyar:
/// ürün listesi ürünün yanında toplam stoğunu ve durumunu, hareket listesi
/// hareketin yanında ürün adını ve lokasyon kodunu ister.
///
/// Bu birleştirme **veri katmanında** yapılır. Alternatifi, ekranın ayrı ayrı
/// ürün ve stok listeleri çekip kendi içinde eşleştirmesiydi; o da iş
/// mantığını widget'ların içine taşırdı (şartname 32. bölüm).
library;

import 'package:equatable/equatable.dart';

import '../models/models.dart';

/// Bir ürünün tek bir lokasyondaki miktarı.
class LocationStock extends Equatable {
  const LocationStock({
    required this.location,
    required this.quantity,
  });

  final WarehouseLocation location;
  final int quantity;

  @override
  List<Object?> get props => <Object?>[location, quantity];
}

/// Ürün + stok bilgisinin birleşimi.
///
/// Ürün listesi, stok listesi ve tarama sonucu ekranlarının tamamı bunu
/// kullanır.
class ProductStockSummary extends Equatable {
  const ProductStockSummary({
    required this.product,
    required this.category,
    required this.totalQuantity,
    required this.locations,
  });

  final Product product;
  final ProductCategory? category;

  /// Tüm lokasyonlardaki toplam.
  final int totalQuantity;

  /// Lokasyon bazlı dağılım, miktara göre azalan sırada.
  final List<LocationStock> locations;

  /// Toplam miktar ve minimum stoka göre hesaplanan durum.
  StockStatus get status =>
      StockStatus.fromQuantity(totalQuantity, product.minStock);

  /// En çok stoğun bulunduğu lokasyon — kartlarda "ana lokasyon" olarak
  /// gösterilir (şartname 8. bölüm).
  WarehouseLocation? get primaryLocation =>
      locations.isEmpty ? null : locations.first.location;

  /// Ürün birden fazla rafta mı duruyor?
  bool get isMultiLocation => locations.length > 1;

  @override
  List<Object?> get props => <Object?>[
    product,
    category,
    totalQuantity,
    locations,
  ];
}

/// Lokasyon + doluluk bilgisinin birleşimi (şartname 18. bölüm).
class LocationSummary extends Equatable {
  const LocationSummary({
    required this.location,
    required this.zone,
    required this.usedQuantity,
    required this.skuCount,
  });

  final WarehouseLocation location;
  final Zone? zone;

  /// Lokasyondaki toplam adet.
  final int usedQuantity;

  /// Lokasyondaki farklı ürün sayısı.
  final int skuCount;

  double get occupancyRatio => location.occupancyRatio(usedQuantity);

  int get availableCapacity => location.availableCapacity(usedQuantity);

  bool get isEmpty => usedQuantity == 0;

  /// Kapasitenin %85'i dolduysa uyarı rengiyle gösterilir.
  bool get isNearlyFull => occupancyRatio >= 0.85;

  @override
  List<Object?> get props => <Object?>[location, zone, usedQuantity, skuCount];
}

/// Bir lokasyondaki tek ürün satırı — lokasyon detayında listelenir.
class LocationStockLine extends Equatable {
  const LocationStockLine({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  @override
  List<Object?> get props => <Object?>[product, quantity];
}

/// Hareket + ilişkili kayıtların birleşimi (şartname 19. bölüm).
///
/// Hareket listesi ürün adını, lokasyon kodlarını ve kullanıcı adını
/// gösterir; hepsi ayrı kayıtlarda durduğu için burada birleştirilir.
class MovementDetail extends Equatable {
  const MovementDetail({
    required this.movement,
    required this.product,
    this.sourceLocation,
    this.targetLocation,
    this.user,
  });

  final StockMovement movement;
  final Product product;
  final WarehouseLocation? sourceLocation;
  final WarehouseLocation? targetLocation;
  final AppUser? user;

  /// `A-01-01 → B-03-02` ya da tek taraflı hareketlerde tek kod.
  String? get routeLabel => movement.routeLabel(
    sourceCode: sourceLocation?.code,
    targetCode: targetLocation?.code,
  );

  @override
  List<Object?> get props => <Object?>[
    movement,
    product,
    sourceLocation,
    targetLocation,
    user,
  ];
}

/// Bir günün giriş/çıkış toplamı — dashboard grafiği için
/// (şartname 22. bölüm).
class DailyMovementPoint extends Equatable {
  const DailyMovementPoint({
    required this.day,
    required this.inbound,
    required this.outbound,
    required this.transferCount,
  });

  /// Günün başlangıcı (saat 00:00).
  final DateTime day;

  /// O gün depoya giren toplam adet.
  final int inbound;

  /// O gün depodan çıkan toplam adet (pozitif sayı olarak).
  final int outbound;

  /// O gün yapılan transfer sayısı.
  final int transferCount;

  @override
  List<Object?> get props => <Object?>[day, inbound, outbound, transferCount];
}

/// Dashboard'un özet metrikleri (şartname 7. bölüm).
class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.totalProducts,
    required this.totalStock,
    required this.criticalStockCount,
    required this.outOfStockCount,
    required this.pendingOrderCount,
    required this.pickingOrderCount,
    required this.readyToShipCount,
    required this.todayReceiptCount,
    required this.todayShipmentCount,
    required this.unreadNotificationCount,
  });

  /// Katalogdaki ürün çeşidi sayısı.
  final int totalProducts;

  /// Depodaki toplam adet.
  final int totalStock;

  /// Kritik seviyedeki ürün sayısı.
  final int criticalStockCount;

  /// Tükenen ürün sayısı.
  final int outOfStockCount;

  /// Henüz toplanmaya başlanmamış sipariş sayısı.
  final int pendingOrderCount;

  /// Toplanmakta olan sipariş sayısı.
  final int pickingOrderCount;

  /// Sevk edilmeyi bekleyen sipariş sayısı.
  final int readyToShipCount;

  /// Bugün beklenen veya yapılan mal kabul sayısı.
  final int todayReceiptCount;

  /// Bugün sevk edilen sipariş sayısı.
  final int todayShipmentCount;

  final int unreadNotificationCount;

  /// Dikkat gerektiren toplam ürün sayısı — kritik + tükenmiş.
  int get stockAlertCount => criticalStockCount + outOfStockCount;

  @override
  List<Object?> get props => <Object?>[
    totalProducts,
    totalStock,
    criticalStockCount,
    outOfStockCount,
    pendingOrderCount,
    pickingOrderCount,
    readyToShipCount,
    todayReceiptCount,
    todayShipmentCount,
    unreadNotificationCount,
  ];
}

/// Sipariş + ilişkili kayıtların birleşimi (şartname 13. bölüm).
class OrderDetail extends Equatable {
  const OrderDetail({
    required this.order,
    required this.lines,
    this.pickingTask,
    this.shipment,
  });

  final SalesOrder order;
  final List<OrderLineDetail> lines;

  /// Toplama görevi — sipariş henüz toplanmaya başlanmadıysa `null`.
  final PickingTask? pickingTask;

  /// Sevkiyat kaydı — henüz açılmadıysa `null`.
  final Shipment? shipment;

  /// Toplama başlatılabilir mi?
  bool get canStartPicking => order.status.canStartPicking;

  /// Sevkiyat ekranına geçilebilir mi?
  bool get canShip => order.status.canShip;

  @override
  List<Object?> get props => <Object?>[order, lines, pickingTask, shipment];
}

/// Sipariş satırı + ürün bilgisi.
class OrderLineDetail extends Equatable {
  const OrderLineDetail({
    required this.item,
    required this.product,
    required this.availableStock,
    this.pickLocation,
  });

  final OrderItem item;
  final Product product;

  /// Ürünün depodaki toplam stoğu — yetersizse arayüz uyarı gösterir.
  final int availableStock;

  /// Toplama görevi varsa bu satırın kaynak lokasyonu.
  final WarehouseLocation? pickLocation;

  /// İstenen miktar depoda var mı?
  bool get hasEnoughStock => availableStock >= item.remainingQuantity;

  @override
  List<Object?> get props => <Object?>[
    item,
    product,
    availableStock,
    pickLocation,
  ];
}

/// Toplama ekranının tek adımı (şartname 14. bölüm).
class PickingStep extends Equatable {
  const PickingStep({
    required this.task,
    required this.line,
    required this.product,
    required this.location,
    required this.stepNumber,
    required this.totalSteps,
    required this.availableStock,
    required this.orderNumber,
  });

  final PickingTask task;
  final PickingLine line;
  final Product product;
  final WarehouseLocation location;

  /// 1 tabanlı adım numarası — ekranda `2 / 3` olarak gösterilir.
  final int stepNumber;
  final int totalSteps;

  /// Kaynak lokasyondaki mevcut stok.
  final int availableStock;

  final String orderNumber;

  bool get hasEnoughStock => availableStock >= line.remainingQuantity;

  @override
  List<Object?> get props => <Object?>[
    task,
    line,
    product,
    location,
    stepNumber,
    totalSteps,
    availableStock,
    orderNumber,
  ];
}

/// Mal kabul + ürün bilgilerinin birleşimi (şartname 11. bölüm).
class ReceiptDetail extends Equatable {
  const ReceiptDetail({required this.receipt, required this.lines});

  final GoodsReceipt receipt;
  final List<ReceiptLineDetail> lines;

  @override
  List<Object?> get props => <Object?>[receipt, lines];
}

/// Mal kabul satırı + ürün ve hedef lokasyon.
class ReceiptLineDetail extends Equatable {
  const ReceiptLineDetail({
    required this.line,
    required this.product,
    this.targetLocation,
  });

  final GoodsReceiptLine line;
  final Product product;
  final WarehouseLocation? targetLocation;

  @override
  List<Object?> get props => <Object?>[line, product, targetLocation];
}

/// Sayım + ürün bilgilerinin birleşimi (şartname 16. bölüm).
class CountDetail extends Equatable {
  const CountDetail({
    required this.count,
    required this.location,
    required this.lines,
  });

  final InventoryCount count;
  final WarehouseLocation location;
  final List<CountLineDetail> lines;

  @override
  List<Object?> get props => <Object?>[count, location, lines];
}

/// Sayım satırı + ürün bilgisi.
class CountLineDetail extends Equatable {
  const CountLineDetail({required this.line, required this.product});

  final InventoryCountLine line;
  final Product product;

  @override
  List<Object?> get props => <Object?>[line, product];
}

/// Sevkiyat + sipariş bilgilerinin birleşimi (şartname 17. bölüm).
class ShipmentDetail extends Equatable {
  const ShipmentDetail({
    required this.shipment,
    required this.order,
    required this.lines,
  });

  final Shipment shipment;
  final SalesOrder order;
  final List<OrderLineDetail> lines;

  /// Sevk edilecek toplam adet.
  int get totalQuantity => order.totalQuantity;

  @override
  List<Object?> get props => <Object?>[shipment, order, lines];
}

/// Barkod tarama sonucu (şartname 10. bölüm).
class ScanResult extends Equatable {
  const ScanResult({required this.barcode, this.summary});

  /// Taranan ham kod.
  final String barcode;

  /// Eşleşen ürün — bulunamadıysa `null`.
  final ProductStockSummary? summary;

  bool get isFound => summary != null;

  @override
  List<Object?> get props => <Object?>[barcode, summary];
}
