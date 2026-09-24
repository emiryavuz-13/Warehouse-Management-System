/// Mal kabul modülünün veri kaynakları (şartname 11-12. bölümler).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Tüm mal kabul kayıtları — açık olanlar üstte.
final FutureProvider<List<GoodsReceipt>> receiptsProvider =
    FutureProvider<List<GoodsReceipt>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(orderRepositoryProvider).getGoodsReceipts();
    });

/// Tek bir mal kabul kaydının satırları ve ürün bilgileri.
final receiptDetailProvider = FutureProvider.family<ReceiptDetail?, String>((
  Ref ref,
  String receiptId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(orderRepositoryProvider).getReceiptDetail(receiptId);
});

/// Yerleştirme ekranının lokasyon listesi (şartname 12. bölüm).
///
/// Sıralama rastgele değil, **operasyonel**:
///
/// 1. Ürünün hâlihazırda bulunduğu raflar en üstte. Gerçek depoda aynı ürün
///    mümkün olduğunca tek yerde toplanır; dağıtmak toplamayı yavaşlatır.
/// 2. Sonra boş kapasitesi çok olanlar — az yer kalan rafa koymak bir
///    sonraki sevkiyatta sorun çıkarır.
///
/// Kapasitesi yetmeyen raflar listeden çıkarılmaz, işaretlenir: kullanıcı
/// neden seçemediğini görmeli.
final putawayLocationsProvider =
    FutureProvider.family<List<PutawayLocation>, String>((
      Ref ref,
      String productId,
    ) async {
      ref.watch(dataRevisionProvider);

      final List<LocationSummary> locations = await ref.watch(
        locationsProvider.future,
      );
      final ProductStockSummary? summary = await ref.watch(
        productSummaryProvider(productId).future,
      );

      final Set<String> holdingIds = <String>{
        for (final LocationStock stock in summary?.locations ?? const <LocationStock>[])
          stock.location.id,
      };

      final List<PutawayLocation> result = <PutawayLocation>[
        for (final LocationSummary location in locations)
          PutawayLocation(
            summary: location,
            alreadyHoldsProduct: holdingIds.contains(location.location.id),
          ),
      ];

      result.sort((PutawayLocation a, PutawayLocation b) {
        if (a.alreadyHoldsProduct != b.alreadyHoldsProduct) {
          return a.alreadyHoldsProduct ? -1 : 1;
        }
        return b.summary.availableCapacity.compareTo(
          a.summary.availableCapacity,
        );
      });

      return result;
    });

/// Yerleştirme listesindeki tek lokasyon.
class PutawayLocation {
  const PutawayLocation({
    required this.summary,
    required this.alreadyHoldsProduct,
  });

  final LocationSummary summary;

  /// Ürün bu rafta zaten var mı? Arayüz bunu "önerilen" olarak gösterir.
  final bool alreadyHoldsProduct;

  /// Verilen miktar bu rafa sığar mı?
  bool fits(int quantity) => summary.availableCapacity >= quantity;
}
