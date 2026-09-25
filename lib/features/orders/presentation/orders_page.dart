import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/repositories.dart';
import '../../../models/models.dart';
import '../providers/order_providers.dart';
import 'widgets/order_filter_sheet.dart';

/// Sipariş listesi (şartname 13. bölüm).
///
/// Şartnamenin istediği altı alan her satırda; filtreler durum, tarih ve
/// öncelik.
///
/// **Sıralama depo önceliğine göre.** Repository açık siparişleri üstte,
/// acil olanları önce döner. Depo çalışanı listeyi "ne toplamalıyım" diye
/// açar; sevk edilmiş siparişler o soruya cevap vermez.
class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SalesOrder>> orders = ref.watch(orderListProvider);
    final OrderFilter filter = ref.watch(orderFilterProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişler'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(AppIcons.shipment),
            tooltip: 'Sevkiyatlar',
            onPressed: () => context.push(AppRoutes.shipments),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: <Widget>[
                AppSearchBar(
                  hintText: 'Sipariş numarası veya müşteri',
                  initialValue: filter.query,
                  activeFilterCount: filter.activeCount,
                  onChanged: ref.read(orderFilterProvider.notifier).setQuery,
                  onFilterTap: () => OrderFilterSheet.show(context),
                ),
                if (filter.isActive) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: OrderActiveFilterChips(),
                  ),
                ],
              ],
            ),
          ),

          _ResultSummary(orders: orders),
          Divider(height: 1, color: status.border),

          Expanded(
            child: AsyncValueView<List<SalesOrder>>(
              value: orders,
              onRetry: () => ref.invalidate(orderListProvider),
              loading: const LoadingIndicator(message: 'Siparişler'),
              isEmpty: (List<SalesOrder> items) => items.isEmpty,
              empty: filter.query.trim().isNotEmpty
                  ? EmptyState.noResults(
                      query: filter.query,
                      onClear: filter.isActive
                          ? ref.read(orderFilterProvider.notifier).clearFilters
                          : null,
                    )
                  : EmptyState(
                      icon: AppIcons.orders,
                      title: 'Sipariş bulunamadı',
                      message: 'Seçili daraltmalarla eşleşen sipariş yok.',
                      actionLabel: filter.isActive ? 'Filtreleri temizle' : null,
                      onAction: filter.isActive
                          ? ref.read(orderFilterProvider.notifier).clearFilters
                          : null,
                    ),
              data: (List<SalesOrder> items) => AppRefreshIndicator(
                onRefresh: () async {
                  ref.read(warehouseActionsProvider).refreshAll();
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.xxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: status.border),
                  itemBuilder: (BuildContext context, int index) =>
                      ListEntrance(
                        index: index,
                        child: OrderCard(
                          order: items[index],
                          onTap: () => context.push(
                            AppRoutes.orderDetail(items[index].id),
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste başındaki özet.
///
/// Toplam adet değil **bekleyen iş** öne çıkar: kaç sipariş toplanmayı
/// bekliyor. Sevk edilmiş siparişleri saymak bu ekranda bilgi taşımaz.
class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.orders});

  final AsyncValue<List<SalesOrder>> orders;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final List<SalesOrder> items = orders.value ?? const <SalesOrder>[];
    if (items.isEmpty) return const SizedBox(height: AppSpacing.sm);

    final int openCount = items
        .where((SalesOrder o) => !o.status.isClosed)
        .length;
    final int urgentCount = items
        .where(
          (SalesOrder o) =>
              o.priority == OrderPriority.urgent && !o.status.isClosed,
        )
        .length;
    final int totalQuantity = items.fold(
      0,
      (int sum, SalesOrder o) => sum + o.totalQuantity,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${items.length} sipariş · $openCount açık · '
              '${Formatters.integer.format(totalQuantity)} adet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
          if (urgentCount > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(StatusTone.danger.icon, size: 13, color: status.danger),
                const SizedBox(width: 4),
                Text(
                  '$urgentCount acil',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: status.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
