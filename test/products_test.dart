import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/repositories/repositories.dart';
import 'package:warehouse_management_system/models/models.dart';
import 'package:warehouse_management_system/features/products/providers/product_providers.dart';

/// Ürünler modülünü uçtan uca doğrular (şartname 8. bölüm).
///
/// Testler gerçek uygulamayı gerçek mock veriyle açıp dashboard'dan ürün
/// listesine geçiyor; böylece navigasyon zinciri de kapsanıyor.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
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

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  /// Dashboard'daki "ÜRÜN" bloğuna dokunarak ürün listesini açar.
  Future<ProviderContainer> openProductList(WidgetTester tester) async {
    final ProviderContainer container = await pumpApp(tester);
    await tester.tap(find.text('ÜRÜN'));
    await tester.pumpAndSettle();
    return container;
  }

  group('Ürün listesi', () {
    testWidgets('dashboard üzerinden açılır ve ürünleri listeler', (
      WidgetTester tester,
    ) async {
      await openProductList(tester);

      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.byType(ProductCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sonuç özeti ürün ve adet sayısını gösterir', (
      WidgetTester tester,
    ) async {
      await openProductList(tester);

      // 15 ürün, 496 adet toplam stok.
      expect(find.textContaining('15 ürün'), findsOneWidget);
      expect(find.textContaining('496 adet'), findsOneWidget);
    });

    testWidgets('uyarı sayısı listede gösterilir', (WidgetTester tester) async {
      await openProductList(tester);

      // 4 kritik + 1 tükenmiş.
      expect(find.text('5 uyarı'), findsOneWidget);
    });

    testWidgets('varsayılan sıralama ada göre', (WidgetTester tester) async {
      final ProviderContainer container = await openProductList(tester);

      expect(container.read(productFilterProvider).sort, ProductSort.nameAsc);
    });
  });

  group('Arama', () {
    testWidgets('ürün adına göre filtreler', (WidgetTester tester) async {
      await openProductList(tester);

      await tester.enterText(find.byType(TextField).first, 'iphone');
      // Arama gecikmeli; süreyi geçmek gerekir.
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.textContaining('iPhone 15'), findsWidgets);
      expect(find.textContaining('MacBook'), findsNothing);
    });

    testWidgets('SKU ile arama çalışır', (WidgetTester tester) async {
      // Şartname 31: arama SKU üzerinde de çalışmalı.
      await openProductList(tester);

      await tester.enterText(find.byType(TextField).first, 'LOGI-MX3S');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.textContaining('MX Master'), findsOneWidget);
      expect(find.textContaining('1 ürün'), findsOneWidget);
    });

    testWidgets('barkod ile arama çalışır', (WidgetTester tester) async {
      await openProductList(tester);

      await tester.enterText(find.byType(TextField).first, '8691234567890');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
    });

    testWidgets('sonuç yoksa açıklayıcı boş durum gösterilir', (
      WidgetTester tester,
    ) async {
      await openProductList(tester);

      await tester.enterText(find.byType(TextField).first, 'bulunmayanurun');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('Sonuç bulunamadı'), findsOneWidget);
      // Aranan metin hem arama kutusunda hem mesajda geçtiği için
      // mesajın kendine özgü kısmı aranır.
      expect(find.textContaining('için eşleşen kayıt yok'), findsOneWidget);
    });
  });

  group('Filtreler', () {
    testWidgets('stok durumu filtresi uygulanır', (WidgetTester tester) async {
      final ProviderContainer container = await openProductList(tester);

      container
          .read(productFilterProvider.notifier)
          .toggleStatus(StockStatus.outOfStock);
      await tester.pumpAndSettle();

      // Yalnızca tükenen ürün kalır.
      expect(find.textContaining('1 ürün'), findsOneWidget);
      expect(find.textContaining('ThinkPad'), findsOneWidget);
    });

    testWidgets('etkin filtre çipi gösterilir ve kaldırılabilir', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openProductList(tester);

      container
          .read(productFilterProvider.notifier)
          .toggleStatus(StockStatus.critical);
      await tester.pumpAndSettle();

      expect(find.byType(RemovableChip), findsOneWidget);

      await tester.tap(find.byType(RemovableChip));
      await tester.pumpAndSettle();

      expect(find.byType(RemovableChip), findsNothing);
      expect(container.read(productFilterProvider).status, isNull);
    });

    testWidgets('filtre temizlenince arama korunur', (
      WidgetTester tester,
    ) async {
      // Kullanıcı "temizle"ye bastığında yazdığı aramayı kaybetmeyi
      // beklemez; sadece daralttığı filtreleri geri almak ister.
      final ProviderContainer container = await openProductList(tester);
      final ProductFilterController controller = container.read(
        productFilterProvider.notifier,
      );

      controller.setQuery('logitech');
      controller.toggleStatus(StockStatus.critical);
      await tester.pumpAndSettle();

      controller.clearFilters();
      await tester.pumpAndSettle();

      expect(container.read(productFilterProvider).query, 'logitech');
      expect(container.read(productFilterProvider).status, isNull);
    });

    testWidgets('sıralama stoğu çok olandan aza çevrilebilir', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openProductList(tester);

      container
          .read(productFilterProvider.notifier)
          .setSort(ProductSort.stockDesc);
      await tester.pumpAndSettle();

      // En çok stoklu ürün USB-C kablo (245 adet, M-01 dahil).
      final ProductCard first = tester.widget<ProductCard>(
        find.byType(ProductCard).first,
      );
      expect(first.summary.product.sku, 'USBC-CBL-2M');
    });
  });

  group('Ürün detayı', () {
    Future<void> openDetail(WidgetTester tester, String productName) async {
      await openProductList(tester);
      await tester.tap(find.textContaining(productName).first);
      await tester.pumpAndSettle();
    }

    testWidgets('toplam stok hero figürü olarak gösterilir', (
      WidgetTester tester,
    ) async {
      await openDetail(tester, 'iPhone 15 128GB');

      expect(find.text('Ürün Detayı'), findsOneWidget);
      expect(find.byType(HeroFigure), findsOneWidget);
      expect(find.text('toplam stok'), findsOneWidget);
      // iPhone 15: 18 + 6 = 24 adet.
      expect(find.text('24'), findsOneWidget);
    });

    testWidgets('lokasyon bazlı stok dökümü gösterilir', (
      WidgetTester tester,
    ) async {
      // Şartname 8: "Lokasyonlar A-01-01 → 18, B-03-02 → 6".
      await openDetail(tester, 'iPhone 15 128GB');

      expect(find.text('Lokasyonlar'), findsOneWidget);
      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.text('B-03-02'), findsOneWidget);
      expect(find.text('18 adet'), findsOneWidget);
      expect(find.text('6 adet'), findsOneWidget);
    });

    testWidgets('ürün bilgileri eksiksiz', (WidgetTester tester) async {
      await openDetail(tester, 'iPhone 15 128GB');
      await tester.scrollUntilVisible(
        find.text('Ürün Bilgileri'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('SKU'), findsOneWidget);
      expect(find.text('Barkod'), findsOneWidget);
      expect(find.text('Marka'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Birim'), findsOneWidget);
      expect(find.text('Minimum stok'), findsOneWidget);
      expect(find.text('IP15-128-BLK'), findsOneWidget);
      expect(find.text('8691234567890'), findsOneWidget);
    });

    testWidgets('son hareketler listelenir', (WidgetTester tester) async {
      await openDetail(tester, 'iPhone 15 128GB');
      await tester.scrollUntilVisible(
        find.text('Son Hareketler'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Son Hareketler'), findsOneWidget);
      // iPhone'un transfer ve mal kabul hareketleri var.
      expect(find.text('Transfer'), findsWidgets);
    });

    testWidgets('stoksuz üründe transfer butonu devre dışı', (
      WidgetTester tester,
    ) async {
      // Butonu gizlemek yerine devre dışı bırakmak, kullanıcıya neden
      // yapamadığını sormadan gösterir.
      await openDetail(tester, 'Lenovo ThinkPad');

      final PrimaryButton button = tester.widget<PrimaryButton>(
        find.byType(PrimaryButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('stoklu üründe transfer butonu etkin', (
      WidgetTester tester,
    ) async {
      await openDetail(tester, 'iPhone 15 128GB');

      final PrimaryButton button = tester.widget<PrimaryButton>(
        find.byType(PrimaryButton),
      );
      expect(button.onPressed, isNotNull);
      expect(button.label, 'Stok Transfer Et');
    });

    testWidgets('kritik üründe durum rozeti gösterilir', (
      WidgetTester tester,
    ) async {
      await openDetail(tester, 'Logitech MX Master');

      expect(find.text('Kritik'), findsWidgets);
    });
  });
}
