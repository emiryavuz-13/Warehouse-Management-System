import '../../core/constants/app_constants.dart';
import '../../models/models.dart';
import '../mock_config.dart';
import '../views.dart';
import '../warehouse_database.dart';

/// Hareket listesine uygulanacak arama ve filtreler (şartname 19. bölüm).
class MovementFilter {
  const MovementFilter({
    this.query = '',
    this.types = const <MovementType>{},
    this.productId,
    this.locationId,
  });

  /// Ürün adı, SKU veya referans metninde aranır.
  final String query;

  /// Boşsa tüm türler gösterilir.
  final Set<MovementType> types;

  final String? productId;
  final String? locationId;

  bool get isActive =>
      types.isNotEmpty || productId != null || locationId != null;

  MovementFilter copyWith({
    String? query,
    Set<MovementType>? types,
    String? productId,
    String? locationId,
    bool clearProduct = false,
    bool clearLocation = false,
  }) {
    return MovementFilter(
      query: query ?? this.query,
      types: types ?? this.types,
      productId: clearProduct ? null : (productId ?? this.productId),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
    );
  }
}

/// Stok hareketleri ve raporlama (şartname 19 ve 22. bölümler).
abstract interface class MovementRepository {
  /// Hareketleri yeniden eskiye döner.
  Future<List<MovementDetail>> getStockMovements([MovementFilter filter]);

  /// Bir ürünün son hareketleri — ürün detayında gösterilir.
  Future<List<MovementDetail>> getMovementsForProduct(
    String productId, {
    int? limit,
  });

  /// Dashboard'un son hareketler bölümü.
  Future<List<MovementDetail>> getRecentMovements({int limit});

  /// Dashboard özet metrikleri (şartname 7. bölüm).
  Future<DashboardSummary> getDashboardSummary();

  /// Son N günün günlük giriş/çıkış toplamları (şartname 22. bölüm).
  Future<List<DailyMovementPoint>> getDailyMovements({int days});
}

/// [MovementRepository]'nin mock veriyle çalışan implementasyonu.
class MockMovementRepository implements MovementRepository {
  MockMovementRepository(this._db, this._config);

  final WarehouseDatabase _db;
  final MockConfig _config;

  @override
  Future<List<MovementDetail>> getStockMovements([
    MovementFilter filter = const MovementFilter(),
  ]) async {
    await _config.beforeRead(long: true);

    final String query = filter.query.trim().toLowerCase();

    final List<MovementDetail> result = <MovementDetail>[];
    for (final StockMovement movement in _db.movements) {
      if (filter.types.isNotEmpty && !filter.types.contains(movement.type)) {
        continue;
      }
      if (filter.productId != null && movement.productId != filter.productId) {
        continue;
      }
      if (filter.locationId != null &&
          movement.sourceLocationId != filter.locationId &&
          movement.targetLocationId != filter.locationId) {
        continue;
      }

      final MovementDetail? detail = _detail(movement);
      if (detail == null) continue;

      if (query.isNotEmpty) {
        final String haystack =
            '${detail.product.name} ${detail.product.sku} '
                    '${movement.reference} ${detail.routeLabel ?? ''}'
                .toLowerCase();
        if (!haystack.contains(query)) continue;
      }

      result.add(detail);
    }

    // Veritabanı listesi zaten yeniden eskiye sıralı; yine de garanti altına
    // alınır, çünkü sıralama hareket listesinin gün başlıklarını belirler.
    result.sort(
      (MovementDetail a, MovementDetail b) =>
          b.movement.timestamp.compareTo(a.movement.timestamp),
    );

    return result;
  }

  @override
  Future<List<MovementDetail>> getMovementsForProduct(
    String productId, {
    int? limit,
  }) async {
    await _config.beforeRead();

    final List<MovementDetail> result = _db
        .movementsOfProduct(productId, limit: limit)
        .map(_detail)
        .whereType<MovementDetail>()
        .toList();

    return result;
  }

  @override
  Future<List<MovementDetail>> getRecentMovements({
    int limit = AppConstants.dashboardRecentMovementCount,
  }) async {
    await _config.beforeRead();

    final List<MovementDetail> result = <MovementDetail>[];
    for (final StockMovement movement in _db.movements) {
      final MovementDetail? detail = _detail(movement);
      if (detail != null) result.add(detail);
      if (result.length >= limit) break;
    }

    return result;
  }

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    await _config.beforeRead();

    final DateTime startOfToday = _startOfToday();

