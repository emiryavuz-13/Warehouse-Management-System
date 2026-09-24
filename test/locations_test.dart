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
import 'package:warehouse_management_system/features/locations/providers/location_providers.dart';

/// Lokasyon modülünü doğrular (şartname 18. bölüm).
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

  /// Stok sekmesindeki lokasyon kısayoluyla ekranı açar.
  Future<ProviderContainer> openLocations(WidgetTester tester) async {
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

    await tester.tap(find.text('Stok').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.locations).first);
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  group('Lokasyon ağacı', () {
    testWidgets('stok sekmesinden açılır', (WidgetTester tester) async {
      await openLocations(tester);

      expect(find.text('Lokasyonlar'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şartnamedeki bölgeler başlık olarak gösterilir', (
      WidgetTester tester,
    ) async {
      // Merkez Depo: A, B, C, Mal Kabul, Sevkiyat.
      await openLocations(tester);

      expect(find.text('A BÖLGESİ'), findsOneWidget);
      expect(find.text('B BÖLGESİ'), findsOneWidget);
      expect(find.text('C BÖLGESİ'), findsOneWidget);
    });

    testWidgets('lokasyon satırı şartnamedeki alanları taşır', (
      WidgetTester tester,
    ) async {
      // Kod, doluluk yüzdesi, SKU sayısı, kullanılan/kapasite.
      await openLocations(tester);

      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.byType(OccupancyBar), findsWidgets);
      expect(find.textContaining('ürün ·'), findsWidgets);
    });

    testWidgets('depo özeti bölge ve lokasyon sayısını verir', (
      WidgetTester tester,
    ) async {
      await openLocations(tester);

      // Merkez Depo: 5 bölge, 13 lokasyon.
      expect(find.textContaining('5 bölge'), findsOneWidget);
      expect(find.textContaining('13 lokasyon'), findsOneWidget);
    });

    testWidgets('arama lokasyon koduna göre daraltır', (
      WidgetTester tester,
    ) async {
      await openLocations(tester);

      await tester.enterText(find.byType(TextField).first, 'A-01');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.text('A-01-02'), findsOneWidget);
      expect(find.text('B-01-01'), findsNothing);
      // Sonucu olmayan bölge başlıkları da gizlenir.
      expect(find.text('B BÖLGESİ'), findsNothing);
    });

    testWidgets('sonuç yoksa açıklayıcı boş durum', (
      WidgetTester tester,
    ) async {
      await openLocations(tester);

      await tester.enterText(find.byType(TextField).first, 'Z-99');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('Sonuç bulunamadı'), findsOneWidget);
    });
  });

  group('Depo seçici', () {
    testWidgets('iki depo arasında geçiş yapılır', (
      WidgetTester tester,
    ) async {
      // Mock veride Merkez Depo ve Anadolu Depo var.
      await openLocations(tester);

      expect(find.text('Merkez Depo'), findsWidgets);
      expect(find.text('Anadolu Depo'), findsOneWidget);

      await tester.tap(find.text('Anadolu Depo'));
      await tester.pumpAndSettle();

      expect(find.text('D BÖLGESİ'), findsOneWidget);
      expect(find.text('A BÖLGESİ'), findsNothing);
    });

    testWidgets('depo seçimi uygulamanın çalıştığı depoyu değiştirmez', (
      WidgetTester tester,
    ) async {
      // Lokasyon listesi bir tarama ekranı; operasyon deposunu bozmamalı.
      final ProviderContainer container = await openLocations(tester);
      final String before = container.read(currentWarehouseIdProvider);

      await tester.tap(find.text('Anadolu Depo'));
      await tester.pumpAndSettle();

      expect(container.read(currentWarehouseIdProvider), before);
    });
  });

  group('Lokasyon detayı', () {
    Future<ProviderContainer> openA0101(WidgetTester tester) async {
      final ProviderContainer container = await openLocations(tester);
      await tester.tap(find.text('A-01-01'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('şartnamedeki alanların tamamı bulunur', (
      WidgetTester tester,
    ) async {
      // Kod, bölge, kapasite, doluluk, SKU sayısı, toplam adet.
      await openA0101(tester);

      expect(find.text('A Bölgesi'), findsWidgets);
      expect(find.text('Lokasyon kodu'), findsOneWidget);
      expect(find.text('Kapasite'), findsOneWidget);
      expect(find.text('Farklı ürün'), findsOneWidget);
      expect(find.text('Tip'), findsOneWidget);
      // Doluluk yüzdesi doluluk çubuğunda; InfoRow'da tekrarlanmaz.
      expect(find.byType(OccupancyBar), findsWidgets);
      expect(find.text('%25'), findsOneWidget);
    });

    testWidgets('hero figürü boş kapasiteyi gösterir', (
      WidgetTester tester,
    ) async {
      // Bu ekranın sorusu "buraya daha ne sığar".
      await openA0101(tester);

      expect(find.byType(HeroFigure), findsOneWidget);
      expect(find.text('boş kapasite'), findsOneWidget);
      // A-01-01: 120 kapasite, 30 dolu → 90 boş.
      expect(find.text('90'), findsOneWidget);
      expect(find.text('30 / 120'), findsOneWidget);
    });

    testWidgets('lokasyondaki ürünler listelenir', (
      WidgetTester tester,
    ) async {
      // Şartname 18: "lokasyona girildiğinde o lokasyondaki ürünleri göster".
      await openA0101(tester);
      await tester.scrollUntilVisible(
        find.text('Bu Lokasyondaki Ürünler'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
      expect(find.text('18 adet'), findsOneWidget);
    });

    testWidgets('ürüne dokunmak ürün detayını açar', (
      WidgetTester tester,
    ) async {
      await openA0101(tester);
      await tester.scrollUntilVisible(
        find.textContaining('iPhone 15 128GB'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('iPhone 15 128GB'));
      await tester.pumpAndSettle();

      expect(find.text('Ürün Detayı'), findsOneWidget);
    });
  });

  group('Veri tutarlılığı', () {
    test('ağaçtaki lokasyon sayısı düz listeyle eşleşir', () async {
      final ProviderContainer container = makeContainer();

      final List<ZoneGroup> tree = await container.read(
        locationTreeProvider.future,
      );
      final int inTree = tree.fold(
        0,
        (int sum, ZoneGroup g) => sum + g.locations.length,
      );

      // Merkez Depo'da 13 lokasyon, 5 bölge var (Anadolu Depo'nun iki
      // lokasyonu bu ağaca girmez).
      expect(inTree, 13);
      expect(tree.length, 5);
    });

    test('lokasyon içeriği toplamı doluluğa eşit', () async {
      // Ekranın gösterdiği pay çubukları buna dayanıyor.
      final ProviderContainer container = makeContainer();

      final LocationSummary summary = (await container.read(
        locationSummaryProvider('loc-a0101').future,
      ))!;
      final List<LocationStockLine> lines = await container.read(
        locationContentsProvider('loc-a0101').future,
      );

      final int sum = lines.fold(
        0,
        (int acc, LocationStockLine l) => acc + l.quantity,
      );
      expect(sum, summary.usedQuantity);
      expect(lines.length, summary.skuCount);
    });

    test('transfer sonrası doluluk güncellenir', () async {
      // Şartname 24: işlem tüm ekranlara yansımalı.
      final ProviderContainer container = makeContainer();

      final LocationSummary before = (await container.read(
        locationSummaryProvider('loc-a0101').future,
      ))!;

      await container.read(warehouseActionsProvider).transferStock(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
            targetLocationId: 'loc-b0302',
            quantity: 5,
          );

      final LocationSummary after = (await container.read(
        locationSummaryProvider('loc-a0101').future,
      ))!;

      expect(after.usedQuantity, before.usedQuantity - 5);
      expect(after.availableCapacity, before.availableCapacity + 5);
    });
  });
}
