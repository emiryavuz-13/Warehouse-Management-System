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
import 'package:warehouse_management_system/features/scan/providers/scan_providers.dart';
import 'package:warehouse_management_system/features/transfer/presentation/widgets/product_picker_sheet.dart';

/// Alttan açılan panellerin sistem çubuğunun altında kalmaması
/// (Samsung'ların üç tuşlu gezinme çubuğu).
///
/// `showModalBottomSheet(useSafeArea: true)` yalnızca üst çentiği halleder.
/// Alttaki gezinme çubuğu panelin kendi sorumluluğudur; hesaplanmazsa
/// panelin en altındaki düğmeler tuşların arkasında kalır ve dokunulamaz.
///
/// Bu dosya her paneli gezinme çubuğu olan bir cihazda açıp en alttaki
/// öğenin çubuğun üstünde kaldığını doğrular.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  /// Üç tuşlu gezinme çubuğunun yüksekliği (mantıksal piksel).
  const double navigationBar = 48;

  /// Ekranın dokunulabilir alanının alt sınırı.
  const double reachableBottom = 844 - navigationBar;

  Future<void> openRoute(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    // Gezinme çubuğu olan bir cihaz: ekranın altındaki 48 piksel sistemin.
    tester.view.padding = const FakeViewPadding(bottom: navigationBar);
    tester.view.viewPadding = const FakeViewPadding(bottom: navigationBar);
    addTearDown(tester.view.reset);

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

    ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)))
        .read(routerProvider)
        .go(route);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// Bulunan öğenin alt kenarı gezinme çubuğunun üstünde mi.
  void expectAboveNavigationBar(WidgetTester tester, Finder finder) {
    final Rect rect = tester.getRect(finder);
    expect(
      rect.bottom,
      lessThanOrEqualTo(reachableBottom),
      reason:
          'Öğenin altı ${rect.bottom} pikselde; gezinme çubuğu '
          '$reachableBottom pikselden sonra başlıyor, orası dokunulamaz.',
    );
  }

  group('Sayım paneli (şartname 16. bölüm)', () {
    testWidgets('kaydet ve vazgeç düğmeleri gezinme çubuğunun üstünde', (
      WidgetTester tester,
    ) async {
      // Kullanıcının bildirdiği hata: Samsung cihazda "Vazgeç" ve "Sayımı
      // Kaydet" üç tuşlu çubuğun arkasında kalıyordu.
      await openRoute(tester, '/counts/ic-031');

      await tester.tap(find.textContaining('iPhone 15 128GB').first);
      await tester.pumpAndSettle();

      expect(find.text('Sayımı Kaydet'), findsOneWidget);
      expectAboveNavigationBar(
        tester,
        find.widgetWithText(PrimaryButton, 'Sayımı Kaydet'),
      );
      expectAboveNavigationBar(
        tester,
        find.widgetWithText(SecondaryButton, 'Vazgeç'),
      );
    });

    testWidgets('düğmelere gerçekten dokunulabilir', (
      WidgetTester tester,
    ) async {
      // Konum doğru olsa bile dokunuşun düğmeye ulaştığını görmek gerekir.
      await openRoute(tester, '/counts/ic-031');
      await tester.tap(find.textContaining('iPhone 15 128GB').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SecondaryButton, 'Vazgeç'));
      await tester.pumpAndSettle();

      expect(find.text('Sayımı Kaydet'), findsNothing);
    });
  });

  group('Diğer paneller', () {
    testWidgets('toplama: kalem listesinin son satırı görünür', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/orders/ord-10452/picking');

      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();

      expectAboveNavigationBar(tester, find.textContaining('MX Master').first);
    });

    testWidgets('toplama: raf listesinin son satırı görünür', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/orders/ord-10452/picking');

      await tester.tap(find.textContaining('Başka raf').first);
      await tester.pumpAndSettle();

      // En alttaki raf satırı çubuğun arkasında kalmamalı.
      expectAboveNavigationBar(tester, find.text('B-03-02').last);
    });

    testWidgets('barkod doğrulama: son düğme görünür', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/orders/ord-10452/picking');

      await tester.tap(find.widgetWithText(SecondaryButton, 'Barkod Doğrula'));
      await tester.pumpAndSettle();

      expectAboveNavigationBar(tester, find.text('Doğrulamadan Devam Et'));
    });

    testWidgets('filtre paneli: uygula düğmesi görünür', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/orders');

      await tester.tap(find.byIcon(AppIcons.filter));
      await tester.pumpAndSettle();

      expectAboveNavigationBar(
        tester,
        find.widgetWithText(PrimaryButton, 'Uygula'),
      );
    });

    testWidgets('ürün seçici: son satır görünür', (WidgetTester tester) async {
      await openRoute(tester, '/transfer');

      await tester.tap(find.text('Ürün Seç'));
      await tester.pumpAndSettle();

      // 15 ürünlük liste kaydırılabilir, yani son satır zaten ekranın
      // altında olabilir — burada anlamlı olan panelin kendi tabanı.
      expectAboveNavigationBar(tester, find.byType(ProductPickerSheet));
    });
  });
}
