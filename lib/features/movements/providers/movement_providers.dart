/// Stok hareketleri modülünün durumu (şartname 19. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Hareket listesinin arama ve tür filtresi.
class MovementFilterController extends Notifier<MovementFilter> {
  @override
  MovementFilter build() => const MovementFilter();

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// Tür filtresi çoklu seçim: "giriş hareketleri" diye bakmak isteyen
  /// kullanıcı mal kabul ve iadeyi birlikte seçer.
  void toggleType(MovementType type) {
    final Set<MovementType> next = Set<MovementType>.of(state.types);
    if (!next.remove(type)) next.add(type);
    state = state.copyWith(types: next);
  }

  void setTypes(Set<MovementType> types) => state = state.copyWith(types: types);

  /// Ürün detayından "tümünü gör" ile gelindiğinde tek ürüne kilitlenir.
  void setProduct(String? productId) {
    state = productId == null
        ? state.copyWith(clearProduct: true)
        : state.copyWith(productId: productId);
  }

  void clearFilters() =>
      state = MovementFilter(query: state.query);

  void reset() => state = const MovementFilter();
}

final NotifierProvider<MovementFilterController, MovementFilter>
movementFilterProvider =
    NotifierProvider<MovementFilterController, MovementFilter>(
      MovementFilterController.new,
    );

/// Filtrelenmiş hareket listesi, yeniden eskiye.
final FutureProvider<List<MovementDetail>> movementListProvider =
    FutureProvider<List<MovementDetail>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      final MovementFilter filter = ref.watch(movementFilterProvider);
      return ref.watch(movementRepositoryProvider).getStockMovements(filter);
    });

/// Hareketleri güne göre gruplar (şartname 19: "zaman sıralı").
///
/// Gruplama ekranda değil burada yapılır: aynı listeyi iki kez dolaşmak
/// yerine tek geçişte gün başlıkları hazırlanır ve ekran yalnızca çizer.
final Provider<List<MovementDayGroup>> movementsByDayProvider =
    Provider<List<MovementDayGroup>>((Ref ref) {
      final List<MovementDetail> items =
          ref.watch(movementListProvider).value ?? const <MovementDetail>[];

      final List<MovementDayGroup> groups = <MovementDayGroup>[];
      for (final MovementDetail detail in items) {
        final DateTime moment = detail.movement.timestamp;
        final DateTime day = DateTime(moment.year, moment.month, moment.day);

        if (groups.isNotEmpty && groups.last.day == day) {
          groups.last.movements.add(detail);
        } else {
          groups.add(
            MovementDayGroup(day: day, movements: <MovementDetail>[detail]),
          );
        }
      }
      return groups;
    });

/// Bir günün hareketleri.
class MovementDayGroup {
  MovementDayGroup({required this.day, required this.movements});

  final DateTime day;
  final List<MovementDetail> movements;

  /// O gün depoya giren net adet.
  int get inbound => movements
      .where((MovementDetail m) => m.movement.quantity > 0)
      .fold(0, (int sum, MovementDetail m) => sum + m.movement.quantity);

  /// O gün depodan çıkan adet (pozitif sayı olarak).
  int get outbound => movements
      .where((MovementDetail m) => m.movement.quantity < 0)
      .fold(0, (int sum, MovementDetail m) => sum + m.movement.quantity.abs());
}
