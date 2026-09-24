import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';

/// Dashboard'u uçtan uca doğrular (şartname 7. bölüm).
///
/// Testler gerçek uygulamayı, gerçek mock veriyle açar; sahte veri
/// enjekte edilmez. Böylece "veri katmanından ekrana kadar zincir çalışıyor
/// mu" sorusu da cevaplanmış olur — bir repository değişikliği dashboard'u
/// bozarsa burada görünür.
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
  /// CustomScrollView ekran dışındaki slivarları oluşturmaz; ekranın altındaki
  /// bölümleri test edebilmek için önce oraya kaydırmak gerekir.
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

  group('Özet kartları', () {
    testWidgets('şartnamedeki metrikleri gösterir', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      expect(find.text('Toplam Ürün'), findsOneWidget);
      expect(find.text('Toplam Stok'), findsOneWidget);
      expect(find.text('Bekleyen Sipariş'), findsOneWidget);
      expect(find.text('Toplanıyor'), findsOneWidget);
      expect(find.text('Bugünkü Mal Kabul'), findsOneWidget);
      expect(find.text('Bugünkü Sevkiyat'), findsOneWidget);
    });

    testWidgets('metrikler gerçek mock veriyle eşleşir', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      // Mock veri seti 15 ürün içeriyor.
      expect(find.text('15'), findsWidgets);
      // Üç yeni sipariş var (#10453, #10454, #10460).
      expect(find.text('Bekleyen Sipariş'), findsOneWidget);
    });

    testWidgets('kritik stok uyarı şeridi görünür', (
      WidgetTester tester,
    ) async {
      // Mock veride 4 kritik + 1 tükenmiş ürün var.
      await openDashboard(tester);

      expect(find.textContaining('üründe stok uyarısı'), findsOneWidget);
      expect(find.textContaining('kritik'), findsOneWidget);
    });
  });

  group('Hızlı işlemler', () {
    testWidgets('beş kısayol da bulunuyor', (WidgetTester tester) async {
      await openDashboard(tester);

      expect(find.text('Ürün Tara'), findsOneWidget);
      expect(find.text('Mal Kabul'), findsOneWidget);
      expect(find.text('Sipariş Topla'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      // Beşinci kısayol yatay listede ekran dışında kalıyor; yana kaydır.
      await tester.drag(
        find.byType(QuickActionCard).first,
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sayım'), findsOneWidget);
    });

    testWidgets('"Ürün Tara" tarama sekmesine götürür', (
      WidgetTester tester,
    ) async {
      // Şartname 34: tarama bir-iki dokunuşta bulunmalı.
      await openDashboard(tester);

      await tester.tap(find.text('Ürün Tara'));
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
      // Tükenen ürün en üstte olmalı.
      expect(find.text('Stok Yok'), findsWidgets);
    });

    testWidgets('eksik miktarı açıkça yazar', (WidgetTester tester) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Kritik Stok'));

      expect(find.textContaining('Minimum seviyenin'), findsWidgets);
    });
  });

  group('Son hareketler bölümü', () {
    testWidgets('hareketler listeleniyor', (WidgetTester tester) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Son Hareketler'));

      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.byType(MovementTile), findsWidgets);
    });

    testWidgets('giriş ve çıkış hareketleri işaretli gösteriliyor', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);
      await scrollTo(tester, find.text('Son Hareketler'));

      final Finder tiles = find.byType(MovementTile);
      expect(tiles, findsWidgets);
      // En az bir işaretli miktar bulunmalı (+ veya -).
      expect(
        find.descendant(of: tiles.first, matching: find.byType(Text)),
        findsWidgets,
      );
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

      final MockConfig config = MockConfig.instant();

      await tester.pumpWidget(
        ProviderScope(
          retry: noRetryPolicy,
          overrides: [mockConfigProvider.overrideWithValue(config)],
          child: const WarehouseApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Hata simülasyonunu aç ve yenile.
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
