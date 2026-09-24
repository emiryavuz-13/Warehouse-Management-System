/// Stok transferi modülünün veri kaynakları (şartname 15. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/views.dart';

/// Transfer edilebilecek ürünler.
///
/// Stoğu sıfır olan ürünler listelenmez: transferin kaynağı olamazlar ve
/// listede durmaları kullanıcıyı seçtikten sonra çıkmaz bir ekrana götürür.
final FutureProvider<List<ProductStockSummary>> transferableProductsProvider =
    FutureProvider<List<ProductStockSummary>>((Ref ref) async {
      ref.watch(dataRevisionProvider);

      final List<ProductStockSummary> all = await ref
          .watch(stockRepositoryProvider)
          .getStocks();

      return all
          .where((ProductStockSummary s) => s.totalQuantity > 0)
          .toList();
    });

/// Transferin hedef olabilecek lokasyonları.
///
/// Kaynak lokasyon listeden çıkarılır — aynı rafa transfer bir işlem değil,
/// bir yanlışlıktır (şartname 26. bölüm). Listede bırakıp hata vermek yerine
/// baştan sunmamak, kullanıcıyı onaya kadar götürmekten iyidir.
final targetLocationsProvider =
    FutureProvider.family<List<TransferTarget>, TransferTargetQuery>((
      Ref ref,
      TransferTargetQuery query,
    ) async {
      ref.watch(dataRevisionProvider);

      final List<LocationSummary> locations = await ref.watch(
        locationsProvider.future,
      );
      final ProductStockSummary? summary = await ref.watch(
        productSummaryProvider(query.productId).future,
      );

      final Set<String> holdingIds = <String>{
        for (final LocationStock stock
            in summary?.locations ?? const <LocationStock>[])
          stock.location.id,
      };

      final List<TransferTarget> result = <TransferTarget>[
        for (final LocationSummary location in locations)
          if (location.location.id != query.sourceLocationId)
            TransferTarget(
              summary: location,
              alreadyHoldsProduct: holdingIds.contains(location.location.id),
            ),
      ];

      // Ürünün zaten bulunduğu raflar üstte: transferin en sık amacı stoğu
      // dağıtmak değil toplamaktır. Sonra boş kapasitesi çok olanlar.
      result.sort((TransferTarget a, TransferTarget b) {
        if (a.alreadyHoldsProduct != b.alreadyHoldsProduct) {
          return a.alreadyHoldsProduct ? -1 : 1;
        }
        return b.summary.availableCapacity.compareTo(
          a.summary.availableCapacity,
        );
      });

      return result;
    });

/// [targetLocationsProvider] için birleşik anahtar.
class TransferTargetQuery {
  const TransferTargetQuery({
    required this.productId,
    required this.sourceLocationId,
  });

  final String productId;
  final String? sourceLocationId;

  @override
  bool operator ==(Object other) =>
      other is TransferTargetQuery &&
      other.productId == productId &&
      other.sourceLocationId == sourceLocationId;

  @override
  int get hashCode => Object.hash(productId, sourceLocationId);
}

/// Hedef lokasyon seçeneği.
class TransferTarget {
  const TransferTarget({
    required this.summary,
    required this.alreadyHoldsProduct,
  });

  final LocationSummary summary;

  /// Ürün bu rafta zaten var mı?
  final bool alreadyHoldsProduct;

  bool fits(int quantity) => summary.availableCapacity >= quantity;
}
