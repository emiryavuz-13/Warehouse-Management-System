import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/data/warehouse_exception.dart';
import 'package:warehouse_management_system/features/dashboard/providers/dashboard_providers.dart';
import 'package:warehouse_management_system/features/transfer/providers/transfer_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Stok transferini doğrular (şartname 15. bölüm).
///
/// Mal kabulden farkı toplamın sabit kalması: transfer depoya mal sokmaz,
/// yerini değiştirir. Testlerin çoğu bu değişmezi kontrol eder.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      retry: noRetryPolicy,
      overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Dashboard'daki "Transfer" hızlı işlemiyle ekranı açar.
  Future<ProviderContainer> openTransfer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        retry: noRetryPolicy,
        overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
        child: const WarehouseApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  /// Ürün detayından transfere girer — ürün önceden seçili açılmalı.
  Future<ProviderContainer> openTransferForIphone(WidgetTester tester) async {
    final ProviderContainer container = await openTransfer(tester);

    await tester.tap(find.text('Ürün Seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('iPhone 15 128GB'));
    await tester.pumpAndSettle();

    return container;
  }

  /// Kaynak ve hedef satırları anahtarla seçilir: aynı raf kodu (B-03-02)
  /// hem kaynak hem hedef listesinde görünebilir.
  Future<void> selectSource(WidgetTester tester, String locationId) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey<String>('source-$locationId')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(ValueKey<String>('source-$locationId')));
    await tester.pumpAndSettle();
  }

  Future<void> selectTarget(WidgetTester tester, String locationId) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey<String>('target-$locationId')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(ValueKey<String>('target-$locationId')));
    await tester.pumpAndSettle();
  }

  group('Ekran açılışı', () {
    testWidgets('ürün seçilmeden boş durum gösterilir', (
      WidgetTester tester,
    ) async {
      await openTransfer(tester);

      expect(find.text('Stok Transferi'), findsWidgets);
      expect(find.text('Hangi ürünü taşıyacaksınız?'), findsOneWidget);
      expect(find.text('Ürün Seç'), findsOneWidget);
    });

    testWidgets('ürün detayından gelince ürün önceden seçili', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          retry: noRetryPolicy,
          overrides: [
            mockConfigProvider.overrideWithValue(MockConfig.instant()),
          ],
          child: const WarehouseApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('ÜRÜN'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('iPhone 15 128GB').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stok Transfer Et'));
      await tester.pumpAndSettle();

      expect(find.text('Hangi ürünü taşıyacaksınız?'), findsNothing);
      expect(find.text('Kaynak Lokasyon'), findsOneWidget);
      expect(find.textContaining('iPhone 15 128GB'), findsWidgets);
    });

    testWidgets('şartnamedeki dört adım da bulunur', (
      WidgetTester tester,
    ) async {
      // Ürün → Kaynak → Hedef → Miktar.
      await openTransferForIphone(tester);

      expect(find.text('Ürün'), findsOneWidget);
      expect(find.text('Kaynak Lokasyon'), findsOneWidget);
      expect(find.text('Hedef Lokasyon'), findsOneWidget);
      expect(find.text('Miktar'), findsOneWidget);
    });
  });

  group('Ürün seçme paneli', () {
    testWidgets('stoksuz ürünler listelenmez', (WidgetTester tester) async {
      // Tükenmiş ürün transferin kaynağı olamaz.
      await openTransfer(tester);

      await tester.tap(find.text('Ürün Seç'));
      await tester.pumpAndSettle();

      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
      expect(find.textContaining('ThinkPad'), findsNothing);
    });

    testWidgets('panelde arama çalışır', (WidgetTester tester) async {
      await openTransfer(tester);

      await tester.tap(find.text('Ürün Seç'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'LOGI-MX3S');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.textContaining('MX Master'), findsOneWidget);
      expect(find.textContaining('iPhone'), findsNothing);
    });
  });

  group('Lokasyon seçimi', () {
    testWidgets('kaynak listesi ürünün bulunduğu rafları gösterir', (
      WidgetTester tester,
    ) async {
      await openTransferForIphone(tester);

      // iPhone: A-01-01 → 18, B-03-02 → 6.
      expect(find.text('A-01-01'), findsWidgets);
      expect(find.text('B-03-02'), findsWidgets);
      expect(find.text('18 adet'), findsOneWidget);
      expect(find.text('6 adet'), findsOneWidget);
    });

    testWidgets('kaynak seçilmeden hedef listesi açılmaz', (
      WidgetTester tester,
    ) async {
      await openTransferForIphone(tester);

      expect(find.text('Önce kaynak seçin'), findsWidgets);
    });

    testWidgets('kaynak hedef listesinden çıkarılır', (
      WidgetTester tester,
    ) async {
      // Aynı rafa transfer bir işlem değil, bir yanlışlık.
      final ProviderContainer container = await openTransferForIphone(tester);

      final List<TransferTarget> targets = await container.read(
        targetLocationsProvider(
          const TransferTargetQuery(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
          ),
        ).future,
      );

      expect(
        targets.every(
          (TransferTarget t) => t.summary.location.id != 'loc-a0101',
        ),
        isTrue,
      );
    });

    testWidgets('ürünün bulunduğu hedef raf önerilir', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openTransferForIphone(tester);

      final List<TransferTarget> targets = await container.read(
        targetLocationsProvider(
          const TransferTargetQuery(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
          ),
        ).future,
      );

      expect(targets.first.alreadyHoldsProduct, isTrue);
      expect(targets.first.summary.location.code, 'B-03-02');
    });
  });

  group('Miktar sınırı', () {
    testWidgets('kaynak seçilmeden miktar alanı kapalı', (
      WidgetTester tester,
    ) async {
      await openTransferForIphone(tester);

      final QuantitySelector selector = tester.widget<QuantitySelector>(
        find.byType(QuantitySelector),
      );
      expect(selector.enabled, isFalse);
      expect(selector.max, isNull);
    });

    testWidgets('miktar kaynaktaki stokla sınırlı', (
      WidgetTester tester,
    ) async {
      // Negatif stok oluşamaz (şartname 26. bölüm).
      await openTransferForIphone(tester);

      await selectSource(tester, 'loc-a0101');

      // Hedef listesi açıldığı için miktar alanı aşağı iner.
      await tester.scrollUntilVisible(
        find.byType(QuantitySelector),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final QuantitySelector selector = tester.widget<QuantitySelector>(
        find.byType(QuantitySelector),
      );
      expect(selector.enabled, isTrue);
      expect(selector.max, 18);
    });
  });

  group('Hedef listesi', () {
    testWidgets('seçimden sonra daralır ve geri açılabilir', (
      WidgetTester tester,
    ) async {
      // On dört satırlık liste açık kalınca miktar adımı ekranın çok
      // altında kalıyordu.
      await openTransferForIphone(tester);
      await selectSource(tester, 'loc-a0101');

      // Kaynak hariç 14 lokasyon.
      expect(find.byKey(const ValueKey<String>('target-loc-m01')), findsOne);

      await selectTarget(tester, 'loc-b0302');

      expect(
        find.byKey(const ValueKey<String>('target-loc-b0302')),
        findsOne,
      );
      expect(find.byKey(const ValueKey<String>('target-loc-m01')), findsNothing);
      expect(find.textContaining('Başka raf seç'), findsOneWidget);

      await tester.tap(find.textContaining('Başka raf seç'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('target-loc-m01')), findsOne);
    });
  });

  group('Önizleme', () {
    testWidgets('öncesi/sonrası işlemden önce gösterilir', (
      WidgetTester tester,
    ) async {
      // Şartname 15: "A-01-01: 18 → 13, B-03-02: 6 → 11".
      await openTransferForIphone(tester);

      await selectSource(tester, 'loc-a0101');
      await selectTarget(tester, 'loc-b0302');

      await tester.scrollUntilVisible(
        find.text('TRANSFER SONRASI'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Varsayılan miktar 1: 18 → 17, 6 → 7.
      expect(find.text('18'), findsWidgets);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('7'), findsWidgets);
      expect(find.textContaining('Toplam stok değişmez'), findsOneWidget);
    });

    testWidgets('transfer başlatma kaynak ve hedef olmadan kapalı', (
      WidgetTester tester,
    ) async {
      await openTransferForIphone(tester);

      final PrimaryButton before = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Transferi Başlat'),
      );
      expect(before.onPressed, isNull);

      await selectSource(tester, 'loc-a0101');
      await selectTarget(tester, 'loc-b0302');

      final PrimaryButton after = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Transferi Başlat'),
      );
      expect(after.onPressed, isNotNull);
    });
  });

  group('Uçtan uca transfer', () {
    testWidgets('iki lokasyon değişir, toplam sabit kalır', (
      WidgetTester tester,
    ) async {
      // Şartname 27, Demo 4.
      final ProviderContainer container = await openTransferForIphone(tester);

      await selectSource(tester, 'loc-a0101');
      await selectTarget(tester, 'loc-b0302');

      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Transferi Başlat'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transferi onayla'), findsOneWidget);
      // Onay kutusu somut özeti taşır: "A-01-01  18 → 17".
      expect(find.textContaining('18 → 17'), findsOneWidget);
      expect(find.textContaining('6 → 7'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationDialog),
          matching: find.widgetWithText(FilledButton, 'Transfer Et'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transfer tamamlandı'), findsOneWidget);

      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      expect(after.totalQuantity, 24, reason: 'Toplam değişmemeli');
      expect(
        after.locations
            .firstWhere((LocationStock l) => l.location.code == 'A-01-01')
            .quantity,
        17,
      );
      expect(
        after.locations
            .firstWhere((LocationStock l) => l.location.code == 'B-03-02')
            .quantity,
        7,
      );
    });
  });

  group('İş kuralları (şartname 26. bölüm)', () {
    test('transfer toplamı değiştirmez, hareket oluşturur', () async {
      final ProviderContainer container = makeContainer();

      final int totalBefore = (await container.read(
        productSummaryProvider('p-01').future,
      ))!.totalQuantity;

      await container.read(warehouseActionsProvider).transferStock(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
            targetLocationId: 'loc-b0302',
            quantity: 5,
          );

      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      expect(after.totalQuantity, totalBefore);

      // Şartname 15: hareket geçmişine "TRANSFER / A-01-01 → B-03-02".
      final List<MovementDetail> movements = await container
          .read(movementRepositoryProvider)
          .getMovementsForProduct('p-01', limit: 1);
      expect(movements.first.movement.type, MovementType.transfer);
      expect(movements.first.movement.quantity, 5);
      expect(movements.first.routeLabel, 'A-01-01 → B-03-02');
    });

    test('kaynaktan fazla transfer edilemez', () async {
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).transferStock(
              productId: 'p-01',
              sourceLocationId: 'loc-a0101',
              targetLocationId: 'loc-b0302',
              quantity: 19,
            ),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('aynı lokasyona transfer edilemez', () async {
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).transferStock(
              productId: 'p-01',
              sourceLocationId: 'loc-a0101',
              targetLocationId: 'loc-a0101',
              quantity: 1,
            ),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('transfer dashboard toplam stoğunu değiştirmez', () async {
      final ProviderContainer container = makeContainer();

      final DashboardSummary before = await container.read(
        dashboardSummaryProvider.future,
      );

      await container.read(warehouseActionsProvider).transferStock(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
            targetLocationId: 'loc-b0302',
            quantity: 5,
          );

      final DashboardSummary after = await container.read(
        dashboardSummaryProvider.future,
      );

      expect(after.totalStock, before.totalStock);
      expect(after.todayMovementCount, before.todayMovementCount + 1);
    });
  });
}
