import '../../models/models.dart';
import 'mock_categories.dart';
import 'mock_counts.dart';
import 'mock_locations.dart';
import 'mock_movements.dart';
import 'mock_notifications.dart';
import 'mock_orders.dart';
import 'mock_picking.dart';
import 'mock_products.dart';
import 'mock_receipts.dart';
import 'mock_shipments.dart';
import 'mock_stocks.dart';
import 'mock_users.dart';
import 'mock_warehouses.dart';

export 'mock_users.dart' show MockUsers;
export 'mock_warehouses.dart' show MockWarehouses;

/// Uygulamanın başlangıç verisinin tamamı.
///
/// [MockDataset.seed] çağrıldığında tüm listeler bir arada üretilir ve
/// `WarehouseDatabase` bunları kendi değiştirilebilir kopyalarına alır.
/// Böylece demo sırasında yapılan transferler, sayımlar ve toplamalar
/// başlangıç verisini bozmaz — uygulama yeniden başlatıldığında temiz
/// senaryoya dönülür.
class MockDataset {
  const MockDataset({
    required this.products,
    required this.categories,
    required this.warehouses,
    required this.zones,
    required this.locations,
    required this.stocks,
    required this.orders,
    required this.pickingTasks,
    required this.goodsReceipts,
    required this.shipments,
    required this.inventoryCounts,
    required this.movements,
    required this.notifications,
    required this.users,
  });

  final List<Product> products;
  final List<ProductCategory> categories;
  final List<Warehouse> warehouses;
  final List<Zone> zones;
  final List<WarehouseLocation> locations;
  final List<Stock> stocks;
  final List<SalesOrder> orders;
  final List<PickingTask> pickingTasks;
  final List<GoodsReceipt> goodsReceipts;
  final List<Shipment> shipments;
  final List<InventoryCount> inventoryCounts;
  final List<StockMovement> movements;
  final List<AppNotification> notifications;
  final List<AppUser> users;

  /// Başlangıç verisini üretir.
  ///
  /// [now] verilmezse geçerli zaman kullanılır. Tarihler bu ana **göreli**
  /// hesaplandığı için uygulama ne zaman açılırsa açılsın veriler tazedir:
  /// dashboard "bugünkü" hareketleri, "3 saat önce" gelen bildirimleri
  /// gösterir. Testlerde ise sabit bir [now] geçilerek sonuçlar
  /// belirlenebilir hale getirilir.
  factory MockDataset.seed({DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();

    return MockDataset(
      products: List<Product>.of(MockProducts.all),
      categories: List<ProductCategory>.of(MockCategories.all),
      warehouses: List<Warehouse>.of(MockWarehouses.all),
      zones: List<Zone>.of(MockWarehouses.allZones),
      locations: List<WarehouseLocation>.of(MockLocations.all),
      stocks: List<Stock>.of(MockStocks.all),
      orders: MockOrders.build(reference),
      pickingTasks: MockPickingTasks.build(reference),
      goodsReceipts: MockGoodsReceipts.build(reference),
      shipments: MockShipments.build(reference),
      inventoryCounts: MockInventoryCounts.build(reference),
      movements: MockMovements.build(reference),
      notifications: MockNotifications.build(reference),
      users: MockUsers.build(reference),
    );
  }
}
