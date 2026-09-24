import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/core/constants/app_constants.dart';
import 'package:warehouse_management_system/data/mock/mock_data.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Mock verinin iç tutarlılığını doğrular.
///
/// Şartname 23. bölüm mock verinin "rastgele bağımsız listeler" olmamasını,
/// birbiriyle ilişkili olmasını şart koşuyor. Bu dosya o ilişkiyi makineye
/// doğrulatır: var olmayan bir ürüne referans veren sipariş, kapasitesi aşılan
/// bir raf veya stoğu yetmeyen bir toplama satırı buradan geçemez.
///
/// Böyle bir testin olmaması, bu tür hataların ancak demo ortasında —
/// sunum sırasında — ortaya çıkması demektir.
void main() {
  // Sabit referans zaman: testler makinenin saatinden bağımsız çalışsın.
  final DateTime now = DateTime(2026, 9, 24, 14, 30);
  final MockDataset data = MockDataset.seed(now: now);

  // Hızlı arama için kimlik kümeleri.
  final Set<String> productIds =
      data.products.map((Product p) => p.id).toSet();
  final Set<String> categoryIds =
      data.categories.map((ProductCategory c) => c.id).toSet();
  final Set<String> warehouseIds =
      data.warehouses.map((Warehouse w) => w.id).toSet();
  final Set<String> zoneIds = data.zones.map((Zone z) => z.id).toSet();
  final Set<String> locationIds =
      data.locations.map((WarehouseLocation l) => l.id).toSet();
  final Set<String> orderIds =
      data.orders.map((SalesOrder o) => o.id).toSet();
  final Set<String> userIds = data.users.map((AppUser u) => u.id).toSet();

  /// Bir lokasyondaki belirli ürünün miktarı.
  int stockAt(String productId, String locationId) {
    return data.stocks
        .where(
          (Stock s) => s.productId == productId && s.locationId == locationId,
        )
        .fold(0, (int sum, Stock s) => sum + s.quantity);
  }

  /// Bir ürünün tüm lokasyonlardaki toplamı.
  int totalStock(String productId) {
    return data.stocks
        .where((Stock s) => s.productId == productId)
        .fold(0, (int sum, Stock s) => sum + s.quantity);
  }

  group('Şartname 23: minimum veri hacmi', () {
    test('her kayıt türü istenen alt sınırı karşılıyor', () {
      expect(data.products.length, greaterThanOrEqualTo(10));
      expect(data.categories.length, greaterThanOrEqualTo(4));
      expect(data.warehouses.length, greaterThanOrEqualTo(1));
      expect(data.zones.length, greaterThanOrEqualTo(3));
      expect(data.locations.length, greaterThanOrEqualTo(10));
      expect(data.stocks.length, greaterThanOrEqualTo(20));
      expect(data.orders.length, greaterThanOrEqualTo(8));
      expect(data.pickingTasks.length, greaterThanOrEqualTo(5));
      expect(data.goodsReceipts.length, greaterThanOrEqualTo(5));
      expect(data.movements.length, greaterThanOrEqualTo(15));
      expect(data.inventoryCounts.length, greaterThanOrEqualTo(3));
      expect(data.shipments.length, greaterThanOrEqualTo(3));
      expect(data.notifications.length, greaterThanOrEqualTo(5));
    });
  });

  group('Kimlikler benzersiz', () {
    void expectUnique(String label, Iterable<String> ids) {
      final List<String> list = ids.toList();
      expect(list.toSet().length, list.length, reason: '$label: tekrar eden id');
    }

    test('hiçbir listede tekrar eden kimlik yok', () {
      expectUnique('ürün', data.products.map((Product e) => e.id));
      expectUnique('kategori', data.categories.map((ProductCategory e) => e.id));
      expectUnique('depo', data.warehouses.map((Warehouse e) => e.id));
      expectUnique('bölge', data.zones.map((Zone e) => e.id));
      expectUnique('lokasyon', data.locations.map((WarehouseLocation e) => e.id));
      expectUnique('stok', data.stocks.map((Stock e) => e.id));
      expectUnique('sipariş', data.orders.map((SalesOrder e) => e.id));
      expectUnique('toplama', data.pickingTasks.map((PickingTask e) => e.id));
      expectUnique('mal kabul', data.goodsReceipts.map((GoodsReceipt e) => e.id));
      expectUnique('sevkiyat', data.shipments.map((Shipment e) => e.id));
      expectUnique('sayım', data.inventoryCounts.map((InventoryCount e) => e.id));
      expectUnique('hareket', data.movements.map((StockMovement e) => e.id));
      expectUnique('bildirim', data.notifications.map((AppNotification e) => e.id));
      expectUnique('kullanıcı', data.users.map((AppUser e) => e.id));
    });

    test('SKU ve barkodlar benzersiz', () {
      final List<String> skus = data.products.map((Product p) => p.sku).toList();
      final List<String> barcodes =
          data.products.map((Product p) => p.barcode).toList();

      expect(skus.toSet().length, skus.length);
      expect(barcodes.toSet().length, barcodes.length);
    });
  });

  group('Depo yapısı tutarlı', () {
    test('her bölge var olan bir depoya bağlı', () {
      for (final Zone zone in data.zones) {
        expect(warehouseIds, contains(zone.warehouseId), reason: zone.code);
      }
    });

    test('her lokasyon var olan bir bölge ve depoya bağlı', () {
      for (final WarehouseLocation location in data.locations) {
        expect(zoneIds, contains(location.zoneId), reason: location.code);
        expect(
          warehouseIds,
          contains(location.warehouseId),
          reason: location.code,
        );
      }
    });

    test('lokasyonun bölgesi ile deposu birbiriyle uyumlu', () {
      final Map<String, String> zoneWarehouse = <String, String>{
        for (final Zone z in data.zones) z.id: z.warehouseId,
      };

      for (final WarehouseLocation location in data.locations) {
        expect(
          zoneWarehouse[location.zoneId],
          location.warehouseId,
          reason: '${location.code} bölgesiyle farklı depoda görünüyor',
        );
      }
    });

    test('tam olarak bir varsayılan depo var', () {
      final int defaults =
          data.warehouses.where((Warehouse w) => w.isDefault).length;
      expect(defaults, 1);
    });
  });

  group('Ürün ve stok tutarlı', () {
    test('her ürün var olan bir kategoriye bağlı', () {
      for (final Product product in data.products) {
        expect(categoryIds, contains(product.categoryId), reason: product.sku);
      }
    });

    test('her stok kaydı var olan ürün ve lokasyona bağlı', () {
      for (final Stock stock in data.stocks) {
        expect(productIds, contains(stock.productId), reason: stock.id);
        expect(locationIds, contains(stock.locationId), reason: stock.id);
      }
    });

    test('hiçbir stok negatif değil', () {
      for (final Stock stock in data.stocks) {
        expect(stock.quantity, greaterThanOrEqualTo(0), reason: stock.id);
      }
    });

    test('aynı ürün aynı lokasyonda birden fazla kayıt tutmuyor', () {
      final Set<String> seen = <String>{};
      for (final Stock stock in data.stocks) {
        final String key = '${stock.productId}@${stock.locationId}';
        expect(seen.add(key), isTrue, reason: '$key iki kez tanımlanmış');
      }
    });

    test('hiçbir lokasyonun kapasitesi aşılmamış', () {
      for (final WarehouseLocation location in data.locations) {
        final int used = data.stocks
            .where((Stock s) => s.locationId == location.id)
            .fold(0, (int sum, Stock s) => sum + s.quantity);

        expect(
          used,
          lessThanOrEqualTo(location.capacity),
          reason: '${location.code}: $used / ${location.capacity}',
        );
      }
    });

    test('üç stok durumu da veri setinde temsil ediliyor', () {
      final Set<StockStatus> found = data.products
          .map(
            (Product p) =>
                StockStatus.fromQuantity(totalStock(p.id), p.minStock),
          )
          .toSet();

      expect(found, containsAll(StockStatus.values));
    });

    test('birden fazla lokasyonda bulunan ürün var', () {
      final bool hasMultiLocation = data.products.any((Product p) {
        return data.stocks.where((Stock s) => s.productId == p.id).length > 1;
      });

      expect(hasMultiLocation, isTrue);
    });
  });

  group('Siparişler tutarlı', () {
    test('her sipariş satırı var olan bir ürüne bağlı', () {
      for (final SalesOrder order in data.orders) {
        for (final OrderItem item in order.items) {
          expect(
            productIds,
            contains(item.productId),
            reason: '#${order.orderNumber}',
          );
        }
      }
    });

    test('her siparişin en az bir satırı var', () {
      for (final SalesOrder order in data.orders) {
        expect(order.items, isNotEmpty, reason: '#${order.orderNumber}');
      }
    });

    test('toplanan miktar istenen miktarı aşmıyor', () {
      for (final SalesOrder order in data.orders) {
        for (final OrderItem item in order.items) {
          expect(
            item.pickedQuantity,
            lessThanOrEqualTo(item.requestedQuantity),
            reason: '#${order.orderNumber} / ${item.productId}',
          );
        }
      }
    });

    test('altı sipariş durumu da temsil ediliyor', () {
      final Set<OrderStatus> found =
          data.orders.map((SalesOrder o) => o.status).toSet();

      expect(found, containsAll(OrderStatus.values));
    });

    test('sevk edilmiş siparişlerin sevk tarihi var', () {
      for (final SalesOrder order in data.orders) {
        if (order.status == OrderStatus.shipped) {
          expect(order.shippedAt, isNotNull, reason: '#${order.orderNumber}');
        }
      }
    });

    test('tamamlanmış durumdaki siparişler gerçekten tam toplanmış', () {
      for (final SalesOrder order in data.orders) {
        if (order.status == OrderStatus.picked ||
            order.status == OrderStatus.ready ||
            order.status == OrderStatus.shipped) {
          expect(
            order.isFullyPicked,
            isTrue,
            reason: '#${order.orderNumber} durumu ${order.status.label} ama '
                'satırları eksik',
          );
        }
      }
    });
  });

  group('Toplama görevleri tutarlı', () {
    test('her görev var olan bir siparişe bağlı', () {
      for (final PickingTask task in data.pickingTasks) {
        expect(orderIds, contains(task.orderId), reason: task.code);
        expect(userIds, contains(task.assignedUserId), reason: task.code);
      }
    });

    test('her satır var olan ürün ve lokasyona bağlı', () {
      for (final PickingTask task in data.pickingTasks) {
        for (final PickingLine line in task.lines) {
          expect(productIds, contains(line.productId), reason: task.code);
          expect(locationIds, contains(line.locationId), reason: task.code);
        }
      }
    });

    test('bir siparişin en fazla bir toplama görevi var', () {
      final List<String> taskOrderIds =
          data.pickingTasks.map((PickingTask t) => t.orderId).toList();

      expect(taskOrderIds.toSet().length, taskOrderIds.length);
    });

    test('BEKLEYEN toplama satırlarının kaynak lokasyonunda yeterli stok var', () {
      // Demo sırasında toplama adımının "yetersiz stok" ile durmaması için
      // en kritik kontrol budur.
      for (final PickingTask task in data.pickingTasks) {
        if (task.status.isCompleted) continue;

        for (final PickingLine line in task.lines) {
          if (line.isCompleted) continue;

          final int available = stockAt(line.productId, line.locationId);
          expect(
            available,
            greaterThanOrEqualTo(line.remainingQuantity),
            reason:
                '${task.code}: ${line.productId} için ${line.locationId} '
                'lokasyonunda $available adet var, ${line.remainingQuantity} '
                'adet gerekiyor',
          );
        }
      }
    });

    test('tamamlanmış görevlerin tüm satırları toplanmış', () {
      for (final PickingTask task in data.pickingTasks) {
        if (!task.status.isCompleted) continue;
        expect(task.isFullyPicked, isTrue, reason: task.code);
        expect(task.completedAt, isNotNull, reason: task.code);
      }
    });

    test('görev satırları siparişin istediği miktarla örtüşüyor', () {
      final Map<String, SalesOrder> orderById = <String, SalesOrder>{
        for (final SalesOrder o in data.orders) o.id: o,
      };

      for (final PickingTask task in data.pickingTasks) {
        final SalesOrder order = orderById[task.orderId]!;

        for (final PickingLine line in task.lines) {
          final int requestedInOrder = order.items
              .where((OrderItem i) => i.productId == line.productId)
              .fold(0, (int sum, OrderItem i) => sum + i.requestedQuantity);

          expect(
            line.requestedQuantity,
            requestedInOrder,
            reason: '${task.code} / ${line.productId}',
          );
        }
      }
    });
  });

  group('Mal kabul tutarlı', () {
    test('her satır var olan ürüne, hedef lokasyon var olan lokasyona bağlı', () {
      for (final GoodsReceipt receipt in data.goodsReceipts) {
        expect(receipt.lines, isNotEmpty, reason: receipt.code);

        for (final GoodsReceiptLine line in receipt.lines) {
          expect(productIds, contains(line.productId), reason: receipt.code);

          final String? target = line.targetLocationId;
          if (target != null) {
            expect(locationIds, contains(target), reason: receipt.code);
          }
        }
      }
    });

    test('üç mal kabul durumu da temsil ediliyor', () {
      final Set<ReceiptStatus> found =
          data.goodsReceipts.map((GoodsReceipt r) => r.status).toSet();

      expect(found, containsAll(ReceiptStatus.values));
    });

    test('tamamlanmış kabullerde tarih var ve tüm satırlar yerleştirilmiş', () {
      for (final GoodsReceipt receipt in data.goodsReceipts) {
        if (!receipt.status.isCompleted) continue;

        expect(receipt.completedAt, isNotNull, reason: receipt.code);
        for (final GoodsReceiptLine line in receipt.lines) {
          expect(line.isPutAway, isTrue, reason: receipt.code);
        }
      }
    });

    test('bekleyen kabullerde henüz mal alınmamış', () {
      for (final GoodsReceipt receipt in data.goodsReceipts) {
        if (receipt.status != ReceiptStatus.pending) continue;
        expect(receipt.totalReceived, 0, reason: receipt.code);
      }
    });
  });

  group('Sevkiyat tutarlı', () {
    test('her sevkiyat var olan bir siparişe bağlı', () {
      for (final Shipment shipment in data.shipments) {
        expect(orderIds, contains(shipment.orderId), reason: shipment.code);
      }
    });

    test('bir siparişin en fazla bir sevkiyatı var', () {
      final List<String> shipmentOrderIds =
          data.shipments.map((Shipment s) => s.orderId).toList();

      expect(shipmentOrderIds.toSet().length, shipmentOrderIds.length);
    });

    test('sevk edilmiş kayıtlarda tarih ve takip numarası var', () {
      for (final Shipment shipment in data.shipments) {
        if (!shipment.status.isShipped) continue;
        expect(shipment.shippedAt, isNotNull, reason: shipment.code);
        expect(shipment.trackingNumber, isNotNull, reason: shipment.code);
      }
    });

    test('sevk edilmiş sevkiyatın siparişi de sevk edilmiş durumda', () {
      final Map<String, SalesOrder> orderById = <String, SalesOrder>{
        for (final SalesOrder o in data.orders) o.id: o,
      };

      for (final Shipment shipment in data.shipments) {
        if (!shipment.status.isShipped) continue;
        expect(
          orderById[shipment.orderId]!.status,
          OrderStatus.shipped,
          reason: shipment.code,
        );
      }
    });

    test('sevkiyatı olan siparişler toplanmış durumda', () {
      final Map<String, SalesOrder> orderById = <String, SalesOrder>{
        for (final SalesOrder o in data.orders) o.id: o,
      };

      for (final Shipment shipment in data.shipments) {
        final SalesOrder order = orderById[shipment.orderId]!;
        expect(
          order.isFullyPicked,
          isTrue,
          reason: '${shipment.code} toplanmamış siparişe bağlı',
        );
      }
    });
  });

  group('Sayımlar tutarlı', () {
    test('her sayım var olan lokasyon, kullanıcı ve ürünlere bağlı', () {
      for (final InventoryCount count in data.inventoryCounts) {
        expect(locationIds, contains(count.locationId), reason: count.code);
        expect(userIds, contains(count.assignedUserId), reason: count.code);
        expect(count.lines, isNotEmpty, reason: count.code);

        for (final InventoryCountLine line in count.lines) {
          expect(productIds, contains(line.productId), reason: count.code);
        }
      }
    });

    test('üç sayım durumu da temsil ediliyor', () {
      final Set<CountStatus> found =
          data.inventoryCounts.map((InventoryCount c) => c.status).toSet();

      expect(found, containsAll(CountStatus.values));
    });

    test('devam eden sayımın sistem miktarı gerçek stokla aynı', () {
      // Fark hesabının anlamlı olması buna bağlıdır: kullanıcı ekranda
      // gördüğü "Sistem Stoku" ile gerçek stok aynı olmalıdır.
      for (final InventoryCount count in data.inventoryCounts) {
        if (count.status.isCompleted) continue;

        for (final InventoryCountLine line in count.lines) {
          expect(
            line.systemQuantity,
            stockAt(line.productId, count.locationId),
            reason: '${count.code} / ${line.productId}',
          );
        }
      }
    });

    test('tamamlanmış sayımda girilen miktar mevcut stoka eşit', () {
      // Sayım onaylandığında stok o değere çekilir; dolayısıyla tamamlanmış
      // bir sayımın sonucu ile güncel stok birbirini tutmalıdır.
      for (final InventoryCount count in data.inventoryCounts) {
        if (!count.status.isCompleted) continue;

        expect(count.isFullyCounted, isTrue, reason: count.code);
        expect(count.completedAt, isNotNull, reason: count.code);

        for (final InventoryCountLine line in count.lines) {
          expect(
            line.countedQuantity,
            stockAt(line.productId, count.locationId),
            reason: '${count.code} / ${line.productId}',
          );
        }
      }
    });

    test('bekleyen sayımda hiçbir satır girilmemiş', () {
      for (final InventoryCount count in data.inventoryCounts) {
        if (count.status != CountStatus.pending) continue;
        expect(count.countedLineCount, 0, reason: count.code);
      }
    });

    test('farkı olan tamamlanmış sayım var', () {
      // Sayım ekranının fark gösterimi demo'da görünür olmalı.
      final bool hasDifference = data.inventoryCounts.any(
        (InventoryCount c) => c.status.isCompleted && c.differenceCount > 0,
      );

      expect(hasDifference, isTrue);
    });
  });

  group('Stok hareketleri tutarlı', () {
    test('her hareket var olan ürün, kullanıcı ve lokasyonlara bağlı', () {
      for (final StockMovement movement in data.movements) {
        expect(productIds, contains(movement.productId), reason: movement.id);
        expect(userIds, contains(movement.userId), reason: movement.id);

        final String? source = movement.sourceLocationId;
        if (source != null) {
          expect(locationIds, contains(source), reason: movement.id);
        }
        final String? target = movement.targetLocationId;
        if (target != null) {
          expect(locationIds, contains(target), reason: movement.id);
        }
      }
    });

    test('her hareketin en az bir lokasyonu var', () {
      for (final StockMovement movement in data.movements) {
        expect(
          movement.sourceLocationId ?? movement.targetLocationId,
          isNotNull,
          reason: movement.id,
        );
      }
    });

    test('transfer hareketinin kaynağı ve hedefi farklı', () {
      for (final StockMovement movement in data.movements) {
        if (movement.type != MovementType.transfer) continue;

        expect(movement.sourceLocationId, isNotNull, reason: movement.id);
        expect(movement.targetLocationId, isNotNull, reason: movement.id);
        expect(
          movement.sourceLocationId,
          isNot(movement.targetLocationId),
          reason: movement.id,
        );
      }
    });

    test('yedi hareket türü de temsil ediliyor', () {
      final Set<MovementType> found =
          data.movements.map((StockMovement m) => m.type).toSet();

      expect(found, containsAll(MovementType.values));
    });

    test('hareketler son 7 gün içinde ve gelecekte değil', () {
      for (final StockMovement movement in data.movements) {
        expect(
          movement.timestamp.isAfter(
            now.subtract(const Duration(days: AppConstants.reportDayRange)),
          ),
          isTrue,
          reason: '${movement.id} 7 günlük pencerenin dışında',
        );
        expect(
          movement.timestamp.isAfter(now),
          isFalse,
          reason: '${movement.id} gelecekte',
        );
      }
    });

    test('miktar işareti hareket yönüyle uyumlu', () {
      for (final StockMovement movement in data.movements) {
        switch (movement.type.direction) {
          case MovementDirection.inbound:
            expect(movement.quantity, greaterThan(0), reason: movement.id);
          case MovementDirection.outbound:
            expect(movement.quantity, lessThan(0), reason: movement.id);
          case MovementDirection.internal:
            expect(movement.quantity, greaterThan(0), reason: movement.id);
          case MovementDirection.adjustment:
            expect(movement.quantity, isNot(0), reason: movement.id);
        }
      }
    });

    test('bugün hareket var — dashboard boş görünmesin', () {
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final int todayCount = data.movements
          .where((StockMovement m) => m.timestamp.isAfter(startOfDay))
          .length;

      expect(todayCount, greaterThan(0));
    });
  });

  group('Bildirimler tutarlı', () {
    test('beş bildirim türünün tamamı temsil ediliyor', () {
      final Set<NotificationType> found =
          data.notifications.map((AppNotification n) => n.type).toSet();

      expect(found, containsAll(NotificationType.values));
    });

    test('okunmamış bildirim var — rozet görünür olsun', () {
      final int unread =
          data.notifications.where((AppNotification n) => !n.isRead).length;

      expect(unread, greaterThan(0));
    });
  });

  group('Kullanıcılar tutarlı', () {
    test('oturum açmış kullanıcı veri setinde var', () {
      expect(userIds, contains(MockUsers.currentUserId));
    });

    test('her kullanıcı var olan bir depoya bağlı', () {
      for (final AppUser user in data.users) {
        expect(warehouseIds, contains(user.warehouseId), reason: user.id);
      }
    });

    test('üç rol de temsil ediliyor', () {
      final Set<UserRole> found = data.users.map((AppUser u) => u.role).toSet();
      expect(found, containsAll(UserRole.values));
    });
  });

  group('Demo senaryoları çalışabilir durumda', () {
    test('Demo 1: her demo barkodu bir ürüne karşılık geliyor', () {
      for (final String barcode in DemoBarcodes.featured) {
        final bool found =
            data.products.any((Product p) => p.barcode == barcode);
        expect(found, isTrue, reason: '$barcode hiçbir ürüne ait değil');
      }
    });

    test('Demo 2: GR-1024 kabul edilmeyi bekliyor', () {
      final GoodsReceipt receipt = data.goodsReceipts.firstWhere(
        (GoodsReceipt r) => r.code == 'GR-1024',
      );

      expect(receipt.status, ReceiptStatus.pending);
      expect(receipt.totalExpected, 50);
      expect(receipt.totalReceived, 0);
    });

    test('Demo 3: #10452 toplanmaya hazır ve görevi var', () {
      final SalesOrder order = data.orders.firstWhere(
        (SalesOrder o) => o.orderNumber == '10452',
      );
      final PickingTask task = data.pickingTasks.firstWhere(
        (PickingTask t) => t.orderId == order.id,
      );

      expect(order.status.canStartPicking, isTrue);
      expect(task.lines.length, 3);
      expect(task.currentLineIndex, 0);
    });

    test('Demo 4: iPhone 15 iki lokasyonda, transfer yapılabilir', () {
      final Product iphone = data.products.firstWhere(
        (Product p) => p.barcode == '8691234567890',
      );
      final List<Stock> stocks =
          data.stocks.where((Stock s) => s.productId == iphone.id).toList();

      expect(stocks.length, greaterThanOrEqualTo(2));
      expect(totalStock(iphone.id), 24);
      expect(stockAt(iphone.id, 'loc-a0101'), 18);
      expect(stockAt(iphone.id, 'loc-b0302'), 6);
    });

    test('Demo 5: IC-2026-031 sayımı girilmeyi bekliyor', () {
      final InventoryCount count = data.inventoryCounts.firstWhere(
        (InventoryCount c) => c.code == 'IC-2026-031',
      );

      expect(count.status, CountStatus.inProgress);
      expect(count.countedLineCount, 0);
      expect(count.lines.first.systemQuantity, 18);
    });

    test('Demo 6: sevk edilmeyi bekleyen bir sevkiyat var', () {
      final Shipment shipment = data.shipments.firstWhere(
        (Shipment s) => s.status == ShipmentStatus.ready,
      );
      final SalesOrder order = data.orders.firstWhere(
        (SalesOrder o) => o.id == shipment.orderId,
      );

      expect(shipment.canShip, isTrue);
      expect(order.status.canShip, isTrue);
    });
  });

  group('Belirlenebilirlik', () {
    test('aynı referans zamanla üretilen veri aynıdır', () {
      final MockDataset a = MockDataset.seed(now: now);
      final MockDataset b = MockDataset.seed(now: now);

      expect(a.products, b.products);
      expect(a.stocks, b.stocks);
      expect(a.orders, b.orders);
      expect(a.movements, b.movements);
    });

    test('üretilen listeler değiştirilebilir kopyalardır', () {
      // WarehouseDatabase bu listeleri doğrudan değiştirecek; sabit listeler
      // olsaydı ilk transferde çalışma zamanı hatası alırdık.
      final MockDataset fresh = MockDataset.seed(now: now);
      final int before = fresh.stocks.length;

      fresh.stocks.removeLast();

      expect(fresh.stocks.length, before - 1);
      // Kaynak sabit liste etkilenmemiş olmalı.
      expect(MockDataset.seed(now: now).stocks.length, before);
    });
  });
}
