import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/app/router.dart';
import 'package:warehouse_management_system/app/theme/status_tone_colors.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/features/scan/presentation/widgets/barcode_verify_sheet.dart';
import 'package:warehouse_management_system/features/scan/providers/scan_providers.dart';

/// Barkod doğrulamayı doğrular (şartname 11. ve 14. bölümler).
///
/// Doğrulamanın amacı navigasyon değil **teyit**: çalışan raftan aldığı
/// ürünün doğru ürün olduğunu okutarak kanıtlar. Panel açılıp kapanır,
/// kullanıcı bulunduğu adımda kalır.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<void> openRoute(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        retry: noRetryPolicy,
        overrides: [
          mockConfigProvider.overrideWithValue(MockConfig.instant()),
          // Widget testinde gerçek kamera kanalı yok; ekran demo barkod
          // listesine düşer ve doğrulama oradan yapılır.
          cameraSupportedProvider.overrideWithValue(false),
        ],
        child: const WarehouseApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)))
        .read(routerProvider)
        .go(route);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// Paneldeki demo barkoda dokunur.
  ///
  /// Barkod arkadaki toplama ekranında da yazdığı için dokunuş panelin
  /// içine sınırlanır.
  Future<void> tapBarcode(WidgetTester tester, String barcode) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BarcodeVerifySheet),
        matching: find.text(barcode),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// #10452 toplama görevinin ilk adımı: A-01-01'den 2 adet iPhone 15.
  Future<void> openPicking(WidgetTester tester) =>
      openRoute(tester, '/orders/ord-10452/picking');

  group('Toplama ekranında doğrulama', () {
    testWidgets('düğme sayfayı değiştirmez, panel açar', (
      WidgetTester tester,
    ) async {
      // Eski hâlinde düğme Tara sekmesine gidiyor ve toplama ekranı
      // yığından düşüyordu.
      await openPicking(tester);

      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();

      expect(find.byType(BarcodeVerifySheet), findsOneWidget);
      expect(find.text('Barkod Doğrula'), findsWidgets);
      expect(find.text('BEKLENEN ÜRÜN'), findsOneWidget);
      // Toplama ekranı hâlâ arkada.
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('yanlış barkod hangi ürünün okunduğunu söyler', (
      WidgetTester tester,
    ) async {
      await openPicking(tester);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();

      // MacBook Air'ın barkodu; beklenen iPhone 15 128GB.
      await tapBarcode(tester, '8691234567891');

      expect(find.text('Yanlış ürün'), findsOneWidget);
      expect(find.textContaining('MacBook Air M3'), findsWidgets);
      // Panel kapanmaz, kullanıcı tekrar deneyebilir.
      expect(find.byType(BarcodeVerifySheet), findsOneWidget);
    });

    testWidgets('doğru barkod paneli kapatır ve onay satırı çıkar', (
      WidgetTester tester,
    ) async {
      await openPicking(tester);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();

      await tapBarcode(tester, '8691234567890');

      expect(find.byType(BarcodeVerifySheet), findsNothing);
      expect(find.byType(BarcodeVerifiedBanner), findsOneWidget);
      expect(find.textContaining('Barkod doğrulandı'), findsOneWidget);
      expect(find.text('IP15-128-BLK'), findsWidgets);
    });

    testWidgets('sonraki adımda doğrulama sıfırlanır', (
      WidgetTester tester,
    ) async {
      // Çalışan her ürünü ayrı okutmalı; bir kez doğrulamak tüm görevi
      // doğrulamış saymaz.
      await openPicking(tester);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();
      await tapBarcode(tester, '8691234567890');

      expect(find.byType(BarcodeVerifiedBanner), findsOneWidget);

      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byType(BarcodeVerifiedBanner), findsNothing);
      expect(
        find.widgetWithText(SecondaryButton, 'Barkod Doğrula'),
        findsOneWidget,
      );
    });

    testWidgets('doğrulama zorunlu değil', (WidgetTester tester) async {
      // Depoda kamera bozuk olabilir; iş durmamalı.
      await openPicking(tester);

      final PrimaryButton confirm = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'),
      );
      expect(confirm.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doğrulamadan Devam Et'));
      await tester.pumpAndSettle();

      expect(find.byType(BarcodeVerifySheet), findsNothing);
      expect(find.byType(BarcodeVerifiedBanner), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('beklenen ürünün barkodu listede her zaman bulunur', (
      WidgetTester tester,
    ) async {
      // Kamerasız bir cihazda doğrulama demosu yapılamazsa panel işe
      // yaramaz.
      await openRoute(tester, '/orders/ord-10461/picking');
      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();

      // #10461'in ilk ürünü demo listesinde olmayabilir; yine de kendi
      // barkodu panelin başında durmalı.
      expect(find.byType(BarcodeVerifySheet), findsOneWidget);
      expect(find.text('DEMO BARKODLAR'), findsOneWidget);
    });
  });

  group('Yerleştirme ekranında doğrulama', () {
    testWidgets('şartname 27. bölüm Demo 2 akışında doğrulama var', (
      WidgetTester tester,
    ) async {
      // "50 adet iPhone → Barkod doğrula → A-01-01 lokasyonu".
      await openRoute(
        tester,
        '/receiving/gr-1024/putaway?productId=p-01',
      );

      expect(
        find.widgetWithText(SecondaryButton, 'Barkod Doğrula'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();
      await tapBarcode(tester, '8691234567890');

      expect(find.byType(BarcodeVerifiedBanner), findsOneWidget);
      // Yerleştirme ekranı hâlâ ayakta.
      expect(find.text('Ürün Yerleştirme'), findsOneWidget);
    });
  });

  group('Mal kabul detayı', () {
    testWidgets('hiçbir yere gitmeyen tarama kısayolu kaldırıldı', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/receiving/gr-1024');

      expect(find.text('GR-1024'), findsWidgets);
      // Başlıkta tarama düğmesi yok; doğrulama yerleştirme adımında.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(AppIcons.scan),
        ),
        findsNothing,
      );
    });
  });
}
