import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/features/dashboard/providers/dashboard_providers.dart';
import 'package:warehouse_management_system/features/receiving/providers/receiving_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Mal kabul ve yerleştirme modülünü doğrular (şartname 11-12. bölümler).
///
/// Bu modül uygulamanın **ilk gerçek yazma işlemi**. Testlerin ağırlığı bu
/// yüzden arayüzde değil sonuçta: şartname 24. bölüm "işlem sadece mesaj
/// göstermemeli, state gerçekten değişmeli" diyor. Stok artıyor mu, hareket
/// oluşuyor mu, durum güncelleniyor mu — hepsi ayrı ayrı doğrulanır.
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

  Future<ProviderContainer> openReceiving(WidgetTester tester) async {
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

    // Dashboard'daki "Mal Kabul" hızlı işlemi.
    await tester.tap(find.text('Mal Kabul'));
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  group('Mal kabul listesi', () {
    testWidgets('dashboard üzerinden açılır', (WidgetTester tester) async {
      await openReceiving(tester);

      expect(find.text('Mal Kabul'), findsWidgets);
      expect(find.text('GR-1024'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şartnamedeki alanlar satırda bulunur', (
      WidgetTester tester,
    ) async {
      // Kabul numarası, tedarikçi, beklenen/kabul edilen, durum, tarih.
      await openReceiving(tester);

      expect(find.text('GR-1024'), findsOneWidget);
      expect(find.text('ABC Elektronik'), findsOneWidget);
      expect(find.text('0 / 50'), findsOneWidget);
      expect(find.text('Bekliyor'), findsWidgets);
      expect(find.text('1 kalem'), findsWidgets);
    });

    testWidgets('açık ve tamamlanan kayıtlar ayrı gruplanır', (
      WidgetTester tester,
    ) async {
      await openReceiving(tester);

      expect(find.text('AÇIK KAYITLAR'), findsOneWidget);
      expect(find.text('TAMAMLANANLAR'), findsOneWidget);
    });
  });

  group('Mal kabul detayı', () {
    Future<ProviderContainer> openGr1024(WidgetTester tester) async {
      final ProviderContainer container = await openReceiving(tester);
      await tester.tap(find.text('GR-1024'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('şartnamenin örnek kaydını gösterir', (
      WidgetTester tester,
    ) async {
      // Mal Kabul #GR-1024 / ABC Elektronik / iPhone 15 / Beklenen 50.
      await openGr1024(tester);

      expect(find.text('ABC Elektronik'), findsOneWidget);
      expect(find.text('Kabul edilen adet'), findsOneWidget);
      expect(find.text('0 / 50'), findsOneWidget);
      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
      expect(find.text('50 kaldı'), findsOneWidget);
    });

    testWidgets('satıra dokunmak yerleştirme ekranını açar', (
      WidgetTester tester,
    ) async {
      await openGr1024(tester);

      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();

      expect(find.text('Ürün Yerleştirme'), findsOneWidget);
      expect(find.text('Lokasyon Seç'), findsOneWidget);
    });
  });

  group('Yerleştirme ekranı', () {
    Future<ProviderContainer> openPutaway(WidgetTester tester) async {
      final ProviderContainer container = await openReceiving(tester);
      await tester.tap(find.text('GR-1024'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('beklenen/kabul edilen/kalan blokları gösterilir', (
      WidgetTester tester,
    ) async {
      await openPutaway(tester);

      expect(find.text('BEKLENEN'), findsOneWidget);
      expect(find.text('KABUL EDİLEN'), findsOneWidget);
      expect(find.text('KALAN'), findsOneWidget);
    });

    testWidgets('varsayılan miktar kalan adettir', (
      WidgetTester tester,
    ) async {
      // Depoda en sık yapılan iş gelen malın tamamını kabul etmek.
      await openPutaway(tester);

      final QuantitySelector selector = tester.widget<QuantitySelector>(
        find.byType(QuantitySelector),
      );
      expect(selector.value, 50);
    });

    testWidgets('lokasyon seçilmeden yerleştirilemez', (
      WidgetTester tester,
    ) async {
      await openPutaway(tester);

      final PrimaryButton button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Yerleştir'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('şartnamenin istediği lokasyon bilgileri gösterilir', (
      WidgetTester tester,
    ) async {
      // Bölge, lokasyon kodu, doluluk ve ürün sayısı.
      await openPutaway(tester);
      await tester.scrollUntilVisible(
        find.text('Lokasyon Seç'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(OccupancyBar), findsWidgets);
      expect(find.textContaining('ürün ·'), findsWidgets);
      expect(find.textContaining('boş'), findsWidgets);
    });

    testWidgets('ürünün bulunduğu raf önerilir', (WidgetTester tester) async {
      // Gerçek depoda aynı ürün mümkün olduğunca tek yerde toplanır.
      final ProviderContainer container = await openPutaway(tester);

      final List<PutawayLocation> options = await container.read(
        putawayLocationsProvider('p-01').future,
      );
      expect(options.first.alreadyHoldsProduct, isTrue);
      expect(
        options.first.summary.location.code,
        anyOf('A-01-01', 'B-03-02'),
      );
    });
  });

  group('Uçtan uca kabul akışı', () {
    testWidgets('yerleştirme stoğu artırır ve yeni toplamı gösterir', (
      WidgetTester tester,
    ) async {
      // Şartname 27, Demo 2: Mal Kabul → GR-1024 → 50 adet → A-01-01 →
      // kabul → stok artışı görünür.
      //
      // Bu test bir hatayı da bekçiliyor: başarı mesajı yazma işleminden
      // hemen sonra `.value` okursa önbellekteki eski stoğu (24) gösterir.
      final ProviderContainer container = await openReceiving(tester);

      await tester.tap(find.text('GR-1024'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('A-01-01'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('A-01-01'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Yerleştir'));
      await tester.pumpAndSettle();

      // Onay kutusu somut özeti gösterir (şartname 30. bölüm).
      expect(find.text('Yerleştirmeyi onayla'), findsOneWidget);
      expect(find.text('50 adet'), findsWidgets);
      expect(find.text('A-01-01'), findsWidgets);

      // "Yerleştir" hem alt bardaki butonda hem onay kutusunda var;
      // hedef açıkça onay kutusunun içinden seçilir.
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationDialog),
          matching: find.widgetWithText(FilledButton, 'Yerleştir'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yerleştirme tamamlandı'), findsOneWidget);
      // 24 + 50 = 74. Eski önbellek okunsaydı burada 24 yazardı.
      expect(find.text('74 adet'), findsOneWidget);

      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      expect(after.totalQuantity, 74);
    });
  });

  group('Kabul işlemi state değiştirir (şartname 24. bölüm)', () {
    test('stok artar, hareket oluşur, durum güncellenir', () async {
      final ProviderContainer container = makeContainer();

      final ProductStockSummary before = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      // Tüm hareketler okunur; dashboard'un "son hareketler" listesi
      // beşle sınırlı olduğu için sayı orada değişmez görünürdü.
      final List<MovementDetail> movementsBefore = await container
          .read(movementRepositoryProvider)
          .getStockMovements();
      expect(before.totalQuantity, 24);

      await container.read(warehouseActionsProvider).receiveGoods(
            receiptId: 'gr-1024',
            productId: 'p-01',
            quantity: 50,
            targetLocationId: 'loc-a0101',
          );

      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      final List<MovementDetail> movementsAfter = await container
          .read(movementRepositoryProvider)
          .getStockMovements();
      final ReceiptDetail detail = (await container.read(
        receiptDetailProvider('gr-1024').future,
      ))!;

      // 1. Stok arttı.
      expect(after.totalQuantity, 74);
      // 2. Tam olarak bir hareket oluştu ve türü mal kabul.
      expect(movementsAfter.length, movementsBefore.length + 1);
      expect(movementsAfter.first.movement.type, MovementType.goodsReceipt);
      expect(movementsAfter.first.movement.quantity, 50);
      // 3. Kayıt tamamlandı.
      expect(detail.receipt.status, ReceiptStatus.completed);
      expect(detail.receipt.totalReceived, 50);
      expect(detail.lines.first.targetLocation?.id, 'loc-a0101');
    });

    test('kabul dashboard özetine yansır', () async {
      // Şartname 24: "tüm ekranlar buna tepki vermeli".
      final ProviderContainer container = makeContainer();

      final DashboardSummary before = await container.read(
        dashboardSummaryProvider.future,
      );

      await container.read(warehouseActionsProvider).receiveGoods(
            receiptId: 'gr-1024',
            productId: 'p-01',
            quantity: 50,
            targetLocationId: 'loc-a0101',
          );

      final DashboardSummary after = await container.read(
        dashboardSummaryProvider.future,
      );

      expect(after.totalStock, before.totalStock + 50);
      expect(after.todayMovementCount, before.todayMovementCount + 1);
    });

    test('fazla kabul engellenmez ama işaretlenir', () async {
      // Şartname 26: gerçek depoda fazla mal gelebilir, kapıda bekletilemez.
      final ProviderContainer container = makeContainer();

      await container.read(warehouseActionsProvider).receiveGoods(
            receiptId: 'gr-1024',
            productId: 'p-01',
            quantity: 55,
            targetLocationId: 'loc-a0101',
          );

      final ReceiptDetail detail = (await container.read(
        receiptDetailProvider('gr-1024').future,
      ))!;

      expect(detail.receipt.totalReceived, 55);
      expect(detail.receipt.hasOverReceipt, isTrue);
      expect(detail.lines.first.line.isOverReceived, isTrue);
    });

    test('kısmi kabulde kayıt açık kalır', () async {
      final ProviderContainer container = makeContainer();

      await container.read(warehouseActionsProvider).receiveGoods(
            receiptId: 'gr-1024',
            productId: 'p-01',
            quantity: 20,
            targetLocationId: 'loc-a0101',
          );

      final ReceiptDetail detail = (await container.read(
        receiptDetailProvider('gr-1024').future,
      ))!;

      expect(detail.receipt.status, ReceiptStatus.receiving);
      expect(detail.lines.first.line.remainingQuantity, 30);
    });

    test('yerleştirme adayları yalnızca kullanıcının deposundan', () async {
      final ProviderContainer container = makeContainer();

      final List<PutawayLocation> options = await container.read(
        putawayLocationsProvider('p-01').future,
      );

      expect(options, isNotEmpty);
      expect(
        options.every(
          (PutawayLocation l) => l.summary.location.warehouseId == 'w-01',
        ),
        isTrue,
      );
    });

    test('kapasitesi yetmeyen rafa yerleştirilemez', () async {
      final ProviderContainer container = makeContainer();

      final List<PutawayLocation> options = await container.read(
        putawayLocationsProvider('p-01').future,
      );
      final PutawayLocation tight = options.last;

      expect(
        tight.fits(tight.summary.availableCapacity + 1),
        isFalse,
        reason: 'Kapasite kontrolü arayüzde de yapılmalı',
      );

      await expectLater(
        container.read(warehouseActionsProvider).receiveGoods(
              receiptId: 'gr-1024',
              productId: 'p-01',
              quantity: tight.summary.availableCapacity + 1,
              targetLocationId: tight.summary.location.id,
            ),
        throwsA(isA<Object>()),
      );
    });
  });
}
