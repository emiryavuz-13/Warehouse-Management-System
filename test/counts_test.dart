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
import 'package:warehouse_management_system/features/counts/presentation/widgets/difference_label.dart';
import 'package:warehouse_management_system/features/dashboard/providers/dashboard_providers.dart';
import 'package:warehouse_management_system/features/locations/providers/location_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Stok sayımını doğrular (şartname 16. bölüm).
///
/// Sayımın diğer işlemlerden farkı iki aşamalı olması: kayıt stoğu
/// değiştirmez, onay değiştirir. Testler bu ayrımı ayrıca kontrol eder.
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

  /// Dashboard'daki "Sayım" hızlı işlemiyle listeyi açar.
  Future<ProviderContainer> openCounts(WidgetTester tester) async {
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

    await tester.tap(find.text('Sayım'));
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  Future<ProviderContainer> openDemoCount(WidgetTester tester) async {
    final ProviderContainer container = await openCounts(tester);
    await tester.tap(find.text('IC-2026-031'));
    await tester.pumpAndSettle();
    return container;
  }

  group('Sayım listesi', () {
    testWidgets('dashboard üzerinden açılır', (WidgetTester tester) async {
      await openCounts(tester);

      expect(find.text('Stok Sayımı'), findsWidgets);
      expect(find.text('IC-2026-031'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şartnamedeki alanlar satırda bulunur', (
      WidgetTester tester,
    ) async {
      // Sayım numarası, lokasyon, durum.
      await openCounts(tester);

      expect(find.text('IC-2026-031'), findsOneWidget);
      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.text('Devam Ediyor'), findsOneWidget);
      expect(find.text('Bekliyor'), findsOneWidget);
    });

    testWidgets('tamamlanan sayımda fark sayısı gösterilir', (
      WidgetTester tester,
    ) async {
      // "Tamamlandı" rozeti sayımın sonucunu söylemez, sadece bittiğini.
      await openCounts(tester);

      // IC-2026-030: iki üründe fark, IC-2026-029: fark yok.
      expect(find.text('2 üründe fark'), findsOneWidget);
      expect(find.text('Fark yok'), findsOneWidget);
    });

    testWidgets('açık sayımda ilerleme gösterilir', (
      WidgetTester tester,
    ) async {
      await openCounts(tester);

      expect(find.byType(TaskProgressBar), findsWidgets);
      expect(find.text('Sayılan ürün'), findsWidgets);
    });
  });

  group('Sayım ekranı', () {
    testWidgets('şartnamedeki üç sayı her satırda', (
      WidgetTester tester,
    ) async {
      // Sistem stoku, fiziksel sayım, fark.
      await openDemoCount(tester);

      expect(find.text('SİSTEM'), findsWidgets);
      expect(find.text('FİZİKSEL'), findsWidgets);
      expect(find.text('FARK'), findsWidgets);
    });

    testWidgets('sayım lokasyon bazlıdır, ürünün toplamı değil', (
      WidgetTester tester,
    ) async {
      // iPhone 15'in toplam stoğu 24 ama A-01-01 rafında 18 var. Sayan kişi
      // tek bir rafın önünde durur; sistem miktarı o rafınki olmalı.
      await openDemoCount(tester);

      expect(find.text('A-01-01'), findsWidgets);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('24'), findsNothing);
    });

    testWidgets('sayılmayan satır boş görünür', (WidgetTester tester) async {
      // "0 sayıldı" ile "henüz sayılmadı" farklı şeylerdir.
      await openDemoCount(tester);

      expect(find.text('sayılmadı'), findsNWidgets(2));
      expect(find.text('bekliyor'), findsNWidgets(2));
    });

    testWidgets('tüm satırlar sayılmadan tamamlanamaz', (
      WidgetTester tester,
    ) async {
      await openDemoCount(tester);

      final PrimaryButton button = tester.widget<PrimaryButton>(
        find.byType(PrimaryButton),
      );
      expect(button.onPressed, isNull);
      expect(button.label, '2 ürün daha sayılmalı');
    });

    testWidgets('tamamlanmış sayım düzenlenemez', (
      WidgetTester tester,
    ) async {
      await openCounts(tester);
      await tester.tap(find.text('IC-2026-030'));
      await tester.pumpAndSettle();

      // Tamamlanmış kayıtta alt eylem çubuğu hiç çizilmez.
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('Tamamlandı'), findsWidgets);
    });
  });

  group('Sayım girişi paneli', () {
    testWidgets('şartnamenin sayım ekranını gösterir', (
      WidgetTester tester,
    ) async {
      await openDemoCount(tester);

      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();

      expect(find.text('Sistem stoku'.toUpperCase()), findsNothing);
      expect(find.text('SİSTEM STOKU'), findsOneWidget);
      expect(find.text('Raftaki fiziksel miktar'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Sayımı Kaydet'), findsOne);
    });

    testWidgets('varsayılan değer sistem stoğudur', (
      WidgetTester tester,
    ) async {
      // Depo sayımlarının çoğu tutar; sıfırdan saydırmak gereksiz iş.
      await openDemoCount(tester);

      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();

      final QuantitySelector selector = tester.widget<QuantitySelector>(
        find.byType(QuantitySelector),
      );
      expect(selector.value, 18);
      expect(selector.min, 0, reason: 'Raf boş çıkmış olabilir');
    });

    testWidgets('fark canlı hesaplanır ve ne olacağı yazılır', (
      WidgetTester tester,
    ) async {
      await openDemoCount(tester);

      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();

      // 18 → 17: fark -1.
      await tester.tap(find.byIcon(AppIcons.remove).first);
      await tester.pumpAndSettle();

      final DifferenceLabel label = tester.widget<DifferenceLabel>(
        find.byType(DifferenceLabel).first,
      );
      expect(label.value, -1);
      expect(find.textContaining('18 yerine 17'), findsOneWidget);
      expect(find.text('eksik'), findsWidgets);
    });
  });

  group('Demo 5 — uçtan uca sayım (şartname 27. bölüm)', () {
    testWidgets('fark girilir, onaylanır, stok düzeltilir', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openDemoCount(tester);

      // --- iPhone 15: 18 → 17 (fark -1) ---
      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.remove).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Sayımı Kaydet'));
      await tester.pumpAndSettle();

      // Kayıt stoğu henüz değiştirmemeli.
      final ProductStockSummary midway = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      expect(midway.totalQuantity, 24, reason: 'Onaydan önce stok sabit');

      // --- iPhone 15 Pro: fark yok ---
      await tester.tap(find.textContaining('iPhone 15 Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Sayımı Kaydet'));
      await tester.pumpAndSettle();

      // --- Onay ---
      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Sayımı Tamamla'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sayımı onayla'), findsOneWidget);
      // Onay kutusu ne olacağını somut yazar.
      expect(find.text('18 → 17'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationDialog),
          matching: find.widgetWithText(FilledButton, 'Onayla'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sayım tamamlandı'), findsOneWidget);

      // --- Sonuç: stok düzeltildi ---
      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      expect(after.totalQuantity, 23, reason: '24 - 1');
      expect(
        after.locations
            .firstWhere((LocationStock l) => l.location.code == 'A-01-01')
            .quantity,
        17,
      );
    });
  });

  group('İş kuralları (şartname 26. bölüm)', () {
    test('kayıt stoğu değiştirmez, onay değiştirir', () async {
      final ProviderContainer container = makeContainer();

      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-01',
            countedQuantity: 17,
          );

      expect(
        (await container.read(productSummaryProvider('p-01').future))!
            .totalQuantity,
        24,
      );

      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-02',
            countedQuantity: 12,
          );
      await container.read(warehouseActionsProvider).completeCount('ic-031');

      expect(
        (await container.read(productSummaryProvider('p-01').future))!
            .totalQuantity,
        23,
      );
    });

    test('yalnızca farkı olan satır hareket üretir', () async {
      final ProviderContainer container = makeContainer();

      final List<MovementDetail> before = await container
          .read(movementRepositoryProvider)
          .getStockMovements();

      // İki satır sayılır, biri farklı.
      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-01',
            countedQuantity: 17,
          );
      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-02',
            countedQuantity: 12,
          );
      await container.read(warehouseActionsProvider).completeCount('ic-031');

      final List<MovementDetail> after = await container
          .read(movementRepositoryProvider)
          .getStockMovements();

      expect(after.length, before.length + 1);
      expect(
        after.first.movement.type,
        MovementType.countAdjustment,
      );
      expect(after.first.movement.quantity, -1);
    });

    test('eksik sayımda tamamlama reddedilir', () async {
      final ProviderContainer container = makeContainer();

      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-01',
            countedQuantity: 17,
          );

      await expectLater(
        container.read(warehouseActionsProvider).completeCount('ic-031'),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('negatif sayım reddedilir', () async {
      final ProviderContainer container = makeContainer();

      await expectLater(
        container.read(warehouseActionsProvider).recordCount(
              countId: 'ic-031',
              productId: 'p-01',
              countedQuantity: -1,
            ),
        throwsA(isA<WarehouseException>()),
      );
    });

    test('sayım lokasyonun doluluğunu ve dashboard toplamını günceller',
        () async {
      // Şartname 24: işlem tüm ekranlara yansımalı.
      final ProviderContainer container = makeContainer();

      final DashboardSummary beforeSummary = await container.read(
        dashboardSummaryProvider.future,
      );
      final LocationSummary beforeLocation = (await container.read(
        locationSummaryProvider('loc-a0101').future,
      ))!;

      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-01',
            countedQuantity: 17,
          );
      await container.read(warehouseActionsProvider).recordCount(
            countId: 'ic-031',
            productId: 'p-02',
            countedQuantity: 12,
          );
      await container.read(warehouseActionsProvider).completeCount('ic-031');

      final DashboardSummary afterSummary = await container.read(
        dashboardSummaryProvider.future,
      );
      final LocationSummary afterLocation = (await container.read(
        locationSummaryProvider('loc-a0101').future,
      ))!;

      expect(afterSummary.totalStock, beforeSummary.totalStock - 1);
      expect(afterLocation.usedQuantity, beforeLocation.usedQuantity - 1);
    });
  });
}
