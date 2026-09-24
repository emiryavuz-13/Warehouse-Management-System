import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/features/stock/presentation/widgets/stock_row.dart';
import 'package:warehouse_management_system/features/stock/providers/stock_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Stok modülünü uçtan uca doğrular (şartname 9. bölüm).
///
/// Testler gerçek uygulamayı açıp bottom bar'daki "Stok" sekmesine geçiyor;
/// böylece sekmeye bağlanma da kapsanıyor.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<ProviderContainer> openStockTab(WidgetTester tester) async {
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

    // Bottom bar'daki Stok sekmesi.
    await tester.tap(find.text('Stok').last);
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  group('Stok listesi', () {
    testWidgets('sekmeden açılır ve stokları listeler', (
      WidgetTester tester,
    ) async {
      await openStockTab(tester);

      expect(find.byType(StockRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sorunlu stoklar listenin başında', (
      WidgetTester tester,
    ) async {
      // Şartname 9: stok ekranı operasyonel görünüm. Tükenmiş ürün en üstte
      // olmalı, alfabetik sırada değil.
      await openStockTab(tester);

      final StockRow first = tester.widget<StockRow>(
        find.byType(StockRow).first,
      );
      expect(first.summary.status, StockStatus.outOfStock);
      expect(first.summary.product.name, contains('ThinkPad'));
    });

    testWidgets('bağlam satırı toplam adet ve kayıt sayısını gösterir', (
      WidgetTester tester,
    ) async {
      await openStockTab(tester);

      // 496 adet, 25 stok kaydı (ürün-lokasyon çifti).
      expect(find.textContaining('496 adet'), findsOneWidget);
      expect(find.textContaining('25 stok kaydı'), findsOneWidget);
    });

    testWidgets('sıralamanın alfabetik olmadığı kullanıcıya söylenir', (
      WidgetTester tester,
    ) async {
      await openStockTab(tester);

      expect(find.text('sorunlular üstte'), findsOneWidget);
    });
  });

  group('Durum şeridi', () {
    testWidgets('her durumun sayacını gösterir', (WidgetTester tester) async {
      await openStockTab(tester);

      expect(find.text('TÜMÜ'), findsOneWidget);
      expect(find.text('NORMAL'), findsOneWidget);
      // Türkçe büyütme: Dart'ın toUpperCase'i "KRITIK" üretir, bizimki
      // "KRİTİK" (şartname 30. bölüm: arayüz Türkçe).
      expect(find.text('KRİTİK'), findsOneWidget);
      expect(find.text('STOK YOK'), findsOneWidget);

      // 15 ürün: 10 normal, 4 kritik, 1 tükenmiş.
      expect(find.text('15'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('durum bloğuna dokunmak listeyi daraltır', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openStockTab(tester);

      await tester.tap(find.text('KRİTİK'));
      await tester.pumpAndSettle();

      expect(container.read(stockFilterProvider).status, StockStatus.critical);
      expect(find.byType(StockRow), findsNWidgets(4));
    });

    testWidgets('sayaçlar durum filtresinden etkilenmez', (
      WidgetTester tester,
    ) async {
      // Şerit filtrelendikten sonra da tüm resmi göstermeli; aksi halde
      // kullanıcı neyi kaybettiğini göremez.
      final ProviderContainer container = await openStockTab(tester);

      final Map<StockStatus, int> before = container.read(
        stockStatusCountsProvider,
      );

      container
          .read(stockFilterProvider.notifier)
          .toggleStatus(StockStatus.critical);
      await tester.pumpAndSettle();

      expect(container.read(stockStatusCountsProvider), before);
      expect(before[StockStatus.critical], 4);
      expect(before[StockStatus.outOfStock], 1);
      expect(before[StockStatus.normal], 10);
    });

    testWidgets('seçili duruma tekrar dokunmak filtreyi kaldırır', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openStockTab(tester);
      final StockFilterController controller = container.read(
        stockFilterProvider.notifier,
      );

      controller.toggleStatus(StockStatus.critical);
      await tester.pumpAndSettle();
      controller.toggleStatus(StockStatus.critical);
      await tester.pumpAndSettle();

      expect(container.read(stockFilterProvider).status, isNull);
      expect(find.byType(StockRow), findsWidgets);
    });

    testWidgets('boş durumda açıklayıcı mesaj gösterilir', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openStockTab(tester);
      final StockFilterController controller = container.read(
        stockFilterProvider.notifier,
      );

      // A-01-01'de tükenmiş ürün yok; lokasyon + durum birleşimi boş kalır.
      final List<ProductStockSummary> items = container
          .read(stockBaseProvider)
          .value!;
      final String locationId = items
          .firstWhere((ProductStockSummary s) => s.product.id == 'p-01')
          .locations
          .first
          .location
          .id;

      controller.toggleLocation(locationId);
      controller.toggleStatus(StockStatus.outOfStock);
      await tester.pumpAndSettle();

      expect(find.byType(StockRow), findsNothing);
      expect(find.text('Stok Yok ürün yok'), findsOneWidget);
    });
  });

  group('Arama ve filtre', () {
    testWidgets('SKU ile arama çalışır', (WidgetTester tester) async {
      await openStockTab(tester);

      await tester.enterText(find.byType(TextField).first, 'LOGI-MX3S');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.byType(StockRow), findsOneWidget);
      expect(find.textContaining('MX Master'), findsOneWidget);
    });

    testWidgets('filtre temizlenince arama korunur', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openStockTab(tester);
      final StockFilterController controller = container.read(
        stockFilterProvider.notifier,
      );

      controller.setQuery('logitech');
      controller.toggleStatus(StockStatus.critical);
      await tester.pumpAndSettle();

      controller.clearFilters();
      await tester.pumpAndSettle();

      expect(container.read(stockFilterProvider).query, 'logitech');
      expect(container.read(stockFilterProvider).status, isNull);
    });
  });

  group('Satır açılımı', () {
    testWidgets('satır açılınca lokasyon dökümü görünür', (
      WidgetTester tester,
    ) async {
      // Şartname 9: "Aynı ürün birden fazla lokasyonda bulunabiliyorsa
      // bunlar ayrı gösterilmelidir."
      await openStockTab(tester);

      await tester.enterText(find.byType(TextField).first, 'iphone');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.byType(LocationBreakdown), findsNothing);

      await tester.tap(find.textContaining('iPhone 15').first);
      await tester.pumpAndSettle();

      expect(find.byType(LocationBreakdown), findsOneWidget);
      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.text('B-03-02'), findsOneWidget);
      expect(find.text('18 adet'), findsOneWidget);
      expect(find.text('6 adet'), findsOneWidget);
      // Toplam 24'ün payları.
      expect(find.text('%75'), findsOneWidget);
      expect(find.text('%25'), findsOneWidget);
    });

    testWidgets('açık satır tekrar dokunulunca kapanır', (
      WidgetTester tester,
    ) async {
      await openStockTab(tester);

      await tester.enterText(find.byType(TextField).first, 'iphone');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      await tester.tap(find.textContaining('iPhone 15').first);
      await tester.pumpAndSettle();
      expect(find.byType(LocationBreakdown), findsOneWidget);

      await tester.tap(find.textContaining('iPhone 15').first);
      await tester.pumpAndSettle();
      expect(find.byType(LocationBreakdown), findsNothing);
    });

    testWidgets('tek lokasyonlu üründe pay çubuğu çizilmez', (
      WidgetTester tester,
    ) async {
      // Tek satırda %100'lük çubuk bilgi taşımaz.
      await openStockTab(tester);

      await tester.enterText(find.byType(TextField).first, 'LOGI-MX3S');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      await tester.tap(find.textContaining('MX Master'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationBreakdown), findsOneWidget);
      expect(find.text('%100'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('stoksuz üründe transfer devre dışı', (
      WidgetTester tester,
    ) async {
      await openStockTab(tester);

      // Tükenmiş ürün listenin ilk satırı.
      await tester.tap(find.textContaining('ThinkPad'));
      await tester.pumpAndSettle();

      final TextButton transfer = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Transfer'),
      );
      expect(transfer.onPressed, isNull);

      final TextButton detail = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Ürün detayı'),
      );
      expect(detail.onPressed, isNotNull);
    });

    testWidgets('ürün detayına geçiş çalışır', (WidgetTester tester) async {
      await openStockTab(tester);

      await tester.enterText(find.byType(TextField).first, 'iphone');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.tap(find.textContaining('iPhone 15').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ürün detayı'));
      await tester.pumpAndSettle();

      expect(find.text('Ürün Detayı'), findsOneWidget);
      expect(find.byType(HeroFigure), findsOneWidget);
    });
  });

  group('Stok providerları', () {
    test('durum filtresi veri kaynağına gitmez', () async {
      final ProviderContainer container = ProviderContainer(
        retry: noRetryPolicy,
        overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
      );
      addTearDown(container.dispose);

      final List<ProductStockSummary> all = await container.read(
        stockBaseProvider.future,
      );
      expect(all.length, 15);

      container
          .read(stockFilterProvider.notifier)
          .toggleStatus(StockStatus.critical);

      // Temel liste aynı kalır, yalnızca görünen liste daralır.
      expect(container.read(stockBaseProvider).value, all);
      expect(container.read(stockListProvider).value, hasLength(4));
    });
  });
}