    int critical = 0;
    int outOfStock = 0;
    for (final Product product in _db.products) {
      switch (_db.statusOf(product.id)) {
        case StockStatus.critical:
          critical++;
        case StockStatus.outOfStock:
          outOfStock++;
        case StockStatus.normal:
          break;
      }
    }

    int pending = 0;
    int picking = 0;
    int readyToShip = 0;
    int shippedToday = 0;
    for (final SalesOrder order in _db.orders) {
      switch (order.status) {
        case OrderStatus.newOrder:
          pending++;
        case OrderStatus.picking:
          picking++;
        case OrderStatus.picked:
        case OrderStatus.ready:
          readyToShip++;
        case OrderStatus.shipped:
          final DateTime? shippedAt = order.shippedAt;
          if (shippedAt != null && !shippedAt.isBefore(startOfToday)) {
            shippedToday++;
          }
        case OrderStatus.cancelled:
          break;
      }
    }

    // Bugün beklenen veya bugün tamamlanan mal kabuller.
    final int todayReceipts = _db.goodsReceipts.where((GoodsReceipt r) {
      final DateTime? completedAt = r.completedAt;
      if (completedAt != null && !completedAt.isBefore(startOfToday)) {
        return true;
      }
      return _isSameDay(r.expectedDate, startOfToday) && !r.status.isCompleted;
    }).length;

    return DashboardSummary(
      totalProducts: _db.products.length,
      totalStock: _db.stocks.fold<int>(
        0,
        (int sum, Stock s) => sum + s.quantity,
      ),
      criticalStockCount: critical,
      outOfStockCount: outOfStock,
      pendingOrderCount: pending,
      pickingOrderCount: picking,
      readyToShipCount: readyToShip,
      todayReceiptCount: todayReceipts,
      todayShipmentCount: shippedToday,
      unreadNotificationCount: _db.unreadNotificationCount,
    );
  }

  @override
  Future<List<DailyMovementPoint>> getDailyMovements({
    int days = AppConstants.reportDayRange,
  }) async {
    await _config.beforeRead();

    final DateTime startOfToday = _startOfToday();

    // Günler önceden sıfırla doldurulur; hareketsiz gün grafikte boşluk
    // değil, sıfır değerli bir sütun olarak görünmeli.
    final List<DateTime> buckets = <DateTime>[
      for (int i = days - 1; i >= 0; i--)
        startOfToday.subtract(Duration(days: i)),
    ];

    final Map<DateTime, int> inbound = <DateTime, int>{
      for (final DateTime d in buckets) d: 0,
    };
    final Map<DateTime, int> outbound = <DateTime, int>{
      for (final DateTime d in buckets) d: 0,
    };
    final Map<DateTime, int> transfers = <DateTime, int>{
      for (final DateTime d in buckets) d: 0,
    };

    final DateTime windowStart = buckets.first;

    for (final StockMovement movement in _db.movements) {
      if (movement.timestamp.isBefore(windowStart)) continue;

      final DateTime day = DateTime(
        movement.timestamp.year,
        movement.timestamp.month,
        movement.timestamp.day,
      );
      if (!inbound.containsKey(day)) continue;

      if (movement.type == MovementType.transfer) {
        transfers[day] = transfers[day]! + 1;
        continue;
      }

      final int effect = movement.netEffect;
      if (effect > 0) {
        inbound[day] = inbound[day]! + effect;
      } else if (effect < 0) {
        outbound[day] = outbound[day]! + effect.abs();
      }
    }

    return <DailyMovementPoint>[
      for (final DateTime day in buckets)
        DailyMovementPoint(
          day: day,
          inbound: inbound[day]!,
          outbound: outbound[day]!,
          transferCount: transfers[day]!,
        ),
    ];
  }

  /// Hareketi ürün, lokasyon ve kullanıcı bilgileriyle birleştirir.
  ///
  /// Ürün bulunamazsa `null` döner ve hareket listelenmez; bozuk bir kayıt
  /// yüzünden tüm liste çökmemeli.
  MovementDetail? _detail(StockMovement movement) {
    final Product? product = _db.productById(movement.productId);
    if (product == null) return null;

    final String? source = movement.sourceLocationId;
    final String? target = movement.targetLocationId;

    return MovementDetail(
      movement: movement,
      product: product,
      sourceLocation: source == null ? null : _db.locationById(source),
      targetLocation: target == null ? null : _db.locationById(target),
      user: _db.userById(movement.userId),
    );
  }

  DateTime _startOfToday() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
