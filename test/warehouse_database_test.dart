import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/data/warehouse_database.dart';
import 'package:warehouse_management_system/data/warehouse_exception.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Şartname 26. bölümündeki iş kurallarını doğrular.
///
/// Her kural için hem "engellenmesi gereken" hem "izin verilmesi gereken"
/// durum test edilir. Sadece mutlu yolu test etmek, kuralın hiç çalışmadığı
/// bir kodu da geçirirdi.
///
/// Ayrıca her yazma işleminden sonra stok hareketi oluştuğu doğrulanır —
/// şartname 24. bölümün "işlem gerçekten state'i değiştirmeli" maddesinin
/// makine tarafından kontrol edilen karşılığı budur.
void main() {
  late WarehouseDatabase db;

  // Sabit saat: testler makinenin zamanından bağımsız olsun.
  DateTime clock() => DateTime(2026, 9, 24, 14, 30);

  setUp(() {
    db = WarehouseDatabase(clock: clock);
  });

  /// Testlerde sık kullanılan kimlikler.
  const String iphone = 'p-01';
  const String usbCable = 'p-09';
  const String mouse = 'p-10';
  const String shelfA0101 = 'loc-a0101';
  const String shelfB0302 = 'loc-b0302';
  const String shelfB0102 = 'loc-b0102';
  const String shelfC0101 = 'loc-c0101';
  const String user = 'usr-01';

  group('Başlangıç durumu', () {
    test('şartnamedeki iPhone dağılımı yüklenmiş', () {
      expect(db.quantityAt(iphone, shelfA0101), 18);
      expect(db.quantityAt(iphone, shelfB0302), 6);
      expect(db.totalStockOf(iphone), 24);
      expect(db.statusOf(iphone), StockStatus.normal);
    });

    test('okuma listeleri değiştirilemez', () {
      // Dışarıdan doğrudan değiştirme girişimi engellenmeli; tüm değişiklik
      // iş kurallarının çalıştığı metotlardan geçmeli.
      expect(() => db.stocks.clear(), throwsUnsupportedError);
      expect(() => db.orders.clear(), throwsUnsupportedError);
      expect(() => db.movements.clear(), throwsUnsupportedError);
    });
  });

  group('Transfer kuralları', () {
    test('başarılı transfer kaynağı azaltır, hedefi artırır', () {
      db.transferStock(
        productId: iphone,
        sourceLocationId: shelfA0101,
        targetLocationId: shelfB0302,
        quantity: 5,
        userId: user,
      );

      expect(db.quantityAt(iphone, shelfA0101), 13);
      expect(db.quantityAt(iphone, shelfB0302), 11);
    });

    test('transfer toplam stoku değiştirmez', () {
      final int before = db.totalStockOf(iphone);

      db.transferStock(
        productId: iphone,
        sourceLocationId: shelfA0101,
        targetLocationId: shelfB0302,
        quantity: 5,
        userId: user,
      );

      expect(db.totalStockOf(iphone), before);
    });

    test('transfer tam olarak bir hareket oluşturur', () {
      final int before = db.movements.length;

      db.transferStock(
        productId: iphone,
        sourceLocationId: shelfA0101,
        targetLocationId: shelfB0302,
        quantity: 5,
        userId: user,
      );

      expect(db.movements.length, before + 1);

      final StockMovement movement = db.movements.first;
      expect(movement.type, MovementType.transfer);
      expect(movement.quantity, 5);
      expect(movement.sourceLocationId, shelfA0101);
      expect(movement.targetLocationId, shelfB0302);
      expect(movement.userId, user);
      expect(movement.netEffect, 0);
    });

    test('kaynaktan fazla miktar reddedilir', () {
      expect(
        () => db.transferStock(
          productId: iphone,
          sourceLocationId: shelfA0101,
          targetLocationId: shelfB0302,
          quantity: 19,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.insufficientStock,
          ),
        ),
      );
    });

    test('reddedilen transfer stoku hiç değiştirmez', () {
      try {
        db.transferStock(
          productId: iphone,
          sourceLocationId: shelfA0101,
          targetLocationId: shelfB0302,
          quantity: 19,
          userId: user,
        );
      } on WarehouseException {
        // beklenen
      }

      expect(db.quantityAt(iphone, shelfA0101), 18);
      expect(db.quantityAt(iphone, shelfB0302), 6);
    });

    test('kaynak ve hedef aynı olamaz', () {
      expect(
        () => db.transferStock(
          productId: iphone,
          sourceLocationId: shelfA0101,
          targetLocationId: shelfA0101,
          quantity: 1,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.sameLocation,
          ),
        ),
      );
    });

    test('sıfır ve negatif miktar reddedilir', () {
      for (final int quantity in <int>[0, -3]) {
        expect(
          () => db.transferStock(
            productId: iphone,
            sourceLocationId: shelfA0101,
            targetLocationId: shelfB0302,
            quantity: quantity,
            userId: user,
          ),
          throwsA(
            isA<WarehouseException>().having(
              (WarehouseException e) => e.code,
              'code',
              WarehouseErrorCode.invalidQuantity,
            ),
          ),
          reason: 'miktar: $quantity',
        );
      }
    });

    test('hedef kapasitesi aşılırsa reddedilir', () {
      // B-01-01 kapasitesi 60, hâlihazırda 11 dolu.
      expect(
        () => db.transferStock(
          productId: usbCable,
          sourceLocationId: shelfC0101,
          targetLocationId: 'loc-b0101',
          quantity: 60,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.capacityExceeded,
          ),
        ),
      );
    });

    test('ürünün bulunmadığı lokasyona transfer yeni kayıt açar', () {
      expect(db.quantityAt(iphone, shelfB0102), 0);

      db.transferStock(
        productId: iphone,
        sourceLocationId: shelfA0101,
        targetLocationId: shelfB0102,
        quantity: 4,
        userId: user,
      );

      expect(db.quantityAt(iphone, shelfB0102), 4);
    });

    test('stok tükenince ürün durumu güncellenir', () {
      // MX Master 3S: 3 adet, minimum 10 → zaten kritik.
      expect(db.statusOf(mouse), StockStatus.critical);

      db.transferStock(
        productId: mouse,
        sourceLocationId: shelfC0101,
        targetLocationId: shelfB0302,
        quantity: 3,
        userId: user,
      );

      // Transfer toplamı değiştirmediği için durum kritik kalmalı.
      expect(db.totalStockOf(mouse), 3);
      expect(db.statusOf(mouse), StockStatus.critical);
      expect(db.quantityAt(mouse, shelfC0101), 0);
    });
  });

  group('Mal kabul kuralları', () {
    test('kabul stoku artırır ve kaydı tamamlar', () {
      final int before = db.totalStockOf(iphone);

      final GoodsReceipt receipt = db.receiveGoods(
        receiptId: 'gr-1024',
        productId: iphone,
        quantity: 50,
        targetLocationId: shelfA0101,
        userId: user,
      );

      expect(db.totalStockOf(iphone), before + 50);
      expect(db.quantityAt(iphone, shelfA0101), 68);
      expect(receipt.status, ReceiptStatus.completed);
      expect(receipt.completedAt, isNotNull);
    });

    test('kabul mal kabul hareketi oluşturur', () {
      db.receiveGoods(
        receiptId: 'gr-1024',
        productId: iphone,
        quantity: 50,
        targetLocationId: shelfA0101,
        userId: user,
      );

      final StockMovement movement = db.movements.first;
      expect(movement.type, MovementType.goodsReceipt);
      expect(movement.quantity, 50);
      expect(movement.targetLocationId, shelfA0101);
      expect(movement.netEffect, 50);
      expect(movement.reference, contains('GR-1024'));
    });

    test('kısmi kabul kaydı "Kabul Ediliyor" durumunda bırakır', () {
      final GoodsReceipt receipt = db.receiveGoods(
        receiptId: 'gr-1024',
        productId: iphone,
        quantity: 20,
        targetLocationId: shelfA0101,
        userId: user,
      );

      expect(receipt.status, ReceiptStatus.receiving);
      expect(receipt.lines.first.receivedQuantity, 20);
      expect(receipt.lines.first.remainingQuantity, 30);
      expect(receipt.completedAt, isNull);
    });

    test('beklenenden fazla kabul engellenmez ama işaretlenir', () {
      // Şartname 26: "uyarı gösterilebilir" — engelleme değil.
      final GoodsReceipt receipt = db.receiveGoods(
        receiptId: 'gr-1024',
        productId: iphone,
        quantity: 55,
        targetLocationId: shelfA0101,
        userId: user,
      );

      expect(receipt.hasOverReceipt, isTrue);
      expect(receipt.totalReceived, 55);
      expect(db.quantityAt(iphone, shelfA0101), 73);
    });

    test('sıfır miktar reddedilir', () {
      expect(
        () => db.receiveGoods(
          receiptId: 'gr-1024',
          productId: iphone,
          quantity: 0,
          targetLocationId: shelfA0101,
          userId: user,
        ),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('kayıtta bulunmayan ürün reddedilir', () {
      expect(
        () => db.receiveGoods(
          receiptId: 'gr-1024',
          productId: usbCable,
          quantity: 5,
          targetLocationId: shelfA0101,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.notFound,
          ),
        ),
      );
    });
  });

  group('Putaway kuralları', () {
    test('mal kabul alanından rafa taşır', () {
      // GR-1025 ile gelen 120 adet kablo M-01'de bekliyor.
      expect(db.quantityAt(usbCable, 'loc-m01'), 120);

      db.putaway(
        receiptId: 'gr-1025',
        productId: usbCable,
        sourceLocationId: 'loc-m01',
        targetLocationId: shelfC0101,
        quantity: 100,
        userId: user,
      );

      expect(db.quantityAt(usbCable, 'loc-m01'), 20);
      expect(db.quantityAt(usbCable, shelfC0101), 185);
    });

    test('putaway hareketi kaynak ve hedef taşır', () {
      db.putaway(
        receiptId: 'gr-1025',
        productId: usbCable,
        sourceLocationId: 'loc-m01',
        targetLocationId: shelfC0101,
        quantity: 100,
        userId: user,
      );

      final StockMovement movement = db.movements.first;
      expect(movement.type, MovementType.putaway);
      expect(movement.sourceLocationId, 'loc-m01');
      expect(movement.targetLocationId, shelfC0101);
      // Depo içi taşıma: toplam stok değişmez.
      expect(movement.netEffect, 0);
    });

    test('mal kabul satırının hedef lokasyonu güncellenir', () {
      final GoodsReceipt receipt = db.putaway(
        receiptId: 'gr-1025',
        productId: usbCable,
        sourceLocationId: 'loc-m01',
        targetLocationId: shelfC0101,
        quantity: 100,
        userId: user,
      );

      final GoodsReceiptLine line = receipt.lines.firstWhere(
        (GoodsReceiptLine l) => l.productId == usbCable,
      );
      expect(line.targetLocationId, shelfC0101);
      expect(line.isPutAway, isTrue);
    });
  });

  group('Toplama kuralları', () {
    test('yeni sipariş için görev oluşturulur ve durum değişir', () {
      final PickingTask task = db.startPicking(
        orderId: 'ord-10453',
        userId: user,
      );

      expect(task.lines.length, 2);
      expect(task.status, PickingStatus.inProgress);
      expect(db.orderById('ord-10453')!.status, OrderStatus.picking);
    });

    test('aynı sipariş için ikinci görev oluşturulmaz', () {
      final PickingTask first = db.startPicking(
        orderId: 'ord-10453',
        userId: user,
      );
      final PickingTask second = db.startPicking(
        orderId: 'ord-10453',
        userId: user,
      );

      expect(second.id, first.id);
      expect(
        db.pickingTasks.where((PickingTask t) => t.orderId == 'ord-10453').length,
        1,
      );
    });

    test('sevk edilmiş sipariş toplamaya alınamaz', () {
      expect(
        () => db.startPicking(orderId: 'ord-10457', userId: user),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.pickingNotAllowed,
          ),
        ),
      );
    });

    test('görev kaynak lokasyonu en çok stoğun olduğu rafı seçer', () {
      // USB-C kablo: M-01'de 120, C-01-01'de 85, B-01-02'de 40.
      final PickingTask task = db.startPicking(
        orderId: 'ord-10453',
        userId: user,
      );

      final PickingLine line = task.lines.firstWhere(
        (PickingLine l) => l.productId == usbCable,
      );
      expect(line.locationId, 'loc-m01');
    });

    test('toplama stoku azaltır ve hareket oluşturur', () {
      final int before = db.quantityAt(iphone, shelfA0101);

      db.pickLine(
        taskId: 'pk-102',
        productId: iphone,
        quantity: 2,
        userId: user,
      );

      expect(db.quantityAt(iphone, shelfA0101), before - 2);

      final StockMovement movement = db.movements.first;
      expect(movement.type, MovementType.pick);
      expect(movement.quantity, -2);
      expect(movement.netEffect, -2);
      expect(movement.sourceLocationId, shelfA0101);
      expect(movement.reference, contains('10452'));
    });

    test('toplama sipariş satırını da ilerletir', () {
      db.pickLine(
        taskId: 'pk-102',
        productId: iphone,
        quantity: 2,
        userId: user,
      );

      final SalesOrder order = db.orderById('ord-10452')!;
      final OrderItem item = order.items.firstWhere(
        (OrderItem i) => i.productId == iphone,
      );

      expect(item.pickedQuantity, 2);
      expect(item.isPicked, isTrue);
    });

    test('istenen miktardan fazla toplanamaz', () {
      expect(
        () => db.pickLine(
          taskId: 'pk-102',
          productId: iphone,
          quantity: 3,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.exceedsRequested,
          ),
        ),
      );
    });

    test('kaynak lokasyonda yeterli stok yoksa engellenir', () {
      // Önce rafı boşalt, sonra toplamayı dene.
      db.transferStock(
        productId: iphone,
        sourceLocationId: shelfA0101,
        targetLocationId: shelfB0302,
        quantity: 18,
        userId: user,
      );

      expect(
        () => db.pickLine(
          taskId: 'pk-102',
          productId: iphone,
          quantity: 2,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.insufficientStock,
          ),
        ),
      );
    });

    test('tüm satırlar bitmeden sipariş "Toplandı" olmaz', () {
      db.pickLine(
        taskId: 'pk-102',
        productId: iphone,
        quantity: 2,
        userId: user,
      );

      expect(db.orderById('ord-10452')!.status, OrderStatus.picking);
      expect(db.pickingTaskById('pk-102')!.status, PickingStatus.inProgress);
    });

    test('son satır toplanınca sipariş ve görev tamamlanır', () {
      db.pickLine(taskId: 'pk-102', productId: iphone, quantity: 2, userId: user);
      db.pickLine(taskId: 'pk-102', productId: usbCable, quantity: 5, userId: user);
      db.pickLine(taskId: 'pk-102', productId: mouse, quantity: 1, userId: user);

      final PickingTask task = db.pickingTaskById('pk-102')!;
      final SalesOrder order = db.orderById('ord-10452')!;

      expect(task.status, PickingStatus.completed);
      expect(task.completedAt, isNotNull);
      expect(task.isFullyPicked, isTrue);
      expect(order.status, OrderStatus.picked);
      expect(order.isFullyPicked, isTrue);
    });

    test('parça parça toplama da desteklenir', () {
      db.pickLine(taskId: 'pk-102', productId: usbCable, quantity: 2, userId: user);
      db.pickLine(taskId: 'pk-102', productId: usbCable, quantity: 3, userId: user);

      final PickingLine line = db.pickingTaskById('pk-102')!.lines.firstWhere(
        (PickingLine l) => l.productId == usbCable,
      );

      expect(line.pickedQuantity, 5);
      expect(line.isCompleted, isTrue);
    });
  });

  group('Sayım kuralları', () {
    test('sayım girişi stoku hemen değiştirmez', () {
      final int before = db.quantityAt(iphone, shelfA0101);

      db.recordCount(countId: 'ic-031', productId: iphone, countedQuantity: 17);

      expect(db.quantityAt(iphone, shelfA0101), before);
    });

    test('fark doğru hesaplanır', () {
      final InventoryCount count = db.recordCount(
        countId: 'ic-031',
        productId: iphone,
        countedQuantity: 17,
      );

      final InventoryCountLine line = count.lines.firstWhere(
        (InventoryCountLine l) => l.productId == iphone,
      );

      expect(line.systemQuantity, 18);
      expect(line.countedQuantity, 17);
      expect(line.difference, -1);
    });

    test('negatif sayım reddedilir', () {
      expect(
        () => db.recordCount(
          countId: 'ic-031',
          productId: iphone,
          countedQuantity: -1,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.negativeCount,
          ),
        ),
      );
    });

    test('sıfır sayımı geçerlidir', () {
      final InventoryCount count = db.recordCount(
        countId: 'ic-031',
        productId: iphone,
        countedQuantity: 0,
      );

      final InventoryCountLine line = count.lines.first;
      expect(line.isCounted, isTrue);
      expect(line.difference, -18);
    });

    test('tüm satırlar girilmeden sayım tamamlanamaz', () {
      db.recordCount(countId: 'ic-031', productId: iphone, countedQuantity: 17);

      expect(
        () => db.completeCount(countId: 'ic-031', userId: user),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.countIncomplete,
          ),
        ),
      );
    });

    test('onay stoku sayılan değere çeker', () {
      db.recordCount(countId: 'ic-031', productId: iphone, countedQuantity: 17);
      db.recordCount(countId: 'ic-031', productId: 'p-02', countedQuantity: 12);

      db.completeCount(countId: 'ic-031', userId: user);

      expect(db.quantityAt(iphone, shelfA0101), 17);
      expect(db.quantityAt('p-02', shelfA0101), 12);
      expect(db.countById('ic-031')!.status, CountStatus.completed);
    });

    test('yalnızca farkı olan satır düzeltme hareketi üretir', () {
      final int before = db.movements.length;

      db.recordCount(countId: 'ic-031', productId: iphone, countedQuantity: 17);
      db.recordCount(countId: 'ic-031', productId: 'p-02', countedQuantity: 12);
      db.completeCount(countId: 'ic-031', userId: user);

      // iPhone'da -1 fark var, p-02'de fark yok → tek hareket.
      expect(db.movements.length, before + 1);

      final StockMovement movement = db.movements.first;
      expect(movement.type, MovementType.countAdjustment);
      expect(movement.quantity, -1);
      expect(movement.netEffect, -1);
      expect(movement.reference, 'IC-2026-031');
    });

    test('fazla çıkan sayım stoku artırır', () {
      db.recordCount(countId: 'ic-031', productId: iphone, countedQuantity: 20);
      db.recordCount(countId: 'ic-031', productId: 'p-02', countedQuantity: 12);
      db.completeCount(countId: 'ic-031', userId: user);

      expect(db.quantityAt(iphone, shelfA0101), 20);
      expect(db.movements.first.quantity, 2);
    });
  });

  group('Sevkiyat kuralları', () {
    test('toplanmış sipariş sevk edilebilir', () {
      final Shipment shipment = db.shipOrder(
        shipmentId: 'shp-013',
        userId: user,
      );

      expect(shipment.status, ShipmentStatus.shipped);
      expect(shipment.shippedAt, isNotNull);
      expect(shipment.trackingNumber, isNotNull);
      expect(db.orderById('ord-10456')!.status, OrderStatus.shipped);
      expect(db.orderById('ord-10456')!.shippedAt, isNotNull);
    });

    test('sevkiyat stok hareketi oluşturmaz', () {
      // Mal zaten toplama sırasında raftan düşmüştü; ikinci bir hareket
      // aynı malın iki kez çıkmış görünmesine yol açardı.
      final int before = db.movements.length;

      db.shipOrder(shipmentId: 'shp-013', userId: user);

      expect(db.movements.length, before);
    });

    test('sevk edilmiş sipariş yeniden sevk edilemez', () {
      db.shipOrder(shipmentId: 'shp-013', userId: user);

      expect(
        () => db.shipOrder(shipmentId: 'shp-013', userId: user),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.alreadyShipped,
          ),
        ),
      );
    });

    test('zaten sevk edilmiş kayıt tekrar sevk edilemez', () {
      expect(
        () => db.shipOrder(shipmentId: 'shp-012', userId: user),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.alreadyShipped,
          ),
        ),
      );
    });

    test('toplanmamış sipariş için sevkiyat açılamaz', () {
      expect(
        () => db.createShipment(orderId: 'ord-10452'),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.notPicked,
          ),
        ),
      );
    });

    test('toplama bitince sevkiyat açılabilir', () {
      db.pickLine(taskId: 'pk-102', productId: iphone, quantity: 2, userId: user);
      db.pickLine(taskId: 'pk-102', productId: usbCable, quantity: 5, userId: user);
      db.pickLine(taskId: 'pk-102', productId: mouse, quantity: 1, userId: user);

      final Shipment shipment = db.createShipment(orderId: 'ord-10452');

      expect(shipment.status, ShipmentStatus.ready);
      expect(db.orderById('ord-10452')!.status, OrderStatus.ready);
    });
  });

  group('Bildirimler', () {
    test('okundu işareti sayacı düşürür', () {
      final int before = db.unreadNotificationCount;
      final AppNotification unread = db.notifications.firstWhere(
        (AppNotification n) => !n.isRead,
      );

      db.markNotificationRead(unread.id);

      expect(db.unreadNotificationCount, before - 1);
    });

    test('tümünü okundu işaretle sayacı sıfırlar', () {
      db.markAllNotificationsRead();
      expect(db.unreadNotificationCount, 0);
    });

    test('stok kritiğe düşünce bildirim oluşur', () {
      // iPhone 15: 24 adet, minimum 10. Toplama ile 24'ü tüketelim.
      // Önce tüm stoğu tek rafta toplayalım.
      db.transferStock(
        productId: iphone,
        sourceLocationId: shelfB0302,
        targetLocationId: shelfA0101,
        quantity: 6,
        userId: user,
      );

      final int before = db.notifications
          .where(
            (AppNotification n) => n.type == NotificationType.criticalStock,
          )
          .length;

      // Sayımla stoku 8'e çekelim — minimum 10'un altında.
      db.recordCount(countId: 'ic-031', productId: iphone, countedQuantity: 8);
      db.recordCount(countId: 'ic-031', productId: 'p-02', countedQuantity: 12);
      db.completeCount(countId: 'ic-031', userId: user);

      expect(db.statusOf(iphone), StockStatus.critical);

      final int after = db.notifications
          .where(
            (AppNotification n) => n.type == NotificationType.criticalStock,
          )
          .length;

      expect(after, greaterThan(before));
    });

    test('aynı ürün için okunmamış uyarı varken ikincisi eklenmez', () {
      // MX Master 3S zaten kritik ve okunmamış uyarısı var.
      final int before = db.notifications
          .where(
            (AppNotification n) =>
                n.type == NotificationType.criticalStock &&
                n.targetRoute == '/products/$mouse',
          )
          .length;

      db.transferStock(
        productId: mouse,
        sourceLocationId: shelfC0101,
        targetLocationId: shelfB0302,
        quantity: 1,
        userId: user,
      );

      final int after = db.notifications
          .where(
            (AppNotification n) =>
                n.type == NotificationType.criticalStock &&
                n.targetRoute == '/products/$mouse',
          )
          .length;

      expect(after, before);
    });
  });

  group('Bilinmeyen kayıtlar', () {
    test('var olmayan ürün, lokasyon ve siparişler hata verir', () {
      expect(
        () => db.transferStock(
          productId: 'yok',
          sourceLocationId: shelfA0101,
          targetLocationId: shelfB0302,
          quantity: 1,
          userId: user,
        ),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.notFound,
          ),
        ),
      );

      expect(
        () => db.transferStock(
          productId: iphone,
          sourceLocationId: 'yok',
          targetLocationId: shelfB0302,
          quantity: 1,
          userId: user,
        ),
        throwsA(isA<WarehouseException>()),
      );

      expect(
        () => db.startPicking(orderId: 'yok', userId: user),
        throwsA(isA<WarehouseException>()),
      );
    });
  });

  group('Barkod ve kod arama', () {
    test('barkoddan ürün bulunur', () {
      expect(db.productByBarcode('8691234567890')?.id, iphone);
      expect(db.productByBarcode('  8691234567890  ')?.id, iphone);
      expect(db.productByBarcode('yok'), isNull);
    });

    test('SKU ile de arama yapılabilir', () {
      expect(db.productByCode('IP15-128-BLK')?.id, iphone);
      expect(db.productByCode('ip15-128-blk')?.id, iphone);
      expect(db.productByCode('8691234567890')?.id, iphone);
    });

    test('lokasyon koduyla arama yapılabilir', () {
      expect(db.locationByCode('A-01-01')?.id, shelfA0101);
      expect(db.locationByCode('a-01-01')?.id, shelfA0101);
    });
  });

  group('Demo senaryosu uçtan uca', () {
    test('sipariş #10452 toplanıp sevk edilebiliyor', () {
      // 1. Başlangıç durumu
      expect(db.orderById('ord-10452')!.status, OrderStatus.picking);
      final int iphoneBefore = db.totalStockOf(iphone);
      final int movementsBefore = db.movements.length;

      // 2. Üç ürünü sırayla topla
      db.pickLine(taskId: 'pk-102', productId: iphone, quantity: 2, userId: user);
      db.pickLine(taskId: 'pk-102', productId: usbCable, quantity: 5, userId: user);
      db.pickLine(taskId: 'pk-102', productId: mouse, quantity: 1, userId: user);

      // 3. Stok gerçekten azaldı
      expect(db.totalStockOf(iphone), iphoneBefore - 2);

      // 4. Her toplama bir hareket üretti
      expect(db.movements.length, movementsBefore + 3);

      // 5. Sipariş toplandı
      expect(db.orderById('ord-10452')!.status, OrderStatus.picked);

      // 6. Sevkiyat aç ve sevk et
      final Shipment shipment = db.createShipment(orderId: 'ord-10452');
      db.shipOrder(shipmentId: shipment.id, userId: user);

      // 7. Sipariş sevk edildi
      expect(db.orderById('ord-10452')!.status, OrderStatus.shipped);
      expect(db.shipmentForOrder('ord-10452')!.status, ShipmentStatus.shipped);
    });

    test('mal kabul sonrası stok artışı hareket geçmişinde görünüyor', () {
      final int before = db.totalStockOf(iphone);

      db.receiveGoods(
        receiptId: 'gr-1024',
        productId: iphone,
        quantity: 50,
        targetLocationId: shelfA0101,
        userId: user,
      );

      expect(db.totalStockOf(iphone), before + 50);

      final StockMovement movement = db.movementsOfProduct(iphone).first;
      expect(movement.type, MovementType.goodsReceipt);
      expect(movement.quantity, 50);
    });
  });
}
