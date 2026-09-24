import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/repositories/repositories.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/data/warehouse_exception.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Provider katmanını doğrular.
///
/// Asıl sınanan şey yenilenme mekanizması: bir yazma işleminden sonra
/// **ilgisiz görünen** ekranların provider'larının da tazelenmesi gerekir.
/// Bu davranış elle `invalidate` yazmadan çalışmalı; bozulursa ekranlar
/// sessizce eski veriyi gösterir ve bunu fark etmek zordur.
void main() {
  /// Gecikmesiz yapılandırmayla kap oluşturur; testler beklemesin.
  ProviderContainer makeContainer() {
    // `Override` tipi flutter_riverpod'dan dışa aktarılmadığı için liste
    // tipi yazılmadan bırakılır; parametreden çıkarılır.
    final ProviderContainer container = ProviderContainer(
      retry: noRetryPolicy,
      overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Veri sürümü sayacı', () {
    test('başlangıçta sıfır', () {
      final ProviderContainer container = makeContainer();
      expect(container.read(dataRevisionProvider), 0);
    });

    test('bump sayacı artırır', () {
      final ProviderContainer container = makeContainer();

      container.read(dataRevisionProvider.notifier).bump();
      container.read(dataRevisionProvider.notifier).bump();

      expect(container.read(dataRevisionProvider), 2);
    });
  });

  group('Yenilenme zinciri', () {
    test('transfer sonrası ürün özeti kendiliğinden tazelenir', () async {
      final ProviderContainer container = makeContainer();

      final ProductStockSummary before = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      final int a0101Before = before.locations
          .firstWhere((LocationStock l) => l.location.code == 'A-01-01')
          .quantity;
      expect(a0101Before, 18);

      // Provider'ı elle invalidate etmiyoruz; yalnızca işlemi yapıyoruz.
      await container.read(warehouseActionsProvider).transferStock(
        productId: 'p-01',
        sourceLocationId: 'loc-a0101',
        targetLocationId: 'loc-b0302',
        quantity: 5,
      );

      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      final int a0101After = after.locations
          .firstWhere((LocationStock l) => l.location.code == 'A-01-01')
          .quantity;

      expect(a0101After, 13);
    });

    test('transfer sonrası lokasyon doluluğu da tazelenir', () async {
      final ProviderContainer container = makeContainer();

      LocationSummary findA0101(List<LocationSummary> all) =>
          all.firstWhere((LocationSummary l) => l.location.code == 'A-01-01');

      final int usedBefore = findA0101(
        await container.read(locationsProvider.future),
      ).usedQuantity;

      await container.read(warehouseActionsProvider).transferStock(
        productId: 'p-01',
        sourceLocationId: 'loc-a0101',
        targetLocationId: 'loc-b0302',
        quantity: 5,
      );

      final int usedAfter = findA0101(
        await container.read(locationsProvider.future),
      ).usedQuantity;

      expect(usedAfter, usedBefore - 5);
    });

    test('toplama sonrası bildirim sayacı tazelenir', () async {
      final ProviderContainer container = makeContainer();

      final int before = await container.read(
        unreadNotificationCountProvider.future,
      );

      // Üç satırı da toplayınca "Toplama tamamlandı" bildirimi oluşur.
      final WarehouseActions actions = container.read(warehouseActionsProvider);
      await actions.pickLine(
        taskId: 'pk-102',
        productId: 'p-01',
        quantity: 2,
      );
      await actions.pickLine(
        taskId: 'pk-102',
        productId: 'p-09',
        quantity: 5,
      );
      await actions.pickLine(
        taskId: 'pk-102',
        productId: 'p-10',
        quantity: 1,
      );

      final int after = await container.read(
        unreadNotificationCountProvider.future,
      );

      expect(after, greaterThan(before));
    });

    test('bildirim okundu işaretlenince sayaç düşer', () async {
      final ProviderContainer container = makeContainer();

      final List<AppNotification> items = await container.read(
        notificationsProvider.future,
      );
      final AppNotification unread = items.firstWhere(
        (AppNotification n) => !n.isRead,
      );
      final int before = await container.read(
        unreadNotificationCountProvider.future,
      );

      await container
          .read(warehouseActionsProvider)
          .markNotificationRead(unread.id);

      final int after = await container.read(
        unreadNotificationCountProvider.future,
      );

      expect(after, before - 1);
    });
  });

  group('Eylemler', () {
    test('kullanıcı kimliği otomatik geçirilir', () async {
      final ProviderContainer container = makeContainer();

      final StockMovement movement = await container
          .read(warehouseActionsProvider)
          .transferStock(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
            targetLocationId: 'loc-b0302',
            quantity: 1,
          );

      expect(movement.userId, container.read(currentUserIdProvider));
    });

    test('iş kuralı ihlali eylem katmanından geçerek yükselir', () async {
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).transferStock(
          productId: 'p-01',
          sourceLocationId: 'loc-a0101',
          targetLocationId: 'loc-a0101',
          quantity: 1,
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

    test('başarısız işlem sayacı artırmaz', () async {
      final ProviderContainer container = makeContainer();
      final int before = container.read(dataRevisionProvider);

      try {
        await container.read(warehouseActionsProvider).transferStock(
          productId: 'p-01',
          sourceLocationId: 'loc-a0101',
          targetLocationId: 'loc-b0302',
          quantity: 9999,
        );
      } on WarehouseException {
        // beklenen
      }

      expect(container.read(dataRevisionProvider), before);
    });

    test('sevkiyat zinciri uçtan uca çalışır', () async {
      final ProviderContainer container = makeContainer();
      final WarehouseActions actions = container.read(warehouseActionsProvider);

      await actions.pickLine(taskId: 'pk-102', productId: 'p-01', quantity: 2);
      await actions.pickLine(taskId: 'pk-102', productId: 'p-09', quantity: 5);
      await actions.pickLine(taskId: 'pk-102', productId: 'p-10', quantity: 1);

      final Shipment shipment = await actions.createShipment('ord-10452');
      final ShipmentDetail detail = await actions.shipOrder(shipment.id);

      expect(detail.shipment.status, ShipmentStatus.shipped);
      expect(detail.order.status, OrderStatus.shipped);
    });
  });

  group('Hata simülasyonu', () {
    test('açıkken okumalar başarısız olur', () async {
      final ProviderContainer container = makeContainer();

      container.read(errorSimulationProvider.notifier).set(true);

      await expectLater(
        container.read(categoriesProvider.future),
        throwsA(
          isA<WarehouseException>().having(
            (WarehouseException e) => e.code,
            'code',
            WarehouseErrorCode.simulatedFailure,
          ),
        ),
      );
    });

    test('kapatılınca okumalar yeniden çalışır', () async {
      final ProviderContainer container = makeContainer();
      final ErrorSimulation simulation = container.read(
        errorSimulationProvider.notifier,
      );

      simulation.set(true);
      try {
        await container.read(categoriesProvider.future);
      } on WarehouseException {
        // beklenen
      }

      simulation.set(false);

      final List<ProductCategory> categories = await container.read(
        categoriesProvider.future,
      );
      expect(categories, isNotEmpty);
    });

    test('açıkken bile yazmalar çalışır', () async {
      // Demo sırasında kullanıcı yaptığı transferi kaybetmemeli.
      final ProviderContainer container = makeContainer();
      container.read(errorSimulationProvider.notifier).set(true);

      final StockMovement movement = await container
          .read(warehouseActionsProvider)
          .transferStock(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
            targetLocationId: 'loc-b0302',
            quantity: 2,
          );

      expect(movement.type, MovementType.transfer);
    });
  });

  group('Repository bağlantıları', () {
    test('tüm repository provider\'ları mock implementasyonu döner', () {
      final ProviderContainer container = makeContainer();

      expect(
        container.read(productRepositoryProvider),
        isA<MockProductRepository>(),
      );
      expect(
        container.read(stockRepositoryProvider),
        isA<MockStockRepository>(),
      );
      expect(
        container.read(orderRepositoryProvider),
        isA<MockOrderRepository>(),
      );
      expect(
        container.read(warehouseRepositoryProvider),
        isA<MockWarehouseRepository>(),
      );
      expect(
        container.read(movementRepositoryProvider),
        isA<MockMovementRepository>(),
      );
    });

    test('tüm repository\'ler aynı veritabanını paylaşır', () async {
      // Ayrı örnekler olsaydı transfer bir ekranda görünür, diğerinde
      // görünmezdi.
      final ProviderContainer container = makeContainer();

      await container.read(warehouseActionsProvider).transferStock(
        productId: 'p-01',
        sourceLocationId: 'loc-a0101',
        targetLocationId: 'loc-b0302',
        quantity: 5,
      );

      final ProductStockSummary viaProduct = (await container
          .read(productRepositoryProvider)
          .getProductById('p-01'))!;
      final ProductStockSummary viaStock = (await container
          .read(stockRepositoryProvider)
          .getStockByProduct('p-01'))!;

      expect(viaProduct.totalQuantity, viaStock.totalQuantity);
      expect(
        viaStock.locations
            .firstWhere((LocationStock l) => l.location.code == 'A-01-01')
            .quantity,
        13,
      );
    });

    test('oturum kullanıcısı yüklenir', () async {
      final ProviderContainer container = makeContainer();
      final AppUser user = await container.read(currentUserProvider.future);

      expect(user.id, container.read(currentUserIdProvider));
      expect(user.role, UserRole.supervisor);
    });

    test('kullanıcının deposu bulunur', () async {
      final ProviderContainer container = makeContainer();
      final Warehouse? warehouse = await container.read(
        currentWarehouseProvider.future,
      );

      expect(warehouse, isNotNull);
      expect(warehouse!.isDefault, isTrue);
    });
  });
}
