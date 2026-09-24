import '../../models/models.dart';
import '../mock_config.dart';
import '../views.dart';
import '../warehouse_database.dart';

/// Depo, bölge ve lokasyon okuma işlemleri (şartname 18. bölüm).
abstract interface class WarehouseRepository {
  Future<List<Warehouse>> getWarehouses();

  Future<List<Zone>> getZones({String? warehouseId});

  /// Lokasyonları doluluk bilgisiyle birlikte döner.
  Future<List<LocationSummary>> getLocations({
    String? warehouseId,
    String? zoneId,
    String query,
  });

  Future<LocationSummary?> getLocationById(String locationId);

  /// Bir lokasyondaki ürünler ve miktarları.
  Future<List<LocationStockLine>> getLocationContents(String locationId);

  /// Bir ürünü yerleştirmek için uygun lokasyonlar.
  ///
  /// Kapasitesi yetmeyen lokasyonlar listelenir ama işaretlenir; kullanıcı
  /// neden seçemediğini görmeli (şartname 12. bölüm).
  Future<List<LocationSummary>> getPutawayCandidates({
    String? warehouseId,
    String? excludeLocationId,
  });

  /// Oturum açmış kullanıcı (şartname 21. bölüm).
  Future<AppUser> getCurrentUser();

  // --- Bildirimler (şartname 20. bölüm) ---

  Future<List<AppNotification>> getNotifications();

  Future<int> getUnreadNotificationCount();

  Future<void> markNotificationRead(String id);

  Future<void> markAllNotificationsRead();
}

/// [WarehouseRepository]'nin mock veriyle çalışan implementasyonu.
class MockWarehouseRepository implements WarehouseRepository {
  MockWarehouseRepository(this._db, this._config, this._currentUserId);

  final WarehouseDatabase _db;
  final MockConfig _config;
  final String _currentUserId;

  @override
  Future<List<Warehouse>> getWarehouses() async {
    await _config.beforeRead();
    return _db.warehouses;
  }

  @override
  Future<List<Zone>> getZones({String? warehouseId}) async {
    await _config.beforeRead();
    if (warehouseId == null) return _db.zones;
    return _db.zones.where((Zone z) => z.warehouseId == warehouseId).toList();
  }

  @override
  Future<List<LocationSummary>> getLocations({
    String? warehouseId,
    String? zoneId,
    String query = '',
  }) async {
    await _config.beforeRead();

    final String trimmed = query.trim().toLowerCase();

    final List<LocationSummary> result = _db.locations
        .where((WarehouseLocation l) {
          if (warehouseId != null && l.warehouseId != warehouseId) return false;
          if (zoneId != null && l.zoneId != zoneId) return false;
          if (trimmed.isNotEmpty &&
              !l.code.toLowerCase().contains(trimmed)) {
            return false;
          }
          return true;
        })
        .map(_summarize)
        .toList();

    // Lokasyon kodları doğal sırada okunur: A-01-01, A-01-02, A-02-01...
    result.sort(
      (LocationSummary a, LocationSummary b) =>
          a.location.code.compareTo(b.location.code),
    );

    return result;
  }

  @override
  Future<LocationSummary?> getLocationById(String locationId) async {
    await _config.beforeRead();
    final WarehouseLocation? location = _db.locationById(locationId);
    return location == null ? null : _summarize(location);
  }

  @override
  Future<List<LocationStockLine>> getLocationContents(
    String locationId,
  ) async {
    await _config.beforeRead();

    final List<LocationStockLine> lines = <LocationStockLine>[];
    for (final Stock stock in _db.stocksAtLocation(
      locationId,
      includeEmpty: true,
    )) {
      final Product? product = _db.productById(stock.productId);
      if (product == null) continue;
      lines.add(
        LocationStockLine(product: product, quantity: stock.quantity),
      );
    }

    lines.sort(
      (LocationStockLine a, LocationStockLine b) =>
          b.quantity.compareTo(a.quantity),
    );

    return lines;
  }

  @override
  Future<List<LocationSummary>> getPutawayCandidates({
    String? warehouseId,
    String? excludeLocationId,
  }) async {
    await _config.beforeRead();

    final List<LocationSummary> result = _db.locations
        .where((WarehouseLocation l) {
          if (l.id == excludeLocationId) return false;
          if (warehouseId != null && l.warehouseId != warehouseId) return false;
          // Mal kabul alanı hedef olamaz: ürün oradan rafa kaldırılır.
          return l.type != LocationType.receiving;
        })
        .map(_summarize)
        .toList();

    // Boş yeri çok olan lokasyon önce önerilir.
    result.sort(
      (LocationSummary a, LocationSummary b) =>
          b.availableCapacity.compareTo(a.availableCapacity),
    );

    return result;
  }

  @override
  Future<AppUser> getCurrentUser() async {
    await _config.beforeRead();
    final AppUser? user = _db.userById(_currentUserId);
    if (user != null) return user;
    // Kullanıcı bulunamazsa ilk kullanıcıya düşülür; demo hiçbir koşulda
    // kullanıcısız kalmamalı.
    return _db.users.first;
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    await _config.beforeRead();

    final List<AppNotification> items = List<AppNotification>.of(
      _db.notifications,
    );
    items.sort(
      (AppNotification a, AppNotification b) =>
          b.createdAt.compareTo(a.createdAt),
    );

    return items;
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    // Rozet sayısı gecikmeden okunur: her ekran açılışında bekletmek anlamsız.
    return _db.unreadNotificationCount;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    _db.markNotificationRead(id);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    _db.markAllNotificationsRead();
  }

  LocationSummary _summarize(WarehouseLocation location) {
    final List<Stock> stocks = _db.stocksAtLocation(location.id);

    return LocationSummary(
      location: location,
      zone: _db.zoneById(location.zoneId),
      usedQuantity: stocks.fold<int>(0, (int sum, Stock s) => sum + s.quantity),
      skuCount: stocks.length,
    );
  }
}
