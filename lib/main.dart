import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';

/// Uygulamanın giriş noktası.
///
/// Burada yalnızca açılış için zorunlu hazırlıklar yapılır:
/// Türkçe tarih verisinin yüklenmesi ve Riverpod kapsamının kurulması.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `intl` paketinin Türkçe ay/gün adlarını üretebilmesi için gereklidir;
  // Formatters sınıfındaki tüm DateFormat örnekleri buna bağlıdır.
  await initializeDateFormatting('tr_TR');

  runApp(const ProviderScope(child: WarehouseApp()));
}
