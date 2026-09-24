/// Sipariş ve toplama modülünün durumu (şartname 13-14. bölümler).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Sipariş listesinin arama ve filtre durumu.
class OrderFilterController extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => const OrderFilter();

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// Durum filtresi çoklu seçimdir: depo sorumlusu genellikle "yeni ve
  /// toplanıyor" gibi bir kümeye bakar, tek bir duruma değil.
  void toggleStatus(OrderStatus status) {
    final Set<OrderStatus> next = Set<OrderStatus>.of(state.statuses);
    if (!next.remove(status)) next.add(status);
    state = state.copyWith(statuses: next);
  }

  void setStatuses(Set<OrderStatus> statuses) =>
      state = state.copyWith(statuses: statuses);

  void togglePriority(OrderPriority? priority) {
    state = priority == null || priority == state.priority
        ? state.copyWith(clearPriority: true)
        : state.copyWith(priority: priority);
  }

  void setOnlyToday(bool value) => state = state.copyWith(onlyToday: value);

  /// Filtreleri temizler, aramayı korur.
  void clearFilters() => state = state.cleared();

  void reset() => state = const OrderFilter();
}

final NotifierProvider<OrderFilterController, OrderFilter> orderFilterProvider =
    NotifierProvider<OrderFilterController, OrderFilter>(
      OrderFilterController.new,
    );

/// Filtrelenmiş sipariş listesi.
final FutureProvider<List<SalesOrder>> orderListProvider =
    FutureProvider<List<SalesOrder>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      final OrderFilter filter = ref.watch(orderFilterProvider);
      return ref.watch(orderRepositoryProvider).getOrders(filter);
    });

/// Tek bir siparişin satırları, toplama görevi ve sevkiyatı.
final orderDetailProvider = FutureProvider.family<OrderDetail?, String>((
  Ref ref,
  String orderId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(orderRepositoryProvider).getOrderDetail(orderId);
});

/// Toplama görevinin sıradaki adımı (şartname 14. bölüm).
///
/// Görev tamamlandığında `null` döner; ekran bunu "toplama bitti" olarak
/// yorumlar. Adım numarası ve toplam adım sayısı da bu nesnede gelir,
/// böylece ekranın kendi sayacı olmaz ve iki kaynak birbirinden ayrışmaz.
final pickingStepProvider = FutureProvider.family<PickingStep?, String>((
  Ref ref,
  String taskId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(orderRepositoryProvider).getCurrentPickingStep(taskId);
});
