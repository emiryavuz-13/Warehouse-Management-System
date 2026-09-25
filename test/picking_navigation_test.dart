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
import 'package:warehouse_management_system/features/orders/presentation/widgets/picking_sheets.dart';
import 'package:warehouse_management_system/features/orders/providers/order_providers.dart';
import 'package:warehouse_management_system/features/scan/providers/scan_providers.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Toplama akışının iki esnekliğini doğrular (şartname 14. bölüm).
///
/// Önceki hâlinde toplama iki yerde katıydı:
///
/// 1. Kaynak raf görev açılırken sabitleniyordu. USB-C kablo üç rafta
///    duruyor ama çalışan hangisinden aldığını seçemiyordu.
/// 2. Kalemler sırayla zorunluydu; çalışan deponun içinde yürürken yanından
///    geçtiği rafa uğrayamıyordu.
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

  Future<ProviderContainer> openPicking(WidgetTester tester) async {
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

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WarehouseApp)),
    );
    container.read(routerProvider).go('/orders/ord-10452/picking');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    return container;
  }

  Future<ProviderContainer> openOrder(
    WidgetTester tester,
    String orderId,
  ) async {
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

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WarehouseApp)),
    );
    container.read(routerProvider).go('/orders/$orderId');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    return container;
  }

  /// Sipariş detayındaki kalem satırlarında "Topla" kısayolu.
  ///
  /// Ekranın altındaki tek düğme ("Toplamaya Devam Et") çalışanı hep
  /// sıradaki kaleme götürüyordu; satırların tıklanabildiğini söyleyen bir
  /// şey yoktu.
  group('Sipariş satırından toplama', () {
    testWidgets('görev açıksa her toplanmamış kalemde "Topla" çıkar', (
      WidgetTester tester,
    ) async {
      await openOrder(tester, 'ord-10452');

      // Üç kalem de toplanmamış.
      expect(find.text('Topla'), findsNWidgets(3));
    });

    testWidgets('görev açılmadan satır kısayolu olmaz', (
      WidgetTester tester,
    ) async {
      // #10460 henüz "Yeni"; tek yol alttaki "Siparişi Topla" düğmesi.
      await openOrder(tester, 'ord-10460');

      expect(find.text('Siparişi Topla'), findsOneWidget);
      expect(find.text('Topla'), findsNothing);
    });

    testWidgets('"Topla" doğrudan o kalemin adımını açar', (
      WidgetTester tester,
    ) async {
      await openOrder(tester, 'ord-10452');

      // Üçüncü kalem alttaki eylem çubuğunun arkasında kalıyor.
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pumpAndSettle();

      // Üçüncü kalem: Logitech MX Master 3S.
      await tester.tap(find.text('Topla').at(2));
      await tester.pumpAndSettle();

      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.textContaining('MX Master'), findsWidgets);
      expect(find.text('C-01-01'), findsWidgets);
    });

    testWidgets('toplanmış kalemde kısayol kalmaz', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openOrder(tester, 'ord-10452');

      await tester.tap(find.text('Topla').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'));
      await tester.pumpAndSettle();

      // Toplama ekranından sipariş detayına dön.
      container.read(routerProvider).go('/orders/ord-10452');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('toplandı'), findsOneWidget);
      expect(find.text('Topla'), findsNWidgets(2));
    });
  });

  group('Adres satırındaki kalem numarası', () {
    testWidgets('geçersiz sıra numarası görevi bitmiş göstermez', (
      WidgetTester tester,
    ) async {
      // Elle yazılmış bir adres ekranı "toplama tamamlandı" ekranına
      // düşürmemeli; sıradaki kaleme dönmeli.
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

      ProviderScope.containerOf(tester.element(find.byType(WarehouseApp)))
          .read(routerProvider)
          .go('/orders/ord-10452/picking?line=9');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('1 / 3'), findsOneWidget);
    });
  });

  group('Kalemler arası geçiş', () {
    testWidgets('adım göstergesi kalem listesini açar', (
      WidgetTester tester,
    ) async {
      await openPicking(tester);

      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();

      expect(find.byType(PickingStepsSheet), findsOneWidget);
      expect(find.text('Görev Kalemleri'), findsOneWidget);
      // Üç kalemin tamamı listelenir.
      expect(find.textContaining('iPhone 15 128GB'), findsWidgets);
      expect(find.textContaining('USB-C Kablo'), findsWidgets);
      expect(find.textContaining('MX Master'), findsWidgets);
    });

    testWidgets('sıradaki kalem beklenmeden üçüncüye atlanabilir', (
      WidgetTester tester,
    ) async {
      // Çalışan yanından geçtiği rafa uğrayabilmeli.
      await openPicking(tester);

      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PickingStepsSheet),
          matching: find.textContaining('MX Master'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('C-01-01'), findsWidgets);
      // MX Master tek rafta duruyor; seçilecek bir şey yok.
      expect(find.textContaining('Başka raf'), findsNothing);

      // İlerleme çubuğu adımı değil toplanan kalemi sayar: 3. adımdayız
      // ama henüz hiçbir kalem toplanmadı.
      expect(
        tester.widget<TaskProgressBar>(find.byType(TaskProgressBar)).completed,
        0,
      );
    });

    testWidgets('atlanan kalem toplanınca sıradakine dönülür', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openPicking(tester);

      // 3. kaleme atla ve topla.
      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PickingStepsSheet),
          matching: find.textContaining('MX Master'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'));
      await tester.pumpAndSettle();

      // Elle seçim bırakılır, ilk tamamlanmamış kaleme dönülür.
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.textContaining('iPhone 15 128GB'), findsWidgets);

      final OrderDetail detail = (await container.read(
        orderDetailProvider('ord-10452').future,
      ))!;
      final OrderItem mouse = detail.order.items.firstWhere(
        (OrderItem i) => i.productId == 'p-10',
      );
      expect(mouse.isPicked, isTrue);
    });

    testWidgets('toplanmış kalem görüntülenebilir ama onaylanamaz', (
      WidgetTester tester,
    ) async {
      await openPicking(tester);

      await tester.tap(find.widgetWithText(PrimaryButton, 'Toplamayı Onayla'));
      await tester.pumpAndSettle();

      // Artık 2. kalemdeyiz; 1. kaleme geri dön.
      await tester.tap(find.text('2 / 3'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PickingStepsSheet),
          matching: find.textContaining('iPhone 15 128GB'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.textContaining('Bu kalem toplandı'), findsWidgets);

      final PrimaryButton button = tester.widget<PrimaryButton>(
        find.byType(PrimaryButton),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Kaynak raf seçimi', () {
    testWidgets('çok raflı üründe seçenek görünür', (
      WidgetTester tester,
    ) async {
      // iPhone A-01-01 ve B-03-02'de duruyor.
      await openPicking(tester);

      expect(find.textContaining('Başka raf (2)'), findsOneWidget);
    });

    testWidgets('çok raflı üründe raflar arasından seçilebilir', (
      WidgetTester tester,
    ) async {
      // USB-C kablo üç rafta duruyor.
      await openPicking(tester);

      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PickingStepsSheet),
          matching: find.textContaining('USB-C Kablo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Başka raf (3)'), findsOneWidget);

      await tester.tap(find.textContaining('Başka raf (3)'));
      await tester.pumpAndSettle();

      expect(find.byType(PickingLocationSheet), findsOneWidget);
      expect(find.text('Hangi raftan alıyorsunuz?'), findsOneWidget);
    });

    testWidgets('raf değişince rafta sayısı ve kod güncellenir', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await openPicking(tester);

      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PickingStepsSheet),
          matching: find.textContaining('USB-C Kablo'),
        ),
      );
      await tester.pumpAndSettle();

      final ProductStockSummary summary = (await container.read(
        productSummaryProvider('p-09').future,
      ))!;
      // En çok stoklu raf önerilir; ikinci rafı seçelim.
      final LocationStock other = summary.locations[1];

      await tester.tap(find.textContaining('Başka raf (3)'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PickingLocationSheet),
          matching: find.text(other.location.code),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PickingLocationSheet), findsNothing);
      expect(find.text(other.location.code), findsWidgets);
      expect(find.text('${other.quantity}'), findsWidgets);
    });
  });

  group('İş kuralları', () {
    test('seçilen raftan düşer, önerilenden değil', () async {
      final ProviderContainer container = makeContainer();

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');
      final PickingLine line = task.lines.firstWhere(
        (PickingLine l) => l.productId == 'p-09',
      );

      final ProductStockSummary before = (await container.read(
        productSummaryProvider('p-09').future,
      ))!;
      // Önerilen raf dışında, 5 adede yeten bir raf seç.
      final LocationStock other = before.locations.firstWhere(
        (LocationStock l) =>
            l.location.id != line.locationId && l.quantity >= 5,
      );

      await container
          .read(warehouseActionsProvider)
          .pickLine(
            taskId: task.id,
            productId: 'p-09',
            quantity: 5,
            locationId: other.location.id,
          );

      final ProductStockSummary after = (await container.read(
        productSummaryProvider('p-09').future,
      ))!;

      // Seçilen raf azaldı.
      expect(
        after.locations
            .firstWhere((LocationStock l) => l.location.id == other.location.id)
            .quantity,
        other.quantity - 5,
      );
      // Önerilen raf değişmedi.
      final int suggestedBefore = before.locations
          .firstWhere((LocationStock l) => l.location.id == line.locationId)
          .quantity;
      expect(
        after.locations
            .firstWhere((LocationStock l) => l.location.id == line.locationId)
            .quantity,
        suggestedBefore,
      );
    });

    test('hareket kaydı gerçek kaynağı gösterir', () async {
      final ProviderContainer container = makeContainer();

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');
      final PickingLine line = task.lines.firstWhere(
        (PickingLine l) => l.productId == 'p-09',
      );
      final ProductStockSummary summary = (await container.read(
        productSummaryProvider('p-09').future,
      ))!;
      final LocationStock other = summary.locations.firstWhere(
        (LocationStock l) =>
            l.location.id != line.locationId && l.quantity >= 5,
      );

      await container
          .read(warehouseActionsProvider)
          .pickLine(
            taskId: task.id,
            productId: 'p-09',
            quantity: 5,
            locationId: other.location.id,
          );

      final List<MovementDetail> movements = await container
          .read(movementRepositoryProvider)
          .getMovementsForProduct('p-09', limit: 1);
      expect(
        movements.first.sourceLocation?.id,
        other.location.id,
        reason: 'Denetim izi nereden alındığını doğru yazmalı',
      );
    });

    test('seçilen rafta yeterli stok yoksa reddedilir', () async {
      final ProviderContainer container = makeContainer();

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');
      final ProductStockSummary summary = (await container.read(
        productSummaryProvider('p-09').future,
      ))!;
      // En az stoklu raf.
      final LocationStock smallest = summary.locations.last;

      await expectLater(
        container
            .read(warehouseActionsProvider)
            .pickLine(
              taskId: task.id,
              productId: 'p-09',
              quantity: smallest.quantity + 1,
              locationId: smallest.location.id,
            ),
        throwsA(isA<Object>()),
      );
    });

    test('adım sorgusu istenen satırı döner', () async {
      final ProviderContainer container = makeContainer();

      final PickingTask task = await container
          .read(warehouseActionsProvider)
          .startPicking('ord-10452');

      final PickingStep? third = await container.read(
        pickingStepProvider(PickingStepQuery(taskId: task.id, lineIndex: 2))
            .future,
      );
      expect(third?.stepNumber, 3);
      expect(third?.product.id, 'p-10');

      final PickingStep? current = await container.read(
        pickingStepProvider(PickingStepQuery(taskId: task.id)).future,
      );
      expect(current?.stepNumber, 1);
    });
  });
}
