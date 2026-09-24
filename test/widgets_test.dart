import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/theme/app_theme.dart';
import 'package:warehouse_management_system/app/theme/status_tone_colors.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/views.dart';
import 'package:warehouse_management_system/data/warehouse_exception.dart';
import 'package:warehouse_management_system/models/models.dart';

/// Bileşen kütüphanesini doğrular.
///
/// Testler bilerek **gerçek telefon genişliğinde** çalışır. Kartlar uzun ürün
/// adı ve büyük sayılarla doldurulur; Flutter taşma (overflow) durumunda
/// testi düşürdüğü için dar ekranda bozulan bir düzen burada yakalanır.
/// Emülatörde gözle fark edilmesi çok daha zor olurdu.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  /// Dar bir telefon ekranı: 360x690 (yaygın Android alt sınırı).
  Future<void> pumpDark(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  const Product product = Product(
    id: 'p-01',
    sku: 'IP15-128-BLK',
    name: 'iPhone 15 128GB Siyah Titanyum Özel Seri',
    barcode: '8691234567890',
    brand: 'Apple',
    categoryId: 'c-01',
    unit: 'adet',
    minStock: 10,
  );

  const WarehouseLocation location = WarehouseLocation(
    id: 'loc-a0101',
    code: 'A-01-01',
    zoneId: 'z-a',
    warehouseId: 'w-01',
    type: LocationType.storage,
    capacity: 120,
  );

  ProductStockSummary summaryWith(int quantity) => ProductStockSummary(
    product: product,
    category: const ProductCategory(
      id: 'c-01',
      name: 'Telefon & Tablet',
      iconKey: 'phone',
    ),
    totalQuantity: quantity,
    locations: <LocationStock>[
      LocationStock(location: location, quantity: quantity),
    ],
  );

  group('StatusBadge', () {
    testWidgets('etiketi ve ton ikonunu gösterir', (WidgetTester tester) async {
      await pumpDark(
        tester,
        const StatusBadge(label: 'Kritik', tone: StatusTone.warning),
      );

      expect(find.text('Kritik'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('stok rozeti miktardan doğru durumu türetir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        Column(
          children: <Widget>[
            StockStatusBadge.fromQuantity(quantity: 24, minStock: 10),
            StockStatusBadge.fromQuantity(quantity: 8, minStock: 10),
            StockStatusBadge.fromQuantity(quantity: 0, minStock: 10),
          ],
        ),
      );

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Kritik'), findsOneWidget);
      expect(find.text('Stok Yok'), findsOneWidget);
    });

    testWidgets('normal öncelikli sipariş rozet üretmez', (
      WidgetTester tester,
    ) async {
      // Her siparişe rozet basmak listeyi gürültüye boğar.
      await pumpDark(
        tester,
        const Column(
          children: <Widget>[
            OrderPriorityBadge(priority: OrderPriority.normal),
            OrderPriorityBadge(priority: OrderPriority.urgent),
          ],
        ),
      );

      expect(find.text('Normal'), findsNothing);
      expect(find.text('Acil'), findsOneWidget);
    });
  });

  group('ProductCard', () {
    testWidgets('uzun ürün adıyla dar ekranda taşmaz', (
      WidgetTester tester,
    ) async {
      await pumpDark(tester, ProductCard(summary: summaryWith(1248)));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('iPhone 15'), findsOneWidget);
      // SKU ve lokasyon tek meta satırında birleşir.
      expect(find.textContaining('IP15-128-BLK'), findsOneWidget);
      expect(find.textContaining('A-01-01'), findsOneWidget);
      // Binlik ayraç Türkçe biçimde.
      expect(find.text('1.248'), findsOneWidget);
    });

    testWidgets('kritik stokta uyarı rozeti gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(tester, ProductCard(summary: summaryWith(5)));

      expect(find.text('Kritik'), findsOneWidget);
    });

    testWidgets('normal stokta rozet gösterilmez', (WidgetTester tester) async {
      // Her satıra "Normal" rozeti basmak listeyi yeşile boğar ve asıl
      // dikkat edilmesi gerekenleri görünmez kılar.
      await pumpDark(tester, ProductCard(summary: summaryWith(240)));

      expect(find.text('Normal'), findsNothing);
      expect(find.text('Kritik'), findsNothing);
    });

    testWidgets('dokunma geri çağrısı çalışır', (WidgetTester tester) async {
      int taps = 0;
      await pumpDark(
        tester,
        ProductCard(summary: summaryWith(24), onTap: () => taps++),
      );

      await tester.tap(find.byType(ProductCard));
      expect(taps, 1);
    });
  });

  group('OrderCard', () {
    SalesOrder buildOrder(OrderStatus status, {int picked = 0}) => SalesOrder(
      id: 'ord-10452',
      orderNumber: '10452',
      customerName: 'ABC Teknoloji Sanayi ve Ticaret Limited Şirketi',
      status: status,
      priority: OrderPriority.urgent,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      items: <OrderItem>[
        OrderItem(
          productId: 'p-01',
          requestedQuantity: 8,
          pickedQuantity: picked,
        ),
      ],
    );

    testWidgets('uzun müşteri adıyla taşmaz', (WidgetTester tester) async {
      await pumpDark(
        tester,
        OrderCard(order: buildOrder(OrderStatus.newOrder)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('#10452'), findsOneWidget);
      expect(find.text('Acil'), findsOneWidget);
    });

    testWidgets('toplanıyor durumunda ilerleme çubuğu gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        OrderCard(order: buildOrder(OrderStatus.picking, picked: 3)),
      );

      expect(find.byType(TaskProgressBar), findsOneWidget);
      expect(find.text('3 / 8'), findsOneWidget);
    });

    testWidgets('yeni siparişte ilerleme çubuğu gösterilmez', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        OrderCard(order: buildOrder(OrderStatus.newOrder)),
      );

      expect(find.byType(TaskProgressBar), findsNothing);
    });
  });

  group('LocationCard', () {
    testWidgets('doluluk oranını yüzde olarak gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        const LocationCard(
          summary: LocationSummary(
            location: location,
            zone: Zone(
              id: 'z-a',
              warehouseId: 'w-01',
              code: 'A',
              name: 'A Bölgesi',
            ),
            usedQuantity: 30,
            skuCount: 2,
          ),
        ),
      );

      expect(find.text('A-01-01'), findsOneWidget);
      expect(find.text('A Bölgesi'), findsOneWidget);
      expect(find.text('30 / 120'), findsOneWidget);
      expect(find.text('%25'), findsOneWidget);
    });

    testWidgets('boş lokasyonda "Boş" rozeti çıkar', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        const LocationCard(
          summary: LocationSummary(
            location: location,
            zone: null,
            usedQuantity: 0,
            skuCount: 0,
          ),
        ),
      );

      expect(find.text('Boş'), findsOneWidget);
    });
  });

  group('MovementTile', () {
    MovementDetail buildMovement(MovementType type, int quantity) {
      return MovementDetail(
        movement: StockMovement(
          id: 'mov-01',
          productId: 'p-01',
          quantity: quantity,
          type: type,
          userId: 'usr-01',
          timestamp: DateTime(2026, 9, 24, 12, 42),
          reference: 'GR-1024 · ABC Elektronik',
          targetLocationId: 'loc-a0101',
        ),
        product: product,
        targetLocation: location,
      );
    }

    testWidgets('girişte işaretli miktar gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        MovementTile(detail: buildMovement(MovementType.goodsReceipt, 10)),
      );

      expect(find.text('+10'), findsOneWidget);
      expect(find.text('12:42'), findsOneWidget);
    });

    testWidgets('çıkışta eksi işaretli gösterir', (WidgetTester tester) async {
      await pumpDark(
        tester,
        MovementTile(detail: buildMovement(MovementType.pick, -2)),
      );

      expect(find.text('-2'), findsOneWidget);
    });

    testWidgets('transferde işaretsiz gösterir', (WidgetTester tester) async {
      // Transfer toplam stoku değiştirmediği için +/- yanıltıcı olurdu.
      await pumpDark(
        tester,
        MovementTile(detail: buildMovement(MovementType.transfer, 5)),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('+5'), findsNothing);
    });
  });

  group('Durum ekranları', () {
    testWidgets('boş durum mesajı ve eylemi gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        const EmptyState(message: 'Henüz sipariş bulunmuyor.'),
      );

      expect(find.text('Henüz sipariş bulunmuyor.'), findsOneWidget);
    });

    testWidgets('sonuç bulunamadı varyantı aramayı yansıtır', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        EmptyState.noResults(query: 'iphone', onClear: () {}),
      );

      expect(find.textContaining('"iphone"'), findsOneWidget);
      expect(find.text('Filtreleri temizle'), findsOneWidget);
    });

    testWidgets('iş kuralı hatası kendi mesajını gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        ErrorState(
          error: WarehouseException.insufficientStock(
            productName: 'iPhone 15',
            locationCode: 'A-01-01',
            available: 3,
            requested: 5,
          ),
        ),
      );

      expect(find.textContaining('A-01-01'), findsOneWidget);
      expect(find.textContaining('3 adet var'), findsOneWidget);
    });

    testWidgets('beklenmeyen hatada teknik ayrıntı sızdırmaz', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        const ErrorState(error: FormatException('null pointer at 0x1F')),
      );

      expect(find.textContaining('0x1F'), findsNothing);
      expect(find.textContaining('Beklenmeyen bir hata'), findsOneWidget);
    });

    testWidgets('tekrar dene butonu çalışır', (WidgetTester tester) async {
      int retries = 0;
      await pumpDark(
        tester,
        ErrorState(
          error: WarehouseException.simulatedFailure(),
          onRetry: () => retries++,
        ),
      );

      await tester.tap(find.text('Tekrar dene'));
      expect(retries, 1);
    });
  });

  group('QuantitySelector', () {
    testWidgets('artı ve eksi düğmeleri değeri değiştirir', (
      WidgetTester tester,
    ) async {
      int value = 5;
      await pumpDark(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return QuantitySelector(
              value: value,
              max: 10,
              onChanged: (int next) => setState(() => value = next),
            );
          },
        ),
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await tester.pump();
      expect(value, 6);

      await tester.tap(find.byIcon(AppIcons.remove));
      await tester.pump();
      expect(value, 5);
    });

    testWidgets('"Tümü" kısayolu değeri üst sınıra çeker', (
      WidgetTester tester,
    ) async {
      int value = 0;
      await pumpDark(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return QuantitySelector(
              value: value,
              max: 50,
              onChanged: (int next) => setState(() => value = next),
            );
          },
        ),
      );

      await tester.tap(find.text('Tümü (50 adet)'));
      await tester.pump();
      expect(value, 50);
    });

    testWidgets('üst sınır aşılınca uyarı gösterir ama değeri düzeltmez', (
      WidgetTester tester,
    ) async {
      // Sessizce düzeltmek, kullanıcının yanlış yazdığını fark etmesini
      // engeller.
      await pumpDark(
        tester,
        QuantitySelector(value: 60, max: 50, onChanged: (_) {}),
      );

      expect(find.textContaining('En fazla 50'), findsOneWidget);
    });

    testWidgets('alt sınırda eksi düğmesi devre dışı', (
      WidgetTester tester,
    ) async {
      int value = 0;
      await pumpDark(
        tester,
        QuantitySelector(
          value: value,
          min: 0,
          max: 10,
          onChanged: (int next) => value = next,
        ),
      );

      await tester.tap(find.byIcon(AppIcons.remove));
      await tester.pump();
      expect(value, 0);
    });
  });

  group('QuickActionCard', () {
    testWidgets('etiket ve bekleyen is rozetini gosterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        SizedBox(
          width: 80,
          child: QuickActionCard(
            label: 'Mal Kabul',
            icon: AppIcons.receiving,
            badgeCount: 3,
            onTap: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Mal Kabul'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('bekleyen is yoksa rozet gizlenir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        SizedBox(
          width: 80,
          child: QuickActionCard(
            label: 'Transfer',
            icon: AppIcons.transfer,
            badgeCount: 0,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
    });
  });

  group('AsyncValueView', () {
    testWidgets('veri geldiğinde içeriği çizer', (WidgetTester tester) async {
      await pumpDark(
        tester,
        AsyncValueView<List<String>>(
          value: const AsyncValue<List<String>>.data(<String>['a', 'b']),
          isEmpty: (List<String> items) => items.isEmpty,
          data: (List<String> items) => Text('${items.length} kayıt'),
        ),
      );

      expect(find.text('2 kayıt'), findsOneWidget);
    });

    testWidgets('boş listede boş durumu gösterir', (WidgetTester tester) async {
      await pumpDark(
        tester,
        AsyncValueView<List<String>>(
          value: const AsyncValue<List<String>>.data(<String>[]),
          isEmpty: (List<String> items) => items.isEmpty,
          empty: const EmptyState(message: 'Henüz kayıt yok.'),
          data: (List<String> items) => const Text('veri'),
        ),
      );

      expect(find.text('Henüz kayıt yok.'), findsOneWidget);
      expect(find.text('veri'), findsNothing);
    });

    testWidgets('hata durumunda hata ekranını gösterir', (
      WidgetTester tester,
    ) async {
      await pumpDark(
        tester,
        AsyncValueView<List<String>>(
          value: AsyncValue<List<String>>.error(
            WarehouseException.simulatedFailure(),
            StackTrace.empty,
          ),
          data: (List<String> items) => const Text('veri'),
        ),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('veri'), findsNothing);
    });
  });

  group('Dialoglar', () {
    testWidgets('onay dialogu işlem özetini gösterir ve true döner', (
      WidgetTester tester,
    ) async {
      // Şartname 30: "Emin misiniz?" yetmez, ne olacağı yazmalı.
      bool? result;

      await pumpDark(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context: context,
                title: 'Transferi onayla',
                message: 'Bu transferi gerçekleştirmek istiyor musunuz?',
                details: const <ConfirmationDetail>[
                  ConfirmationDetail(label: 'Ürün', value: 'iPhone 15'),
                  ConfirmationDetail(label: 'Yol', value: 'A-01-01 → B-03-02'),
                  ConfirmationDetail(label: 'Miktar', value: '5 adet'),
                ],
              );
            },
            child: const Text('Aç'),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.text('A-01-01 → B-03-02'), findsOneWidget);
      expect(find.text('5 adet'), findsOneWidget);

      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('vazgeçilince false döner', (WidgetTester tester) async {
      bool? result;

      await pumpDark(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context: context,
                title: 'Sil',
                message: 'Emin misiniz?',
              );
            },
            child: const Text('Aç'),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('başarı dialogu sonucu ve ikincil eylemi gösterir', (
      WidgetTester tester,
    ) async {
      bool? wentToShipment;

      await pumpDark(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              wentToShipment = await SuccessDialog.show(
                context: context,
                title: 'Transfer tamamlandı',
                details: const <ConfirmationDetail>[
                  ConfirmationDetail(label: 'A-01-01', value: '18 → 13'),
                  ConfirmationDetail(label: 'B-03-02', value: '6 → 11'),
                ],
                secondaryLabel: 'Sevkiyata Geç',
              );
            },
            child: const Text('Aç'),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.text('18 → 13'), findsOneWidget);
      expect(find.text('6 → 11'), findsOneWidget);

      await tester.tap(find.text('Sevkiyata Geç'));
      await tester.pumpAndSettle();
      expect(wentToShipment, isTrue);
    });
  });

  group('Bilgi bileşenleri', () {
    testWidgets('kod çipi monospace stille çizilir', (
      WidgetTester tester,
    ) async {
      await pumpDark(tester, const CodeChip(code: 'A-01-01'));

      final Text text = tester.widget<Text>(find.text('A-01-01'));
      expect(text.style?.fontFamily, 'monospace');
    });

    testWidgets('doluluk çubuğu kapasite aşımında bile taşmaz', (
      WidgetTester tester,
    ) async {
      await pumpDark(tester, const OccupancyBar(used: 200, capacity: 120));

      expect(tester.takeException(), isNull);
      expect(find.text('%100'), findsOneWidget);
    });

    testWidgets('sıfır kapasiteli lokasyonda bölme hatası olmaz', (
      WidgetTester tester,
    ) async {
      await pumpDark(tester, const OccupancyBar(used: 0, capacity: 0));

      expect(tester.takeException(), isNull);
      expect(find.text('%0'), findsOneWidget);
    });

    testWidgets('bölüm başlığı eylem bağlantısını gösterir', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpDark(
        tester,
        SectionHeader(
          title: 'Son Hareketler',
          actionLabel: 'Tümünü gör',
          onAction: () => taps++,
        ),
      );

      await tester.tap(find.text('Tümünü gör'));
      expect(taps, 1);
    });
  });
}
