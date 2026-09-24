import '../../models/models.dart';
import '../mock_config.dart';
import '../views.dart';
import '../warehouse_database.dart';

/// Ürün listesinin sıralama seçenekleri (şartname 8. bölüm).
enum ProductSort {
  nameAsc('Ada göre (A-Z)'),
  nameDesc('Ada göre (Z-A)'),
  stockDesc('Stoğu çok olan önce'),
  stockAsc('Stoğu az olan önce'),
  skuAsc('SKU koduna göre');

  const ProductSort(this.label);

  final String label;
}

/// Ürün listesine uygulanacak arama ve filtreler.
///
/// Tek bir nesne olarak taşınır; böylece yeni bir filtre eklendiğinde
/// repository imzası ve tüm çağrı yerleri değişmez.
class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.categoryId,
    this.status,
    this.locationId,
    this.sort = ProductSort.nameAsc,
  });

  /// Ürün adı, SKU, barkod veya markada aranır (şartname 31. bölüm).
  final String query;

  final String? categoryId;
  final StockStatus? status;

  /// Yalnızca bu lokasyonda stoğu bulunan ürünler.
  final String? locationId;

  final ProductSort sort;

  /// Varsayılan dışında bir filtre uygulanmış mı?
  ///
  /// Arayüz filtre butonunun üzerinde etkin filtre rozetini buna göre gösterir.
  bool get isActive =>
      categoryId != null || status != null || locationId != null;

  /// Etkin filtre sayısı — rozetteki rakam.
  int get activeCount => <Object?>[
    categoryId,
    status,
    locationId,
  ].where((Object? e) => e != null).length;

  ProductFilter copyWith({
    String? query,
    String? categoryId,
    StockStatus? status,
    String? locationId,
    ProductSort? sort,
    bool clearCategory = false,
    bool clearStatus = false,
    bool clearLocation = false,
  }) {
    return ProductFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      status: clearStatus ? null : (status ?? this.status),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
      sort: sort ?? this.sort,
    );
  }

  /// Tüm filtreleri temizler, aramayı korur.
  ProductFilter cleared() => ProductFilter(query: query, sort: sort);
}

/// Ürün ve kategori okuma işlemleri.
///
/// Şartname 36. bölüm: gerçek API'ye geçildiğinde bu arayüzün yeni bir
/// implementasyonu yazılır, UI hiç değişmez.
abstract interface class ProductRepository {
  Future<List<ProductStockSummary>> getProducts([ProductFilter filter]);

  Future<ProductStockSummary?> getProductById(String id);

  /// Barkoda göre ürün arar (şartname 10. bölüm).
  Future<Product?> getProductByBarcode(String barcode);

  /// Barkod tarama sonucunu stok bilgisiyle birlikte döner.
  Future<ScanResult> scanBarcode(String barcode);

  Future<List<ProductCategory>> getCategories();

  /// Kritik seviyedeki ve tükenmiş ürünler (şartname 7. bölüm).
  Future<List<ProductStockSummary>> getCriticalProducts({int? limit});
}

/// [ProductRepository]'nin mock veriyle çalışan implementasyonu.
class MockProductRepository implements ProductRepository {
  MockProductRepository(this._db, this._config);

  final WarehouseDatabase _db;
  final MockConfig _config;

  @override
  Future<List<ProductStockSummary>> getProducts([
    ProductFilter filter = const ProductFilter(),
  ]) async {
    await _config.beforeRead(long: true);

    final String query = filter.query.trim().toLowerCase();

    List<ProductStockSummary> result = _db.products
        .map(_summarize)
        .where((ProductStockSummary s) {
          if (query.isNotEmpty && !s.product.searchText.contains(query)) {
            return false;
          }
          if (filter.categoryId != null &&
              s.product.categoryId != filter.categoryId) {
            return false;
          }
          if (filter.status != null && s.status != filter.status) {
            return false;
          }
          if (filter.locationId != null) {
            final bool atLocation = s.locations.any(
              (LocationStock l) => l.location.id == filter.locationId,
            );
            if (!atLocation) return false;
          }
          return true;
        })
        .toList();

    result = _sorted(result, filter.sort);
    return result;
  }

  @override
  Future<ProductStockSummary?> getProductById(String id) async {
    await _config.beforeRead();
    final Product? product = _db.productById(id);
    return product == null ? null : _summarize(product);
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    await _config.beforeRead();
    return _db.productByBarcode(barcode);
  }

  @override
  Future<ScanResult> scanBarcode(String barcode) async {
    await _config.beforeRead();
    // Tarayıcı hem barkodu hem SKU'yu kabul eder; depoda etiketi yıpranmış
    // ürünün SKU'su elle girilebilsin diye.
    final Product? product = _db.productByCode(barcode);
    return ScanResult(
      barcode: barcode.trim(),
      summary: product == null ? null : _summarize(product),
    );
  }

  @override
  Future<List<ProductCategory>> getCategories() async {
    await _config.beforeRead();
    return _db.categories;
  }

  @override
  Future<List<ProductStockSummary>> getCriticalProducts({int? limit}) async {
    await _config.beforeRead();

    final List<ProductStockSummary> result = _db
        .criticalProducts()
        .map(_summarize)
        .toList();

    // Tükenenler en üstte, sonra stoğu en aza yakın olanlar.
    result.sort((ProductStockSummary a, ProductStockSummary b) {
      if (a.status != b.status) {
        return a.status == StockStatus.outOfStock ? -1 : 1;
      }
      return a.totalQuantity.compareTo(b.totalQuantity);
    });

    if (limit != null && result.length > limit) {
      return result.sublist(0, limit);
    }
    return result;
  }

  /// Ürünü stok bilgisiyle birleştirir.
  ///
  /// Lokasyonlar miktara göre azalan sıralanır; böylece [primaryLocation]
  /// her zaman en çok stoğun bulunduğu raf olur.
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

  static List<ProductStockSummary> _sorted(
    List<ProductStockSummary> items,
    ProductSort sort,
  ) {
    final List<ProductStockSummary> copy = List<ProductStockSummary>.of(items);

    switch (sort) {
      case ProductSort.nameAsc:
        copy.sort(
          (ProductStockSummary a, ProductStockSummary b) =>
              a.product.name.toLowerCase().compareTo(
                b.product.name.toLowerCase(),
              ),
        );
      case ProductSort.nameDesc:
        copy.sort(
          (ProductStockSummary a, ProductStockSummary b) =>
              b.product.name.toLowerCase().compareTo(
                a.product.name.toLowerCase(),
              ),
        );
      case ProductSort.stockDesc:
        copy.sort(
          (ProductStockSummary a, ProductStockSummary b) =>
              b.totalQuantity.compareTo(a.totalQuantity),
        );
      case ProductSort.stockAsc:
        copy.sort(
          (ProductStockSummary a, ProductStockSummary b) =>
              a.totalQuantity.compareTo(b.totalQuantity),
        );
      case ProductSort.skuAsc:
        copy.sort(
          (ProductStockSummary a, ProductStockSummary b) =>
              a.product.sku.compareTo(b.product.sku),
        );
    }

    return copy;
  }
}
