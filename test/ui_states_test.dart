import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/app/router.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Tüm ekranların durum davranışını tarar (şartname 25. bölüm).
///
/// Bu dosya tek tek modülleri değil **tüm uygulamayı** kontrol eder: her
/// ekran hata simülasyonunda anlamlı bir hata durumu göstermeli, dar bir
/// ekranda ve büyük yazı tipiyle taşmamalı.
///
/// Modül testleri ekranın ne yaptığını doğrular; bu dosya ekranın
/// **çökmediğini** doğrular. Yeni bir ekran eklendiğinde buraya bir satır
/// yazmak, o ekranın üç zor durumda da ayakta kaldığını garanti eder.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  /// Şartname 28. bölümdeki ekranların adreslenebilir olanları.
  const Map<String, String> screens = <String, String>{
    'Dashboard': '/dashboard',
    'Stok': '/stock',
    'Ürünler': '/products',
    'Ürün detayı': '/products/p-01',
    'Siparişler': '/orders',
    'Sipariş detayı': '/orders/ord-10452',
    'Mal kabul': '/receiving',
    'Mal kabul detayı': '/receiving/gr-1024',
    'Yerleştirme': '/receiving/gr-1024/putaway?productId=p-01',
    'Sevkiyat': '/shipments',
    'Sevkiyat detayı': '/shipments/shp-013',
    'Sayım': '/counts',
    'Sayım detayı': '/counts/ic-031',
    'Lokasyonlar': '/locations',
    'Lokasyon detayı': '/locations/loc-a0101',
    'Hareketler': '/movements',
    'Bildirimler': '/notifications',
    'Profil': '/profile',
    'Raporlar': '/reports',
    'Transfer': '/transfer?productId=p-01',
    'Tarama sonucu': '/scan-result?barcode=8691234567890',
  };

  /// Uygulamayı açar ve verilen adrese gider.
  Future<void> openScreen(
    WidgetTester tester,
    String route, {
    required Size size,
    bool simulateErrors = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final MockConfig config = MockConfig.instant()
      ..simulateErrors = simulateErrors;

    await tester.pumpWidget(
      ProviderScope(
        retry: noRetryPolicy,
        overrides: [mockConfigProvider.overrideWithValue(config)],
        child: const WarehouseApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)))
        .read(routerProvider)
        .go(route);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('Hata durumu (şartname 25. bölüm)', () {
    for (final MapEntry<String, String> screen in screens.entries) {
      testWidgets('${screen.key} hata ekranı gösterir', (
        WidgetTester tester,
      ) async {
        await openScreen(
          tester,
          screen.value,
          size: const Size(390, 844),
          simulateErrors: true,
        );

        expect(
          find.byType(ErrorState),
          findsWidgets,
          reason: '${screen.key} hata durumunda boş kalmamalı',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Hata durumunda yanlış sayı gösterilmez', () {
    testWidgets('stok durum şeridi sıfır göstermez', (
      WidgetTester tester,
    ) async {
      // Hata ekranının üstünde "0 ürün · 0 kritik" duruyorsa kullanıcı
      // hatayı değil "depo boş" bilgisini okur.
      await openScreen(
        tester,
        '/stock',
        size: const Size(390, 844),
        simulateErrors: true,
      );

      expect(find.byType(ErrorState), findsWidgets);
      expect(find.text('TÜMÜ'), findsNothing);
      expect(find.text('KRİTİK'), findsNothing);
    });

    testWidgets('dashboard başlığı önbellekteki adı gizlemez', (
      WidgetTester tester,
    ) async {
      // Rol ve depo yazısı önbellekten okunurken isim kayboluyordu.
      await openScreen(
        tester,
        '/dashboard',
        size: const Size(390, 844),
        simulateErrors: true,
      );

      // Hata simülasyonu açılışta da etkili olduğu için isim hiç
      // yüklenmemiş olabilir; kritik olan, rol yazılıyken ismin de
      // yazılması.
      final bool hasRole = find.textContaining('Depo Sorumlusu')
          .evaluate()
          .isNotEmpty;
      if (hasRole) {
        expect(find.textContaining('Merhaba, '), findsOneWidget);
      }
    });
  });

  group('Dar ekran (320 px)', () {
    for (final MapEntry<String, String> screen in screens.entries) {
      testWidgets('${screen.key} taşmıyor', (WidgetTester tester) async {
        await openScreen(tester, screen.value, size: const Size(320, 640));

        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.key} dar ekranda taşıyor',
        );
      });
    }
  });

  group('Büyük yazı tipi', () {
    // Uygulama ölçeği 1.3'e sınırlıyor; sınırın kendisinde taşma olmamalı.
    for (final MapEntry<String, String> screen in screens.entries) {
      testWidgets('${screen.key} taşmıyor', (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await openScreen(tester, screen.value, size: const Size(360, 720));

        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.key} büyük yazı tipiyle taşıyor',
        );
      });
    }
  });

  group('Hata simülasyonu yazmayı engellemez (şartname 25. bölüm)', () {
    test('okuma başarısız olurken transfer yine de çalışır', () async {
      // Kullanıcı demo sırasında hata ekranlarını görmek için anahtarı
      // açtığında yaptığı işlemi kaybetmemeli.
      final MockConfig config = MockConfig.instant()..simulateErrors = true;
      final ProviderContainer container = ProviderContainer(
        retry: noRetryPolicy,
        overrides: [mockConfigProvider.overrideWithValue(config)],
      );
      addTearDown(container.dispose);

      // Okuma başarısız.
      await expectLater(
        container.read(productSummaryProvider('p-01').future),
        throwsA(isA<Object>()),
      );

      // Yazma başarılı.
      final StockMovement movement = await container
          .read(warehouseActionsProvider)
          .transferStock(
            productId: 'p-01',
            sourceLocationId: 'loc-a0101',
            targetLocationId: 'loc-b0302',
            quantity: 3,
          );
      expect(movement.quantity, 3);

      // Anahtar kapanınca sonuç görünür olur.
      config.simulateErrors = false;
      container.read(dataRevisionProvider.notifier).bump();

      final ProductStockSummary summary = (await container.read(
        productSummaryProvider('p-01').future,
      ))!;
      expect(
        summary.locations
            .firstWhere((LocationStock l) => l.location.code == 'A-01-01')
            .quantity,
        15,
        reason: '18 - 3',
      );
    });
  });
}
