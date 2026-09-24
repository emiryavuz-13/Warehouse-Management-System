import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Modellerin hesaplanan alanlarını doğrular.
///
/// Bu alanlar iş kurallarının temelidir: stok durumu, toplama ilerlemesi ve
/// sayım farkı buradan okunur. Yanlış hesaplanırlarsa hata tüm ekranlara
/// yayılır, bu yüzden repository katmanından önce test edilirler.
void main() {
  group('StockStatus.fromQuantity', () {
    test('miktar sıfır veya altındaysa Stok Yok döner', () {
      expect(StockStatus.fromQuantity(0, 5), StockStatus.outOfStock);
      expect(StockStatus.fromQuantity(-3, 5), StockStatus.outOfStock);
    });

    test('miktar minimum stok seviyesindeyse Kritik döner', () {
      expect(StockStatus.fromQuantity(5, 5), StockStatus.critical);
    });

    test('miktar minimum stokun altındaysa Kritik döner', () {
      expect(StockStatus.fromQuantity(2, 5), StockStatus.critical);
    });

    test('miktar minimum stokun üstündeyse Normal döner', () {
      expect(StockStatus.fromQuantity(6, 5), StockStatus.normal);
    });

    test('minimum stok sıfırsa bir adet bile Normal sayılır', () {
      expect(StockStatus.fromQuantity(1, 0), StockStatus.normal);
    });
  });

  group('SalesOrder', () {
    SalesOrder buildOrder(List<OrderItem> items) => SalesOrder(
      id: 'o-1',
      orderNumber: '10452',
      customerName: 'ABC Teknoloji',
      items: items,
      status: OrderStatus.picking,
      priority: OrderPriority.normal,
      createdAt: DateTime(2026, 9, 24),
    );

    test('toplam adet tüm satırların istenen miktarını toplar', () {
      final SalesOrder order = buildOrder(<OrderItem>[
        const OrderItem(productId: 'p-1', requestedQuantity: 2),
        const OrderItem(productId: 'p-2', requestedQuantity: 5),
        const OrderItem(productId: 'p-3', requestedQuantity: 1),
      ]);

      expect(order.totalQuantity, 8);
      expect(order.lineCount, 3);
    });

    test('kısmi toplamada ilerleme oransal hesaplanır', () {
      final SalesOrder order = buildOrder(<OrderItem>[
        const OrderItem(
          productId: 'p-1',
          requestedQuantity: 2,
          pickedQuantity: 2,
        ),
        const OrderItem(
          productId: 'p-2',
          requestedQuantity: 6,
          pickedQuantity: 2,
        ),
      ]);

      expect(order.pickedQuantity, 4);
      expect(order.pickProgress, 0.5);
      expect(order.isFullyPicked, isFalse);
    });

    test('tüm satırlar toplandığında sipariş tamamlanmış sayılır', () {
      final SalesOrder order = buildOrder(<OrderItem>[
        const OrderItem(
          productId: 'p-1',
          requestedQuantity: 2,
          pickedQuantity: 2,
        ),
      ]);

      expect(order.isFullyPicked, isTrue);
      expect(order.pickProgress, 1.0);
    });

    test('satırı olmayan sipariş tamamlanmış sayılmaz', () {
      final SalesOrder order = buildOrder(<OrderItem>[]);

      expect(order.isFullyPicked, isFalse);
      expect(order.pickProgress, 0);
    });
  });

  group('OrderStatus iş kuralları', () {
    test('sadece toplanmış veya hazır sipariş sevk edilebilir', () {
      expect(OrderStatus.picked.canShip, isTrue);
      expect(OrderStatus.ready.canShip, isTrue);
      expect(OrderStatus.newOrder.canShip, isFalse);
      expect(OrderStatus.picking.canShip, isFalse);
      expect(OrderStatus.shipped.canShip, isFalse);
    });

    test('sevk edilmiş ve iptal edilmiş siparişler kapalıdır', () {
      expect(OrderStatus.shipped.isClosed, isTrue);
      expect(OrderStatus.cancelled.isClosed, isTrue);
      expect(OrderStatus.picking.isClosed, isFalse);
    });
  });

  group('PickingTask', () {
    PickingTask buildTask(List<PickingLine> lines) => PickingTask(
      id: 'pk-1',
      code: 'PK-102',
      orderId: 'o-1',
      lines: lines,
      status: PickingStatus.inProgress,
      assignedUserId: 'u-1',
      createdAt: DateTime(2026, 9, 24),
    );

    test('sıradaki satır ilk tamamlanmamış satırdır', () {
      final PickingTask task = buildTask(<PickingLine>[
        const PickingLine(
          productId: 'p-1',
          locationId: 'l-1',
          requestedQuantity: 2,
          pickedQuantity: 2,
        ),
        const PickingLine(
          productId: 'p-2',
          locationId: 'l-2',
          requestedQuantity: 5,
        ),
      ]);

      expect(task.currentLineIndex, 1);
      expect(task.currentLine?.productId, 'p-2');
      expect(task.completedLineCount, 1);
      expect(task.progress, 0.5);
    });

    test('tüm satırlar bittiğinde sıradaki satır kalmaz', () {
      final PickingTask task = buildTask(<PickingLine>[
        const PickingLine(
          productId: 'p-1',
          locationId: 'l-1',
          requestedQuantity: 2,
          pickedQuantity: 2,
        ),
      ]);

      expect(task.currentLineIndex, -1);
      expect(task.currentLine, isNull);
      expect(task.isFullyPicked, isTrue);
      expect(task.progress, 1.0);
    });
  });

  group('GoodsReceiptLine', () {
    test('beklenenden fazla kabul uyarı olarak işaretlenir', () {
      const GoodsReceiptLine line = GoodsReceiptLine(
        productId: 'p-1',
        expectedQuantity: 50,
        receivedQuantity: 55,
      );

      expect(line.isOverReceived, isTrue);
      expect(line.isCompleted, isTrue);
      // Kalan miktar negatife düşmez.
      expect(line.remainingQuantity, 0);
    });

    test('yerleştirme lokasyon atanmadan tamamlanmış sayılmaz', () {
      const GoodsReceiptLine line = GoodsReceiptLine(
        productId: 'p-1',
        expectedQuantity: 50,
        receivedQuantity: 50,
      );

      expect(line.isPutAway, isFalse);
      expect(line.copyWith(targetLocationId: 'l-1').isPutAway, isTrue);
    });
  });

  group('InventoryCountLine', () {
    test('sayılmamış satırda fark hesaplanmaz', () {
      const InventoryCountLine line = InventoryCountLine(
        productId: 'p-1',
        systemQuantity: 24,
      );

      expect(line.isCounted, isFalse);
      expect(line.difference, isNull);
      expect(line.hasDifference, isFalse);
    });

    test('eksik sayımda fark negatif çıkar', () {
      const InventoryCountLine line = InventoryCountLine(
        productId: 'p-1',
        systemQuantity: 24,
        countedQuantity: 23,
      );

      expect(line.difference, -1);
      expect(line.hasDifference, isTrue);
    });

    test('sıfır sayımı ile hiç sayılmamış birbirinden ayrılır', () {
      const InventoryCountLine counted = InventoryCountLine(
        productId: 'p-1',
        systemQuantity: 5,
        countedQuantity: 0,
      );

      expect(counted.isCounted, isTrue);
      expect(counted.difference, -5);
      expect(counted.clearCount().isCounted, isFalse);
    });

    test('sayım sistemle uyuşuyorsa fark sıfırdır', () {
      const InventoryCountLine line = InventoryCountLine(
        productId: 'p-1',
        systemQuantity: 24,
        countedQuantity: 24,
      );

      expect(line.difference, 0);
      expect(line.hasDifference, isFalse);
    });
  });

  group('StockMovement.netEffect', () {
    StockMovement build(MovementType type, int quantity) => StockMovement(
      id: 'm-1',
      productId: 'p-1',
      quantity: quantity,
      type: type,
      userId: 'u-1',
      timestamp: DateTime(2026, 9, 24),
      reference: 'test',
    );

    test('mal kabul toplam stoku artırır', () {
      expect(build(MovementType.goodsReceipt, 10).netEffect, 10);
    });

    test('sipariş çıkışı toplam stoku azaltır', () {
      expect(build(MovementType.pick, 2).netEffect, -2);
    });

    test('transfer toplam stoku değiştirmez', () {
      expect(build(MovementType.transfer, 5).netEffect, 0);
    });

    test('sayım düzeltmesi işaretini korur', () {
      expect(build(MovementType.countAdjustment, -1).netEffect, -1);
      expect(build(MovementType.countAdjustment, 3).netEffect, 3);
    });
  });

  group('WarehouseLocation', () {
    const WarehouseLocation location = WarehouseLocation(
      id: 'l-1',
      code: 'A-01-01',
      zoneId: 'z-1',
      warehouseId: 'w-1',
      type: LocationType.storage,
      capacity: 100,
    );

    test('doluluk oranı kapasiteye göre hesaplanır', () {
      expect(location.occupancyRatio(50), 0.5);
      expect(location.availableCapacity(50), 50);
    });

    test('kapasite aşılsa bile oran 1.0 üzerine çıkmaz', () {
      expect(location.occupancyRatio(150), 1.0);
      expect(location.availableCapacity(150), 0);
    });

    test('bölge ön eki lokasyon kodundan türetilir', () {
      expect(location.zonePrefix, 'A');
    });
  });

  group('Baş harf üretimi', () {
    test('kullanıcı adından iki harf üretilir', () {
      final AppUser user = AppUser(
        id: 'u-1',
        fullName: 'Emir Yavuz',
        role: UserRole.supervisor,
        warehouseId: 'w-1',
        lastLoginAt: DateTime(2026, 9, 24),
      );

      expect(user.initials, 'EY');
      expect(user.firstName, 'Emir');
    });

    test('tek kelimelik üründe tek harf üretilir', () {
      const Product product = Product(
        id: 'p-1',
        sku: 'MOUSE-01',
        name: 'Mouse',
        barcode: '123',
        brand: 'Logitech',
        categoryId: 'c-1',
        unit: 'adet',
        minStock: 5,
      );

      expect(product.initials, 'M');
    });
  });
}
