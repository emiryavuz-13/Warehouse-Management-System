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
import 'package:warehouse_management_system/features/orders/providers/order_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Sipariş ve toplama modülünü doğrular (şartname 13-14. bölümler).
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

  Future<ProviderContainer> openOrders(WidgetTester tester) async {
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

    await tester.tap(find.text('Siparişler').last);
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  Future<ProviderContainer> openOrder10452(WidgetTester tester) async {
    final ProviderContainer container = await openOrders(tester);
    await tester.tap(find.text('#10452'));
    await tester.pumpAndSettle();
    return container;
  }

  group('Sipariş listesi', () {
    testWidgets('bottom bar sekmesinden açılır', (WidgetTester tester) async {
      await openOrders(tester);

      expect(find.text('Siparişler'), findsWidgets);
      expect(find.byType(OrderCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şartnamedeki alanlar satırda bulunur', (
      WidgetTester tester,
    ) async {
      // Sipariş numarası, müşteri, ürün sayısı, toplam adet, durum, tarih.
      await openOrders(tester);

      expect(find.text('#10452'), findsOneWidget);
      expect(find.text('ABC Teknoloji'), findsOneWidget);
      expect(find.text('3 çeşit'), findsWidgets);
      expect(find.text('Toplanıyor'), findsWidgets);
    });

    testWidgets('özet açık ve acil sipariş sayısını verir', (
      WidgetTester tester,
    ) async {
      await openOrders(tester);

      // 10 sipariş; sevk edilen 2 + iptal 1 kapalı → 7 açık.
      expect(find.textContaining('10 sipariş'), findsOneWidget);
      expect(find.textContaining('7 açık'), findsOneWidget);
      // #10460 ve #10455 acil, ikisi de kapalı değil.
      expect(find.text('2 acil'), findsOneWidget);
    });

    testWidgets('arama müşteri adında çalışır', (WidgetTester tester) async {
      await openOrders(tester);

      await tester.enterText(find.byType(TextField).first, 'deniz');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('#10454'), findsOneWidget);
      expect(find.text('#10452'), findsNothing);
    });
  });

  group('Filtreler', () {
    testWidgets('durum filtresi çoklu seçimdir', (WidgetTester tester) async {
      // Depo sorumlusu tek bir duruma değil bir kümeye bakar.
      final ProviderContainer container = await openOrders(tester);
      final OrderFilterController controller = container.read(
        orderFilterProvider.notifier,
      );

      controller.toggleStatus(OrderStatus.newOrder);
      controller.toggleStatus(OrderStatus.picking);
      await tester.pumpAndSettle();

      expect(
        container.read(orderFilterProvider).statuses,
        <OrderStatus>{OrderStatus.newOrder, OrderStatus.picking},
      );
      // 3 yeni + 2 toplanıyor.
      expect(find.byType(OrderCard), findsNWidgets(5));
      expect(find.byType(RemovableChip), findsNWidgets(2));
    });

    testWidgets('öncelik filtresi uygulanır', (WidgetTester tester) async {
      final ProviderContainer container = await openOrders(tester);

      container
          .read(orderFilterProvider.notifier)
          .togglePriority(OrderPriority.urgent);
      await tester.pumpAndSettle();

      expect(find.byType(OrderCard), findsNWidgets(2));
      expect(find.text('#10460'), findsOneWidget);
    });

    testWidgets('filtre temizlenince arama korunur', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openOrders(tester);
      final OrderFilterController controller = container.read(
        orderFilterProvider.notifier,
      );

      controller.setQuery('abc');
      controller.toggleStatus(OrderStatus.picking);
      await tester.pumpAndSettle();

      controller.clearFilters();
      await tester.pumpAndSettle();

      expect(container.read(orderFilterProvider).query, 'abc');
      expect(container.read(orderFilterProvider).statuses, isEmpty);
    });
  });

  group('Sipariş detayı', () {
    testWidgets('şartnamedeki örnek siparişi gösterir', (
      WidgetTester tester,
    ) async {
      // Sipariş #10452 / ABC Teknoloji / 3 ürün / Toplanıyor.
      await openOrder10452(tester);

      expect(find.text('ABC Teknoloji'), findsOneWidget);
      // Başlıkta ve kod çipinde olmak üzere iki kez.
      expect(find.text('#10452'), findsNWidgets(2));
      expect(find.text('Toplanıyor'), findsOneWidget);
      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
      expect(find.textContaining('USB-C Kablo'), findsOneWidget);
      expect(find.textContaining('MX Master'), findsOneWidget);
    });

    testWidgets('satırlar istenen miktarı gösterir', (
      WidgetTester tester,
    ) async {
      await openOrder10452(tester);

      // iPhone × 2, USB-C × 5, Mouse × 1.
      expect(find.text('2'), findsWidgets);
      expect(find.text('5'), findsWidgets);
      expect(find.text('×'), findsNWidgets(3));
    });

    testWidgets('açık siparişte toplama aksiyonu bulunur', (
      WidgetTester tester,
    ) async {
      await openOrder10452(tester);

      // Görev zaten açıksa etiket "devam et" olur.
      expect(
        find.widgetWithText(PrimaryButton, 'Toplamaya Devam Et'),
        findsOneWidget,
      );
    });

    testWidgets('sevk edilmiş siparişte aksiyon yok', (
      WidgetTester tester,
    ) async {
      await openOrders(tester);
      await tester.scrollUntilVisible(
        find.text('#10457'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('#10457'));
      await tester.pumpAndSettle();

      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('Sevk Edildi'), findsOneWidget);
    });

    testWidgets('toplanmış siparişte sevkiyat aksiyonu', (
      WidgetTester tester,
    ) async {
      await openOrders(tester);
      await tester.scrollUntilVisible(
        find.text('#10455'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('#10455'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(PrimaryButton, 'Sevkiyata Geç'),
        findsOneWidget,
      );
    });
  });

  group('Toplama ekranı', () {
    Future<ProviderContainer> openPicking(WidgetTester tester) async {
      final ProviderContainer container = await openOrder10452(tester);
      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Toplamaya Devam Et'),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('şartnamedeki adım ekranını gösterir', (
      WidgetTester tester,
    ) async {
      // "1 / 3", lokasyon, ürün, miktar, iki aksiyon.
      await openPicking(tester);

      // Şartnamenin örneği: "TOPLAMA GÖREVİ #PK-102".
      expect(find.textContaining('Görev PK-102'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('GİT VE AL'), findsOneWidget);
      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SecondaryButton, 'Barkod Tara'),
        findsOneWidget,
      );
    });

    testWidgets('varsayılan miktar kalan adettir', (
      WidgetTester tester,
    ) async {
      await openPicking(tester);

      final QuantitySelector selector = tester.widget<QuantitySelector>(
        find.byType(QuantitySelector),
      );
      expect(selector.value, 2);
      expect(selector.max, 2, reason: 'Siparişte istenenden fazlası alınamaz');
    });

    testWidgets('onaylayınca sonraki adıma geçilir', (
      WidgetTester tester,
    ) async {
      await openPicking(tester);

      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.textContaining('USB-C Kablo'), findsOneWidget);
    });
  });

  group('Demo 3 — uçtan uca toplama (şartname 27. bölüm)', () {
    testWidgets('üç ürün sırayla toplanır, sipariş tamamlanır', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openOrder10452(tester);

      final int stockBefore = (await container.read(
        productSummaryProvider('p-01').future,
      ))!.totalQuantity;

      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Toplamaya Devam Et'),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 3; i++) {
        await tester.tap(
          find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'),
        );
        await tester.pumpAndSettle();
      }

      // Şartname 14: "Sipariş toplama tamamlandı ✓ ... [Sevkiyata Geç]".
      expect(find.text('Sipariş toplama tamamlandı'), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Sevkiyata Geç'),
        findsOneWidget,
      );

      // Stok azaldı.
      final int stockAfter = (await container.read(
        productSummaryProvider('p-01').future,
      ))!.totalQuantity;
      expect(stockAfter, stockBefore - 2);

      // Sipariş durumu güncellendi.
      final OrderDetail detail = (await container.read(
        orderDetailProvider('ord-10452').future,
      ))!;
      expect(detail.order.status, OrderStatus.picked);
      expect(detail.order.isFullyPicked, isTrue);
    });
  });

  group('İş kuralları (şartname 26. bölüm)', () {
    test('toplama stoğu azaltır ve hareket oluşturur', () async {
      final ProviderContainer container = makeContainer();

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');

      final int before = (await container.read(
        productSummaryProvider('p-01').future,
      ))!.totalQuantity;

      await container.read(warehouseActionsProvider).pickLine(
            taskId: task.id,
            productId: 'p-01',
            quantity: 2,
          );

      final int after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!.totalQuantity;
      expect(after, before - 2);

      final List<MovementDetail> movements = await container
          .read(movementRepositoryProvider)
          .getMovementsForProduct('p-01', limit: 1);
      expect(movements.first.movement.type, MovementType.pick);
      expect(movements.first.movement.quantity, -2);
    });

    test('istenenden fazla toplanamaz', () async {
      final ProviderContainer container = makeContainer();

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');

      await expectLater(
        container.read(warehouseActionsProvider).pickLine(
              taskId: task.id,
              productId: 'p-01',
              quantity: 3,
            ),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('sevk edilmiş sipariş yeniden toplanamaz', () async {
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).startPicking('ord-10457'),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('iptal edilmiş sipariş toplanamaz', () async {
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).startPicking('ord-10459'),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('toplama dashboard sayaçlarını günceller', () async {
      // Şartname 24: işlem tüm ekranlara yansımalı.
      final ProviderContainer container = makeContainer();

      final DashboardSummary before = await container.read(
        dashboardSummaryProvider.future,
      );

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10453');
      await container.read(warehouseActionsProvider).pickLine(
            taskId: task.id,
            productId: 'p-05',
            quantity: 1,
          );

      final DashboardSummary after = await container.read(
        dashboardSummaryProvider.future,
      );

      expect(after.totalStock, before.totalStock - 1);
      expect(after.todayMovementCount, before.todayMovementCount + 1);
      // #10453 "Yeni"den "Toplanıyor"a geçti.
      expect(after.pendingOrderCount, before.pendingOrderCount - 1);
      expect(after.pickingOrderCount, before.pickingOrderCount + 1);
    });
  });
}
