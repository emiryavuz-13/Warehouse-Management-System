import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warehouse_management_system/app/app.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('uygulama açılır ve tema uygulanır', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WarehouseApp()));
    await tester.pumpAndSettle();

    expect(find.text('Depo Yönetimi'), findsOneWidget);

    // Kurumsal tema yüklendiyse Material 3 aktif olmalıdır.
    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme, isNotNull);
  });
}
