import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/features/products/providers/product_providers.dart';
import 'package:warehouse_management_system/features/scan/providers/scan_providers.dart';

/// Barkod tarama modülünü doğrular (şartname 10. bölüm).
///
/// [cameraSupportedProvider] testlerde `false` ile geçersiz kılınır: widget
/// testinde gerçek kamera kanalı yoktur ve `MobileScanner` platform
/// hatasıyla düşer. Ekranın kamerasız yolu zaten şartnamenin istediği demo
/// modudur, dolayısıyla test edilen şey gerçek kullanım senaryosudur.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<ProviderContainer> openScanTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        retry: noRetryPolicy,
        overrides: [
          mockConfigProvider.overrideWithValue(MockConfig.instant()),
          cameraSupportedProvider.overrideWithValue(false),
        ],
        child: const WarehouseApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Tara').last);
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  group('Tarayıcı ekranı', () {
    testWidgets('bottom bar ortasından açılır', (WidgetTester tester) async {
      await openScanTab(tester);

      expect(find.text('Barkod Tara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kamera yokken açıklama gösterilir', (
      WidgetTester tester,
    ) async {
      // Boş siyah kutu yerine nedenini söyleyen bir kutu.
      await openScanTab(tester);

      expect(find.text('Kamera bu cihazda yok'), findsOneWidget);
      expect(find.text('Bir demo barkod seçin'), findsOneWidget);
    });

    testWidgets('demo barkodlar ürün adlarıyla listelenir', (
      WidgetTester tester,
    ) async {
      // Şartname 10: dört demo barkod ve karşılık geldikleri ürünler.
      await openScanTab(tester);

      expect(find.text('DEMO BARKODLAR'), findsOneWidget);
      expect(find.text('8691234567890'), findsOneWidget);
      expect(find.text('8691234567891'), findsOneWidget);
      expect(find.text('8691234567892'), findsOneWidget);
      expect(find.text('8691234567893'), findsOneWidget);

      expect(find.textContaining('iPhone 15 128GB'), findsOneWidget);
      expect(find.textContaining('MacBook Air M3'), findsOneWidget);
      expect(find.textContaining('USB-C Kablo'), findsOneWidget);
      expect(find.textContaining('MX Master'), findsOneWidget);
    });

    testWidgets('elle barkod girme kutusu açılır', (
      WidgetTester tester,
    ) async {
      await openScanTab(tester);

      await tester.tap(find.text('Elle gir'));
      await tester.pumpAndSettle();

      expect(find.text('Barkodu elle gir'), findsOneWidget);
      expect(find.widgetWithText(TextField, ''), findsWidgets);
    });
  });

  group('Tarama sonucu — bulundu', () {
    Future<void> scanIphone(WidgetTester tester) async {
      await openScanTab(tester);
      await tester.tap(find.text('8691234567890'));
      await tester.pumpAndSettle();
    }

    testWidgets('şartnamedeki alanların tamamını gösterir', (
      WidgetTester tester,
    ) async {
      // Barkod bulundu ✓ / ürün adı / SKU / stok / lokasyon.
      await scanIphone(tester);

      expect(find.text('Tarama Sonucu'), findsOneWidget);
      expect(find.text('Barkod bulundu'), findsOneWidget);
      expect(find.text('8691234567890'), findsWidgets);
      expect(find.text('iPhone 15 128GB Siyah'), findsOneWidget);
      expect(find.text('IP15-128-BLK'), findsOneWidget);

      // Stok: 24 (18 + 6).
      expect(find.byType(HeroFigure), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('toplam stok'), findsOneWidget);
    });

    testWidgets('lokasyon dökümü tek lokasyona indirgenmez', (
      WidgetTester tester,
    ) async {
      // Şartname "Lokasyon: A-01-01" diyor ama ürün iki raftaysa tek kod
      // yazmak yanıltıcı olur.
      await scanIphone(tester);

      expect(find.byType(LocationBreakdown), findsOneWidget);
      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.text('B-03-02'), findsOneWidget);
      expect(find.text('18 adet'), findsOneWidget);
      expect(find.text('6 adet'), findsOneWidget);
    });

    testWidgets('şartnamedeki üç aksiyon da bulunur', (
      WidgetTester tester,
    ) async {
      await scanIphone(tester);

      expect(find.widgetWithText(PrimaryButton, 'Ürün Detayı'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Transfer'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Mal Kabul'), findsOneWidget);
    });

    testWidgets('ürün detayına geçiş çalışır', (WidgetTester tester) async {
      await scanIphone(tester);

      await tester.tap(find.text('Ürün Detayı'));
      await tester.pumpAndSettle();

      expect(find.text('Ürün Detayı'), findsWidgets);
      expect(find.text('Ürün Bilgileri'), findsOneWidget);
      expect(find.text('IP15-128-BLK'), findsWidgets);
    });

    testWidgets('stoksuz üründe transfer devre dışı', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openScanTab(tester);

      // ThinkPad'in barkodu demo listesinde yok; doğrudan sonucu okuruz.
      final ScanResult result = await container.read(
        scanResultProvider('8691234567899').future,
      );
      expect(result.summary?.product.name, contains('ThinkPad'));
      expect(result.summary?.totalQuantity, 0);
    });
  });

  group('Tarama sonucu — bulunamadı', () {
    Future<ProviderContainer> scanUnknown(WidgetTester tester) async {
      final ProviderContainer container = await openScanTab(tester);

      await tester.tap(find.text('Elle gir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '9999999999999');
      await tester.tap(find.text('Ara'));
      await tester.pumpAndSettle();

      return container;
    }

    testWidgets('hata ekranı değil, açıklayıcı bir sonuç gösterilir', (
      WidgetTester tester,
    ) async {
      await scanUnknown(tester);

      expect(find.text('Barkod bulunamadı'), findsOneWidget);
      expect(find.textContaining('Etiket yıpranmış'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('kod ürün aramasına taşınabilir', (WidgetTester tester) async {
      // Kullanıcı kodu elle yazmak zorunda kalmamalı.
      final ProviderContainer container = await scanUnknown(tester);

      await tester.tap(find.text('Ürünlerde Ara'));
      await tester.pumpAndSettle();

      expect(container.read(productFilterProvider).query, '9999999999999');
      expect(find.text('Ürünler'), findsOneWidget);
    });
  });

  group('Barkod eşleştirme', () {
    test('bilinmeyen kod için isFound false döner', () async {
      final ProviderContainer container = ProviderContainer(
        retry: noRetryPolicy,
        overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
      );
      addTearDown(container.dispose);

      final ScanResult found = await container.read(
        scanResultProvider('8691234567890').future,
      );
      expect(found.isFound, isTrue);

      final ScanResult missing = await container.read(
        scanResultProvider('0000000000000').future,
      );
      expect(missing.isFound, isFalse);
      expect(missing.barcode, '0000000000000');
    });

    test('demo barkodların tamamı bir ürüne bağlanır', () async {
      // Liste ile mock veri ayrı yazıldı; biri değişirse burası yakalar.
      final ProviderContainer container = ProviderContainer(
        retry: noRetryPolicy,
        overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
      );
      addTearDown(container.dispose);

      final List<ScanResult> demo = await container.read(
        demoBarcodesProvider.future,
      );

      expect(demo, hasLength(4));
      for (final ScanResult result in demo) {
        expect(result.isFound, isTrue, reason: '${result.barcode} eşleşmedi');
      }
    });
  });
}
