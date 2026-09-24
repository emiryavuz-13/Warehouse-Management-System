import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../models/models.dart';
import '../../providers/order_providers.dart';

/// Sipariş filtresi (şartname 13. bölüm: durum, tarih, öncelik).
///
/// Durum **çoklu** seçimdir. Depo sorumlusu genellikle tek bir duruma değil
/// bir kümeye bakar — "yeni ve toplanıyor" gibi. Tek seçim, açık siparişleri
/// görmek için iki kez filtre açmayı gerektirirdi.
///
/// Tarih filtresi tam bir tarih aralığı değil, tek bir anahtar: "bugün
/// gelenler". Mock veri bir haftalık; aralık seçici burada kullanılmayan bir
/// karmaşıklık olurdu.
class OrderFilterSheet extends ConsumerWidget {
  const OrderFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return FilterSheet.show(
      context: context,
      builder: (BuildContext context) => const OrderFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrderFilter filter = ref.watch(orderFilterProvider);
    final OrderFilterController controller = ref.read(
      orderFilterProvider.notifier,
    );

    return FilterSheet(
      title: 'Sipariş Filtresi',
      onApply: () => Navigator.of(context).pop(),
      onClear: filter.isActive ? controller.clearFilters : null,
      sections: <Widget>[
        MultiFilterSection<OrderStatus>(
          title: 'Durum',
          options: OrderStatus.values,
          selected: filter.statuses,
          labelBuilder: (OrderStatus s) => s.label,
          toneBuilder: (OrderStatus s) => s.tone,
          onChanged: controller.setStatuses,
        ),

        FilterSection<OrderPriority>(
          title: 'Öncelik',
          options: OrderPriority.values,
          selected: filter.priority,
          labelBuilder: (OrderPriority p) => p.label,
          toneBuilder: (OrderPriority p) => p.tone,
          onSelected: controller.togglePriority,
        ),

        FilterSection<bool>(
          title: 'Tarih',
          options: const <bool>[true],
          selected: filter.onlyToday ? true : null,
          labelBuilder: (_) => 'Bugün gelenler',
          noneLabel: 'Tüm tarihler',
          onSelected: (bool? value) => controller.setOnlyToday(value ?? false),
        ),
      ],
    );
  }
}

/// Listenin üstündeki etkin filtre çipleri.
class OrderActiveFilterChips extends ConsumerWidget {
  const OrderActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrderFilter filter = ref.watch(orderFilterProvider);
    if (!filter.isActive) return const SizedBox.shrink();

    final OrderFilterController controller = ref.read(
      orderFilterProvider.notifier,
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final OrderStatus status in filter.statuses)
          RemovableChip(
            label: status.label,
            tone: status.tone,
            onRemove: () => controller.toggleStatus(status),
          ),
        if (filter.priority != null)
          RemovableChip(
            label: filter.priority!.label,
            tone: filter.priority!.tone,
            onRemove: () => controller.togglePriority(null),
          ),
        if (filter.onlyToday)
          RemovableChip(
            label: 'Bugün',
            onRemove: () => controller.setOnlyToday(false),
          ),
      ],
    );
  }
}
