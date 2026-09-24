import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/app/theme/status_tone_colors.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/data/warehouse_exception.dart';
import 'package:warehouse_management_system/features/dashboard/providers/dashboard_providers.dart';
import 'package:warehouse_management_system/features/orders/providers/order_providers.dart';
import 'package:warehouse_management_system/features/shipments/providers/shipment_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Sevkiyat modülünü doğrular (şartname 17. bölüm).
///
/// Sevkin diğer işlemlerden farkı **stok hareketi üretmemesi**: mal zaten
/// toplama sırasında raftan düşmüştür. Testler bunu ayrıca kontrol eder.
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

  /// Siparişler sekmesinin başlığındaki kamyon ikonuyla açar.
  Future<ProviderContainer> openShipments(WidgetTester tester) async {
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
    await tester.tap(find.byIcon(AppIcons.shipment).first);
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  Future<ProviderContainer> openReadyShipment(WidgetTester tester) async {
    final ProviderContainer container = await openShipments(tester);
    await tester.tap(find.text('SH-2026-013'));
    await tester.pumpAndSettle();
    return container;
  }

  group('Sevkiyat listesi', () {
    testWidgets('siparişler sekmesinden açılır', (WidgetTester tester) async {
      await openShipments(tester);

      expect(find.text('Sevkiyat'), findsWidgets);
      expect(find.text('SH-2026-013'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('açık ve sevk edilmiş kayıtlar ayrı gruplanır', (
      WidgetTester tester,
    ) async {
      await openShipments(tester);

      expect(find.text('AÇIK SEVKİYATLAR'), findsOneWidget);
      expect(find.text('SEVK EDİLENLER'), findsOneWidget);
    });

    testWidgets('satır paket ve kargo bilgisini taşır', (
      WidgetTester tester,
    ) async {
      await openShipments(tester);

      expect(find.text('1 paket'), findsWidgets);
      expect(find.text('Yurtiçi Kargo'), findsOneWidget);
      expect(find.text('Sevke Hazır'), findsOneWidget);
      expect(find.text('Hazırlanıyor'), findsOneWidget);
    });
  });

  group('Sevkiyat detayı', () {
    testWidgets('şartnamedeki yedi alan da bulunur', (
      WidgetTester tester,
    ) async {
      // Sipariş no, müşteri, paket sayısı, ürünler, toplam adet, durum,
      // sevk tarihi.
      await openReadyShipment(tester);

      expect(find.text('Teknoloji Merkezi'), findsOneWidget);
      expect(find.text('#10456'), findsOneWidget);
      expect(find.text('PAKET'), findsOneWidget);
      expect(find.text('TOPLAM'), findsOneWidget);
      expect(find.text('Kargo firması'), findsOneWidget);
      expect(find.text('Sevk tarihi'), findsOneWidget);
      expect(find.text('Henüz sevk edilmedi'), findsOneWidget);
      expect(find.text('Ürünler'), findsOneWidget);
    });

    testWidgets('sevke hazır kayıtta Sevk Et etkin', (
      WidgetTester tester,
    ) async {
      await openReadyShipment(tester);

      final PrimaryButton button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Sevk Et'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('sevk edilmiş kayıtta aksiyon yok, takip numarası var', (
      WidgetTester tester,
    ) async {
      // Şartname 26: sevk edilen sipariş yeniden sevk edilemez.
      await openShipments(tester);
      await tester.scrollUntilVisible(
        find.text('SH-2026-012'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('SH-2026-012'));
      await tester.pumpAndSettle();

      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('Takip numarası'), findsOneWidget);
      expect(find.text('ARS4820193755'), findsWidgets);
    });

    testWidgets('ürün dökümü siparişle birebir örtüşür', (
      WidgetTester tester,
    ) async {
      // Sevkiyat ürün listesini kopyalamaz, siparişten okur; ikisi
      // ayrışırsa sevk edilen ile sipariş edilen farklı olurdu.
      final ProviderContainer container = await openReadyShipment(tester);

      final ShipmentDetail shipment = (await container.read(
        shipmentDetailProvider('shp-013').future,
      ))!;
      final OrderDetail order = (await container.read(
        orderDetailProvider('ord-10456').future,
      ))!;

      expect(shipment.lines.length, order.lines.length);
      expect(shipment.totalQuantity, order.order.totalQuantity);
      for (final OrderLineDetail line in shipment.lines) {
        expect(find.text(line.product.name), findsWidgets);
      }
    });
  });

  group('Demo 6 — uçtan uca sevkiyat (şartname 27. bölüm)', () {
    testWidgets('sevk edilir, durum ve takip numarası oluşur', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openReadyShipment(tester);

      await tester.tap(find.widgetWithText(PrimaryButton, 'Sevk Et'));
      await tester.pumpAndSettle();

      expect(find.text('Sevkiyatı onayla'), findsOneWidget);
      expect(find.text('#10456'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationDialog),
          matching: find.widgetWithText(FilledButton, 'Sevk Et'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sevk edildi'), findsOneWidget);
      expect(find.text('Takip numarası'), findsWidgets);

      final ShipmentDetail after = (await container.read(
        shipmentDetailProvider('shp-013').future,
      ))!;
      expect(after.shipment.status, ShipmentStatus.shipped);
      expect(after.shipment.shippedAt, isNotNull);
      expect(after.shipment.trackingNumber, isNotNull);
      expect(after.order.status, OrderStatus.shipped);
    });
  });

  group('Toplamadan sevkiyata geçiş', () {
    testWidgets('Sevkiyata Geç kayıt açar ve detaya götürür', (
      WidgetTester tester,
    ) async {
      // Şartname 17: "Toplama Tamamlandı → Sevkiyat Hazır → Sevk Onayı".
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

      await tester.tap(find.text('Siparişler').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('#10455'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('#10455'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Sevkiyata Geç'));
      await tester.pumpAndSettle();

      // #10455'in kaydı SH-2026-014; yenisi açılmamalı.
      expect(find.text('SH-2026-014'), findsWidgets);
      expect(find.text('Aras Kargo'), findsOneWidget);
    });
  });

  group('İş kuralları (şartname 26. bölüm)', () {
    test('sevk stok hareketi üretmez', () async {
      // Mal toplama sırasında zaten raftan düştü; ikinci bir hareket aynı
      // malın iki kez çıkmış görünmesine yol açardı.
      final ProviderContainer container = makeContainer();

      final List<MovementDetail> before = await container
          .read(movementRepositoryProvider)
          .getStockMovements();
      final int stockBefore = (await container.read(
        dashboardSummaryProvider.future,
      )).totalStock;

      await container.read(warehouseActionsProvider).shipOrder('shp-013');

      final List<MovementDetail> after = await container
          .read(movementRepositoryProvider)
          .getStockMovements();
      final int stockAfter = (await container.read(
        dashboardSummaryProvider.future,
      )).totalStock;

      expect(after.length, before.length);
      expect(stockAfter, stockBefore);
    });

    test('sevk edilen sipariş yeniden sevk edilemez', () async {
      final ProviderContainer container = makeContainer();

      await container.read(warehouseActionsProvider).shipOrder('shp-013');

      await expectLater(
        container.read(warehouseActionsProvider).shipOrder('shp-013'),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('toplanmamış sipariş için sevkiyat açılamaz', () async {
      // #10452 toplanıyor durumunda, tamamlanmadı.
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).createShipment('ord-10452'),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('sevk sipariş durumunu ve dashboard sayacını günceller', () async {
      final ProviderContainer container = makeContainer();

      final DashboardSummary before = await container.read(
        dashboardSummaryProvider.future,
      );

      await container.read(warehouseActionsProvider).shipOrder('shp-013');

      final DashboardSummary after = await container.read(
        dashboardSummaryProvider.future,
      );
      final OrderDetail order = (await container.read(
        orderDetailProvider('ord-10456').future,
      ))!;

      expect(order.order.status, OrderStatus.shipped);
      expect(order.order.shippedAt, isNotNull);
      expect(after.todayShipmentCount, before.todayShipmentCount + 1);
      expect(after.readyToShipCount, before.readyToShipCount - 1);
    });

    test('toplama biten sipariş sevkiyat bekleyenlerde görünür', () async {
      final ProviderContainer container = makeContainer();

      // #10452'yi baştan sona topla.
      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');
      for (final PickingLine line in task.lines) {
        await container.read(warehouseActionsProvider).pickLine(
              taskId: task.id,
              productId: line.productId,
              quantity: line.requestedQuantity,
            );
      }

      final List<SalesOrder> awaiting = await container.read(
        awaitingShipmentProvider.future,
      );

      expect(
        awaiting.any((SalesOrder o) => o.id == 'ord-10452'),
        isTrue,
        reason: 'Sevkiyat kaydı açılmamış sipariş listede kaybolmamalı',
      );
    });
  });
}
