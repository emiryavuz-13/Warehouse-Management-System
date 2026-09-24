import '../../models/models.dart';
import '../mock_config.dart';
import '../views.dart';
import '../warehouse_database.dart';

/// Stok listesine uygulanacak arama ve filtreler (şartname 9. bölüm).
class StockFilter {
  const StockFilter({this.query = '', this.status, this.locationId});

  final String query;
  final StockStatus? status;
  final String? locationId;

  bool get isActive => status != null || locationId != null;

  StockFilter copyWith({
    String? query,
    StockStatus? status,
    String? locationId,
    bool clearStatus = false,
    bool clearLocation = false,
  }) {
    return StockFilter(
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
    );
  }
}

/// Stok görüntüleme ve stok değiştiren operasyonlar.
///
/// Transfer ve sayım burada yer alır; ikisi de doğrudan stoku değiştirir.
abstract interface class StockRepository {
  /// Operasyonel stok listesi (şartname 9. bölüm).
  Future<List<ProductStockSummary>> getStocks([StockFilter filter]);

  /// Bir ürünün lokasyon bazlı stok dökümü.
  Future<ProductStockSummary?> getStockByProduct(String productId);

  /// Toplam depo stoğu — dashboard metriği.
  Future<int> getTotalStock();

  // --- Transfer (şartname 15. bölüm) ---

  /// Lokasyonlar arası stok transferi yapar.
  ///
  /// Kural ihlalinde `WarehouseException` fırlatır: yetersiz stok, aynı
  /// lokasyon, geçersiz miktar veya kapasite aşımı.
  Future<StockMovement> transferStock({
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String userId,
  });

  // --- Sayım (şartname 16. bölüm) ---

  Future<List<InventoryCount>> getInventoryCounts();

  Future<CountDetail?> getCountDetail(String countId);

  /// Bir satıra fiziksel sayım miktarı girer. Stok henüz değişmez.
  Future<CountDetail> recordCount({
    required String countId,
    required String productId,
    required int countedQuantity,
  });

  /// Sayımı onaylar; farklar stoka uygulanır ve düzeltme hareketleri oluşur.
  Future<CountDetail> completeCount({
    required String countId,
    required String userId,
  });
}

/// [StockRepository]'nin mock veriyle çalışan implementasyonu.
class MockStockRepository implements StockRepository {
  MockStockRepository(this._db, this._config);

  final WarehouseDatabase _db;
  final MockConfig _config;

  @override
  Future<List<ProductStockSummary>> getStocks([
    StockFilter filter = const StockFilter(),
  ]) async {
    await _config.beforeRead(long: true);

    final String query = filter.query.trim().toLowerCase();

    final List<ProductStockSummary> result = _db.products
        .map(_summarize)
        .where((ProductStockSummary s) {
          if (query.isNotEmpty && !s.product.searchText.contains(query)) {
            return false;
          }
          if (filter.status != null && s.status != filter.status) return false;
          if (filter.locationId != null) {
            final bool atLocation = s.locations.any(
              (LocationStock l) => l.location.id == filter.locationId,
            );
            if (!atLocation) return false;
          }
          return true;
        })
        .toList();

    // Operasyonel öncelik: önce sorunlu stoklar, sonra ada göre.
    result.sort((ProductStockSummary a, ProductStockSummary b) {
      final int byStatus = _statusRank(
        a.status,
      ).compareTo(_statusRank(b.status));
      if (byStatus != 0) return byStatus;
      return a.product.name.toLowerCase().compareTo(
        b.product.name.toLowerCase(),
      );
    });

    return result;
  }

  @override
  Future<ProductStockSummary?> getStockByProduct(String productId) async {
    await _config.beforeRead();
    final Product? product = _db.productById(productId);
    return product == null ? null : _summarize(product);
  }

  @override
  Future<int> getTotalStock() async {
    await _config.beforeRead();
    return _db.stocks.fold<int>(0, (int sum, Stock s) => sum + s.quantity);
  }

  @override
  Future<StockMovement> transferStock({
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String userId,
  }) async {
    await _config.beforeWrite();
    return _db.transferStock(
      productId: productId,
      sourceLocationId: sourceLocationId,
      targetLocationId: targetLocationId,
      quantity: quantity,
      userId: userId,
    );
  }

  @override
  Future<List<InventoryCount>> getInventoryCounts() async {
    await _config.beforeRead();

    final List<InventoryCount> counts = List<InventoryCount>.of(
      _db.inventoryCounts,
    );
    // Açık sayımlar üstte, tamamlananlar altta; her grup yeniden eskiye.
    counts.sort((InventoryCount a, InventoryCount b) {
      if (a.status.isCompleted != b.status.isCompleted) {
        return a.status.isCompleted ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return counts;
  }

  @override
  Future<CountDetail?> getCountDetail(String countId) async {
    await _config.beforeRead();
    return _buildCountDetail(countId);
  }

  @override
  Future<CountDetail> recordCount({
    required String countId,
    required String productId,
    required int countedQuantity,
  }) async {
    // Sayım girişi hızlı olmalı: kullanıcı arka arkaya birkaç satır girer,
    // her birinde yarım saniye beklemek akışı bozar.
    _db.recordCount(
      countId: countId,
      productId: productId,
      countedQuantity: countedQuantity,
    );
    return _buildCountDetail(countId)!;
  }

  @override
  Future<CountDetail> completeCount({
    required String countId,
    required String userId,
  }) async {
    await _config.beforeWrite();
    _db.completeCount(countId: countId, userId: userId);
    return _buildCountDetail(countId)!;
  }

  CountDetail? _buildCountDetail(String countId) {
    final InventoryCount? count = _db.countById(countId);
    if (count == null) return null;

    final WarehouseLocation? location = _db.locationById(count.locationId);
    if (location == null) return null;

    final List<CountLineDetail> lines = <CountLineDetail>[];
    for (final InventoryCountLine line in count.lines) {
      final Product? product = _db.productById(line.productId);
      if (product == null) continue;
      lines.add(CountLineDetail(line: line, product: product));
    }

    return CountDetail(count: count, location: location, lines: lines);
  }

  ProductStockSummary _summarize(Product product) {
    final List<LocationStock> locations = <LocationStock>[];

    for (final Stock stock in _db.stocksOfProduct(product.id)) {
      final WarehouseLocation? location = _db.locationById(stock.locationId);
      if (location == null) continue;
      locations.add(
        LocationStock(location: location, quantity: stock.quantity),
      );
    }

    locations.sort(
      (LocationStock a, LocationStock b) => b.quantity.compareTo(a.quantity),
    );

    return ProductStockSummary(
      product: product,
      category: _db.categoryById(product.categoryId),
      totalQuantity: _db.totalStockOf(product.id),
      locations: locations,
    );
  }

  /// Sıralama önceliği: tükenmiş → kritik → normal.
  static int _statusRank(StockStatus status) => switch (status) {
    StockStatus.outOfStock => 0,
    StockStatus.critical => 1,
    StockStatus.normal => 2,
  };
}
