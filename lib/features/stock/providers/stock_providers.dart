/// Stok modülünün durumu ve veri kaynakları (şartname 9. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Stok listesinin arama ve filtre durumu.
class StockFilterController extends Notifier<StockFilter> {
  @override
  StockFilter build() => const StockFilter();

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// Aynı duruma tekrar dokunulursa filtre kalkar — durum şeridindeki
  /// seçili bloğa basmak "tümü"ne dönmenin kısayoludur.
  void toggleStatus(StockStatus? status) {
    state = status == null || status == state.status
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void toggleLocation(String? locationId) {
    state = locationId == null
        ? state.copyWith(clearLocation: true)
        : state.copyWith(locationId: locationId);
  }

  /// Filtreleri temizler, aramayı korur (ürün listesiyle aynı kural).
  void clearFilters() => state = StockFilter(query: state.query);

  void reset() => state = const StockFilter();
}

final NotifierProvider<StockFilterController, StockFilter> stockFilterProvider =
    NotifierProvider<StockFilterController, StockFilter>(
      StockFilterController.new,
    );

/// Durum filtresi **uygulanmamış** stok listesi.
///
/// Repository'ye yalnızca arama ve lokasyon gider; durum daraltması burada
/// değil, [stockListProvider] içinde yapılır. İki nedeni var:
///
/// 1. Durum şeridindeki sayaçlar ("Kritik 4") sabit kalmalı. Durum filtresi
///    veri kaynağına da gitseydi, "Kritik"e basıldığında şerit `Normal 0 ·
///    Kritik 4 · Stok Yok 0` olurdu ve kullanıcı geri dönmek için neyi
///    kaybettiğini göremezdi.
/// 2. Durum değiştirmek yeniden veri çekmez — şerit anında tepki verir.
///
/// Filtrenin yalnızca gerçekten kullanılan alanları izlenir; [StockFilter]
/// değer eşitliği taşımadığı için tümünü izlemek her dokunuşta yeniden
/// sorgu anlamına gelirdi.
final FutureProvider<List<ProductStockSummary>> stockBaseProvider =
    FutureProvider<List<ProductStockSummary>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      final String query = ref.watch(
        stockFilterProvider.select((StockFilter f) => f.query),
      );
      final String? locationId = ref.watch(
        stockFilterProvider.select((StockFilter f) => f.locationId),
      );

      return ref
          .watch(stockRepositoryProvider)
          .getStocks(StockFilter(query: query, locationId: locationId));
    });

/// Ekranda gösterilen, durum filtresi uygulanmış liste.
final Provider<AsyncValue<List<ProductStockSummary>>> stockListProvider =
    Provider<AsyncValue<List<ProductStockSummary>>>((Ref ref) {
      final StockStatus? status = ref.watch(
        stockFilterProvider.select((StockFilter f) => f.status),
      );

      return ref
          .watch(stockBaseProvider)
          .whenData(
            (List<ProductStockSummary> items) => status == null
                ? items
                : items
                      .where((ProductStockSummary s) => s.status == status)
                      .toList(),
          );
    });

/// Durum şeridinin sayaçları: her stok durumunda kaç ürün var.
///
/// Durum filtresinden etkilenmez; şerit her zaman tüm resmi gösterir.
final Provider<Map<StockStatus, int>> stockStatusCountsProvider =
    Provider<Map<StockStatus, int>>((Ref ref) {
      final List<ProductStockSummary> items =
          ref.watch(stockBaseProvider).value ?? const <ProductStockSummary>[];

      return <StockStatus, int>{
        for (final StockStatus status in StockStatus.values)
          status: items
              .where((ProductStockSummary s) => s.status == status)
              .length,
      };
    });
