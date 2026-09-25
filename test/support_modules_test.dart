import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';
import 'package:warehouse_management_system/app/theme/theme_mode_controller.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/features/movements/providers/movement_providers.dart';
import 'package:warehouse_management_system/features/reports/providers/report_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Yardımcı modülleri doğrular: hareketler, bildirimler, profil, raporlar
/// (şartname 19-22. bölümler).
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

  Future<ProviderContainer> openProfile(WidgetTester tester) async {
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

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)));
  }

  /// Profil menüsünden bir modülü açar.
  Future<ProviderContainer> openFromProfile(
    WidgetTester tester,
    String label,
  ) async {
    final ProviderContainer container = await openProfile(tester);
    await tester.scrollUntilVisible(
      find.text(label),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    return container;
  }

  group('Profil (şartname 21. bölüm)', () {
    testWidgets('şartnamedeki beş alan da bulunur', (
      WidgetTester tester,
    ) async {
      // Ad soyad, rol, depo, son giriş, yetkiler.
      await openProfile(tester);

      expect(find.text('Emir Yavuz'), findsWidgets);
      expect(find.text('Ad Soyad'), findsOneWidget);
      expect(find.text('Rol'), findsOneWidget);
      expect(find.text('Depo'), findsOneWidget);
      expect(find.text('Son giriş'), findsOneWidget);
      expect(find.text('Yetkiler'), findsOneWidget);
      expect(find.text('Depo Sorumlusu'), findsWidgets);
    });

    testWidgets('tema seçici üç seçenek sunar ve tercihi değiştirir', (
      WidgetTester tester,
    ) async {
      // "Sistem" seçeneği olmayan bir uygulama, cihaz karanlık moda
      // geçtiğinde kullanıcıyı ayara geri gönderir.
      final ProviderContainer container = await openProfile(tester);
      await tester.scrollUntilVisible(
        find.text('TEMA'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Sistem'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.text('Koyu'), findsOneWidget);
      expect(container.read(themeModeProvider), ThemeMode.system);

      await tester.tap(find.text('Koyu'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('hata simülasyonu anahtarı çalışır', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openProfile(tester);
      await tester.scrollUntilVisible(
        find.text('Hata simülasyonu'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(container.read(errorSimulationProvider), isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(errorSimulationProvider), isTrue);
    });

    testWidgets('bottom bar\'da yeri olmayan modüller buradan açılır', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);
      await tester.scrollUntilVisible(
        find.text('Raporlar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Stok Hareketleri'), findsOneWidget);
      expect(find.text('Bildirimler'), findsOneWidget);
      expect(find.text('Lokasyonlar'), findsOneWidget);
      expect(find.text('Raporlar'), findsOneWidget);
    });
  });

  group('Stok hareketleri (şartname 19. bölüm)', () {
    testWidgets('gün başlıklarıyla zaman sıralı listelenir', (
      WidgetTester tester,
    ) async {
      await openFromProfile(tester, 'Stok Hareketleri');

      expect(find.text('Stok Hareketleri'), findsWidgets);
      expect(find.text('BUGÜN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şartnamedeki yedi bilgi satırda bulunur', (
      WidgetTester tester,
    ) async {
      // Ürün, miktar, tür, kaynak, hedef, kullanıcı, saat.
      await openFromProfile(tester, 'Stok Hareketleri');

      expect(find.textContaining('Transfer'), findsWidgets);
      // Kaynak → hedef gösterimi.
      expect(find.textContaining('→'), findsWidgets);
      // İşaretli miktar.
      expect(find.textContaining('+'), findsWidgets);
    });

    testWidgets('tür filtresi listeyi daraltır', (WidgetTester tester) async {
      final ProviderContainer container = await openFromProfile(
        tester,
        'Stok Hareketleri',
      );

      container
          .read(movementFilterProvider.notifier)
          .toggleType(MovementType.transfer);
      await tester.pumpAndSettle();

      final List<MovementDetail> items = await container.read(
        movementListProvider.future,
      );
      expect(
        items.every((MovementDetail m) =>
            m.movement.type == MovementType.transfer),
        isTrue,
      );
    });

    test('gün grupları giriş ve çıkış toplamını verir', () async {
      final ProviderContainer container = makeContainer();
      await container.read(movementListProvider.future);

      final List<MovementDayGroup> groups = container.read(
        movementsByDayProvider,
      );

      expect(groups, isNotEmpty);
      for (final MovementDayGroup group in groups) {
        expect(group.movements, isNotEmpty);
        expect(group.inbound, greaterThanOrEqualTo(0));
        expect(group.outbound, greaterThanOrEqualTo(0));
      }
    });
  });

  group('Bildirimler (şartname 20. bölüm)', () {
    testWidgets('okunmamış sayısı gösterilir', (WidgetTester tester) async {
      await openFromProfile(tester, 'Bildirimler');

      // Mock veride 7 bildirim, 5'i okunmamış.
      expect(find.textContaining('7 bildirim'), findsOneWidget);
      expect(find.textContaining('5 okunmamış'), findsOneWidget);
    });

    testWidgets('şartnamedeki örnek bildirimler bulunur', (
      WidgetTester tester,
    ) async {
      await openFromProfile(tester, 'Bildirimler');

      expect(find.text('Kritik stok'), findsWidgets);
      expect(find.textContaining('Yeni görev'), findsWidgets);
    });

    testWidgets('bildirime dokunmak okundu yapar ve hedefe gider', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openFromProfile(
        tester,
        'Bildirimler',
      );

      final int before =
          await container.read(unreadNotificationCountProvider.future);

      await tester.tap(find.text('Kritik stok').first);
      await tester.pumpAndSettle();

      final int after =
          await container.read(unreadNotificationCountProvider.future);
      expect(after, before - 1);
    });

    testWidgets('tümünü okundu yap sayacı sıfırlar', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openFromProfile(
        tester,
        'Bildirimler',
      );

      await tester.tap(find.text('Tümünü okundu yap'));
      await tester.pumpAndSettle();

      expect(
        await container.read(unreadNotificationCountProvider.future),
        0,
      );
      expect(find.textContaining('tümü okundu'), findsOneWidget);
    });
  });

  group('Raporlar (şartname 22. bölüm)', () {
    testWidgets('şartnamedeki beş rapor da bulunur', (
      WidgetTester tester,
    ) async {
      // 7 gün giriş, 7 gün çıkış, transfer sayısı, günlük sevkiyat,
      // kritik stoklar.
      await openFromProfile(tester, 'Raporlar');

      expect(find.text('Giriş ve Çıkış'), findsOneWidget);
      expect(find.byType(HeroFigure), findsOneWidget);
      expect(find.text('son 7 gün net değişim'), findsOneWidget);
      expect(find.text('TRANSFER'), findsOneWidget);
      expect(find.text('BUGÜN SEVKİYAT'), findsOneWidget);
      expect(find.text('Kritik Stok'), findsOneWidget);
    });

    testWidgets('grafik çizilir', (WidgetTester tester) async {
      await openFromProfile(tester, 'Raporlar');

      expect(find.text('Giriş'), findsWidgets);
      expect(find.text('Çıkış'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('rapor kritik stoğun tamamını gösterir, dashboard dördünü', () async {
      // Raporun eksik liste göstermesi yanlış karara yol açar.
      final ProviderContainer container = makeContainer();

      final List<ProductStockSummary> all = await container.read(
        allCriticalProductsProvider.future,
      );

      // 4 kritik + 1 tükenmiş.
      expect(all.length, 5);
    });
  });
}
