import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/features/dashboard/presentation/widgets/dashboard_metrics.dart';

/// Dashboard'u uçtan uca doğrular (şartname 7. bölüm).
///
/// Testler sahte veri enjekte etmiyor; gerçek uygulamayı gerçek mock veriyle
/// açıyor. Böylece "veri katmanından ekrana kadar zincir çalışıyor mu"
/// sorusu da cevaplanmış oluyor — bir repository değişikliği dashboard'u
/// bozarsa burada görünür.
///
/// Görsel dil yeniden ele alındıktan sonra testler de dataviz sözleşmesine
/// göre yazıldı: tek hero figürü, bağlamlı metrikler, duruma ayrılmış renk.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  /// Uygulamayı dar bir telefon ekranında açar ve dashboard'a kadar
  /// ilerletir.
  Future<void> openDashboard(WidgetTester tester) async {
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
  }

  /// Dikey listeyi [target] görünene kadar kaydırır.
  ///
  /// CustomScrollView ekran dışındaki sliverları oluşturmaz; ekranın
  /// altındaki bölümleri test edebilmek için önce oraya kaydırmak gerekir.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('Dashboard açılışı', () {
    testWidgets('kullanıcıyı adıyla karşılar ve deposunu gösterir', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      expect(find.text('Merhaba, Emir'), findsOneWidget);
      expect(find.textContaining('Depo Sorumlusu'), findsOneWidget);
      expect(find.textContaining('Merkez Depo'), findsOneWidget);
    });

    testWidgets('dar ekranda hiçbir bölüm taşmaz', (WidgetTester tester) async {
      await openDashboard(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Hero figürü', () {
    testWidgets('toplam stok tek büyük sayı olarak öne çıkar', (
      WidgetTester tester,
    ) async {
      // dataviz: görünüm başına tam olarak bir hero figürü.
      await openDashboard(tester);

      expect(find.byType(HeroFigure), findsOneWidget);
      expect(find.text('toplam stok'), findsOneWidget);
      // Mock veride 496 adet stok var.
      expect(find.text('496'), findsOneWidget);
    });

    testWidgets('haftalık değişim ve kırılım gösterilir', (
      WidgetTester tester,
    ) async {
      // Çıplak sayı bağlam taşımaz; delta ve kırılım sözleşmenin parçası.
      await openDashboard(tester);

      expect(find.byType(DeltaLabel), findsWidgets);
      expect(find.textContaining('bu hafta'), findsOneWidget);
      expect(find.textContaining('giriş'), findsWidgets);
      expect(find.textContaining('çıkış'), findsWidgets);
    });

    testWidgets('7 günlük trend çubukları çizilir', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      expect(find.byType(SparkBars), findsOneWidget);
      expect(find.text('son 7 gün hareket'), findsOneWidget);
    });
  });

  group('KPI blokları', () {
    testWidgets('şartnamedeki metrikleri gösterir', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      // Etiketler büyük harfle çizilir.
      expect(find.text('ÜRÜN'), findsOneWidget);
      expect(find.text('BEKLEYEN'), findsOneWidget);
      expect(find.text('TOPLANIYOR'), findsOneWidget);
      expect(find.text('MAL KABUL'), findsOneWidget);
      expect(find.text('SEVKİYAT'), findsOneWidget);
      expect(find.text('HAREKET'), findsOneWidget);
    });

    testWidgets('metrikler gerçek mock veriyle eşleşir', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      // Mock veri seti 15 ürün ve 4 kategori içeriyor.
      expect(find.text('15'), findsWidgets);
      expect(find.text('4 kategori'), findsOneWidget);
    });

    testWidgets('kritik stok uyarı şeridi görünür', (
      WidgetTester tester,
    ) async {
      // Mock veride 4 kritik + 1 tükenmiş ürün var.
      await openDashboard(tester);

      expect(find.byType(StockAlertStrip), findsOneWidget);
      expect(find.textContaining('üründe stok uyarısı'), findsOneWidget);
    });
  });

  group('Hızlı işlemler', () {
    testWidgets('beş kısayol da bulunuyor', (WidgetTester tester) async {
      await openDashboard(tester);

      // Beş kısayol tek satıra sığar, kaydırma gerekmez.
      expect(find.text('Mal Kabul'), findsWidgets);
      expect(find.text('Topla'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Sayım'), findsOneWidget);
      // "Tara" hem kısayolda hem alt menüde bulunur.
      expect(find.text('Tara'), findsNWidgets(2));
    });

    testWidgets('"Tara" kısayolu tarama sekmesine götürür', (
      WidgetTester tester,
    ) async {
      // Şartname 34: tarama bir-iki dokunuşta bulunmalı.
      await openDashboard(tester);

      await tester.tap(find.text('Tara').first);
      await tester.pumpAndSettle();

      expect(find.text('Barkod Tara'), findsWidgets);
    });

    testWidgets('"Transfer" transfer ekranını açar', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Stok Transferi'), findsWidgets);
    });
  });

  group('Kritik stok bölümü', () {
    testWidgets('bölüm başlığı ve ürünler görünür', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Kritik Stok'));

      expect(find.text('Kritik Stok'), findsOneWidget);
      // Tükenen ürün en üstte listelenir.
      expect(find.text('Lenovo ThinkPad E14'), findsOneWidget);
    });

    testWidgets('eksik miktarı açıkça yazar', (WidgetTester tester) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Kritik Stok'));

      // "7 adet eksik · min. 10" biçiminde.
      expect(find.textContaining('eksik · min.'), findsWidgets);
    });
  });

  group('Son hareketler bölümü', () {
    testWidgets('hareketler listeleniyor', (WidgetTester tester) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Son Hareketler'));

      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.byType(DashboardMovementList), findsOneWidget);
    });

    testWidgets('miktar işareti hareket yönünü taşır', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Son Hareketler'));

      // Giriş hareketi artı işaretli.
      expect(find.text('+120'), findsOneWidget);
      // Çıkış hareketi eksi işaretli.
      expect(find.text('-10'), findsOneWidget);
      // Transfer işaretsiz: toplam stok değişmediği için +/- yanıltıcı olur.
      expect(find.text('+15'), findsNothing);
    });
  });

  group('Yenileme', () {
    testWidgets('aşağı çekince yenileme göstergesi çıkar', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('Hata durumu', () {
    testWidgets('okuma başarısız olunca hata ekranı gösterilir', (
      WidgetTester tester,
    ) async {
      // Şartname 25: hata durumu kullanıcıya gösterilmeli, saklanmamalı.
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

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(WarehouseApp)),
      );
      container.read(errorSimulationProvider.notifier).set(true);
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsWidgets);
      expect(find.textContaining('Bağlantı kurulamadı'), findsWidgets);
    });
  });
}
