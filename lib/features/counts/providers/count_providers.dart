/// Stok sayımı modülünün veri kaynakları (şartname 16. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Tüm sayım kayıtları — açık olanlar üstte.
final FutureProvider<List<InventoryCount>> countsProvider =
    FutureProvider<List<InventoryCount>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(stockRepositoryProvider).getInventoryCounts();
    });

/// Tek bir sayımın satırları, lokasyonu ve ürün bilgileri.
final countDetailProvider = FutureProvider.family<CountDetail?, String>((
  Ref ref,
  String countId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(stockRepositoryProvider).getCountDetail(countId);
});
