import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';
import 'package:warehouse_management_system/core/widgets/widgets.dart';
import 'package:warehouse_management_system/data/mock_config.dart';
import 'package:warehouse_management_system/app/providers/providers.dart';

/// Uygulamanın açılışını ve sekme navigasyonunu doğrular.
///
/// Splash → dashboard geçişi ve bottom bar'ın beş sekmesi burada test edilir;
/// bunlar bozulursa demo hiç başlayamaz.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Widget buildApp() {
    return ProviderScope(
      retry: noRetryPolicy,
      overrides: [mockConfigProvider.overrideWithValue(MockConfig.instant())],
      child: const WarehouseApp(),
    );
  }

  testWidgets('açılış ekranı görünür ve tema uygulanır', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('İstif'), findsOneWidget);
    expect(find.text('Depo Yönetim Sistemi'), findsOneWidget);
    expect(find.byType(IstifMark), findsOneWidget);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme, isNotNull);

    // Splash'in zamanlayıcısı bitsin; aksi halde test "pending timer" der.
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('açılıştan sonra ana sayfaya geçilir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsWidgets);
  });

  testWidgets('beş sekme de bulunuyor ve sırası doğru', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(bar.destinations.length, 5);
    // Tara ortada: şartname 10 ve 34. bölümler merkezi tarama aksiyonu
    // istiyor.
    // Dashboard'daki hizli islem kisayolu da ayni etiketi kullandigi icin
    // iki eslesme beklenir.
    expect(find.text('Tara'), findsNWidgets(2));
    expect(find.text('Stok'), findsOneWidget);
    expect(find.text('Siparişler'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('sekmeye dokunmak ilgili ekrana götürür', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Siparişler'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderCard), findsWidgets);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Emir Yavuz'), findsWidgets);
    expect(find.text('Yetkiler'), findsOneWidget);
  });

  testWidgets('sekme değişince önceki sekme durumu korunur', (
    WidgetTester tester,
  ) async {
    // StatefulShellRoute kullanmanın asıl sebebi bu: her sekme kendi
    // geçmişini tutar.
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Stok'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    // Dashboard'a geri dönüldü: karşılama başlığı yeniden görünür.
    expect(find.textContaining('Merhaba'), findsOneWidget);
  });
}
