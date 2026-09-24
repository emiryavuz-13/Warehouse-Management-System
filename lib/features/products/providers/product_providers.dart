/// Ürünler modülünün durumu ve veri kaynakları (şartname 8. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Ürün listesinin arama ve filtre durumu.
///
/// Filtreler tek bir nesnede tutulur; ekran her değişiklikte yalnızca
/// ilgili alanı güncelleyip listenin kendini yenilemesini bekler.
class ProductFilterController extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// Aynı kategoriye tekrar dokunulursa filtre kalkar.
  void toggleCategory(String? categoryId) {
    state = categoryId == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);
  }

  void toggleStatus(StockStatus? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void toggleLocation(String? locationId) {
    state = locationId == null
        ? state.copyWith(clearLocation: true)
        : state.copyWith(locationId: locationId);
  }

  void setSort(ProductSort sort) => state = state.copyWith(sort: sort);

  /// Filtreleri temizler, aramayı korur.
  ///
  /// Kullanıcı "temizle"ye bastığında yazdığı aramayı da kaybetmeyi
  /// beklemez; sadece daralttığı filtreleri geri almak ister.
  void clearFilters() => state = state.cleared();

  /// Her şeyi sıfırlar — ekrandan çıkılırken kullanılır.
  void reset() => state = const ProductFilter();
}

final NotifierProvider<ProductFilterController, ProductFilter>
productFilterProvider =
    NotifierProvider<ProductFilterController, ProductFilter>(
      ProductFilterController.new,
    );

/// Filtrelenmiş ürün listesi.
final FutureProvider<List<ProductStockSummary>> productListProvider =
    FutureProvider<List<ProductStockSummary>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      final ProductFilter filter = ref.watch(productFilterProvider);
      return ref.watch(productRepositoryProvider).getProducts(filter);
    });

/// Bir ürünün son hareketleri — ürün detayında gösterilir.
final productMovementsProvider =
    FutureProvider.family<List<MovementDetail>, String>((
      Ref ref,
      String productId,
    ) {
      ref.watch(dataRevisionProvider);
      return ref
          .watch(movementRepositoryProvider)
          .getMovementsForProduct(
            productId,
            limit: AppConstants.productRecentMovementCount,
          );
    });
