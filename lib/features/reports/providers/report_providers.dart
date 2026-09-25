/// Raporlama modülünün veri kaynakları (şartname 22. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/views.dart';

/// Kritik ve tükenmiş ürünlerin **tamamı**.
///
/// Dashboard'daki `criticalProductsProvider` ilk dörtle sınırlı: orada amaç
/// dikkat çekmek, burada amaç rapor vermek. Raporun eksik liste göstermesi,
/// raporu okuyanın yanlış karar vermesine yol açar.
final FutureProvider<List<ProductStockSummary>> allCriticalProductsProvider =
    FutureProvider<List<ProductStockSummary>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(productRepositoryProvider).getCriticalProducts();
    });
