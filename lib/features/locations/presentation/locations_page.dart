import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../providers/location_providers.dart';

/// Lokasyon ağacı (şartname 18. bölüm).
///
/// Şartnamenin istediği yapı: depo → bölge → lokasyon.
///
/// **Ağaç açılır-kapanır değil, düz gruplu bir liste.** Beş bölge ve on beş
/// lokasyon var; katlanabilir bir ağaçta kullanıcı aradığı rafı görmek için
/// önce bölgeyi açmak zorunda kalır. Bölge başlıkları ayraçla ayrılmış
/// gruplar olarak durduğunda hem yapı görünür hem her raf tek bakışta.
///
/// Arama doğrudan koda bakar: depo çalışanı "A-01" yazıp o koridora iner.
class LocationsPage extends ConsumerWidget {
  const LocationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ZoneGroup>> tree = ref.watch(locationTreeProvider);
    final String query = ref.watch(locationQueryProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: AppBar(title: const Text('Lokasyonlar')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppSearchBar(
              hintText: 'Lokasyon kodu, ör. A-01',
              initialValue: query,
              onChanged: ref.read(locationQueryProvider.notifier).set,
            ),
          ),
          const _WarehouseSelector(),
          const _WarehouseSummary(),
          Divider(height: 1, color: status.border),
          Expanded(
            child: AsyncValueView<List<ZoneGroup>>(
              value: tree,
              onRetry: () => ref.invalidate(locationTreeProvider),
              loading: const LoadingIndicator(message: 'Lokasyonlar'),
              isEmpty: (List<ZoneGroup> groups) => groups.isEmpty,
              empty: query.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.locations,
                      title: 'Lokasyon yok',
                      message: 'Bu depoda tanımlı lokasyon bulunmuyor.',
                    )
                  : EmptyState.noResults(
                      query: query,
                      onClear: () =>
                          ref.read(locationQueryProvider.notifier).set(''),
                    ),
              data: (List<ZoneGroup> groups) => AppRefreshIndicator(
                onRefresh: () async {
                  ref.read(warehouseActionsProvider).refreshAll();
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: <Widget>[
                    for (final ZoneGroup group in groups) ...<Widget>[
                      _ZoneHeader(group: group),
                      for (int i = 0; i < group.locations.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: AppSpacing.lg,
                            color: status.border,
                          ),
                        _LocationRow(summary: group.locations[i]),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Depo seçici — yalnızca birden fazla depo varsa görünür.
///
/// Seçim bu ekranla sınırlı; uygulamanın çalıştığı depoyu değiştirmez.
/// Lokasyon listesi bir tarama ekranı, başka bir depoya bakmak operasyon
/// deposunu değiştirmemeli.
class _WarehouseSelector extends ConsumerWidget {
  const _WarehouseSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Warehouse> warehouses =
        ref.watch(warehousesProvider).value ?? const <Warehouse>[];
    if (warehouses.length < 2) return const SizedBox.shrink();

    final String? selected = ref.watch(effectiveWarehouseIdProvider).value;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppStatusColors status = Theme.of(context).status;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: warehouses.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final Warehouse warehouse = warehouses[index];
          final bool isSelected = warehouse.id == selected;

          return Material(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              onTap: () => ref
                  .read(browsedWarehouseProvider.notifier)
                  .select(warehouse.id),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected ? colors.primary : status.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  warehouse.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected ? colors.primary : colors.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Deponun tek satırlık özeti.
class _WarehouseSummary extends ConsumerWidget {
  const _WarehouseSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final List<ZoneGroup> groups =
        ref.watch(locationTreeProvider).value ?? const <ZoneGroup>[];
    if (groups.isEmpty) return const SizedBox(height: AppSpacing.sm);

    final int locationCount = groups.fold(
      0,
      (int sum, ZoneGroup g) => sum + g.locations.length,
    );
    final int total = groups.fold(
      0,
      (int sum, ZoneGroup g) => sum + g.totalQuantity,
    );
    final int capacity = groups.fold(
      0,
      (int sum, ZoneGroup g) => sum + g.totalCapacity,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${groups.length} bölge · $locationCount lokasyon',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
          // Deponun genel doluluğu: tek tek rafları toplamadan görülmeli.
          Text(
            '${Formatters.integer.format(total)} / '
            '${Formatters.integer.format(capacity)} adet',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ],
      ),
    );
  }
}

/// Bölge başlığı — şartnamedeki ağacın dalı.
class _ZoneHeader extends StatelessWidget {
  const _ZoneHeader({required this.group});

  final ZoneGroup group;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            group.zone.name.toUpperCaseTr(),
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(height: 1, color: status.border)),
          const SizedBox(width: AppSpacing.md),
          // "3 / 5 dolu": bölgede kaç rafın kullanıldığını söyler.
          Text(
            '${group.occupiedCount} / ${group.locations.length} dolu',
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
        ],
      ),
    );
  }
}

/// Lokasyon satırı.
///
/// Şartnamenin istediği alanlar: kod, bölge, kapasite, doluluk, SKU sayısı,
/// toplam adet. Bölge adı satırda tekrarlanmaz — zaten bölge başlığının
/// altındadır.
class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.summary});

  final LocationSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final WarehouseLocation location = summary.location;

    return InkWell(
      onTap: () => context.push(AppRoutes.locationDetail(location.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              location.type.icon,
              size: AppSizes.iconMd,
              color: status.neutral,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          location.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.code.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (summary.isNearlyFull) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        const StatusBadge(
                          label: 'Dolmak üzere',
                          tone: StatusTone.warning,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.isEmpty
                        ? 'Boş · kapasite ${location.capacity}'
                        : '${summary.skuCount} ürün · '
                              '${Formatters.integer.format(summary.usedQuantity)}'
                              ' / ${Formatters.integer.format(location.capacity)}'
                              ' adet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                  const SizedBox(height: AppSpacing.sm - 2),
                  OccupancyBar(
                    used: summary.usedQuantity,
                    capacity: location.capacity,
                    showLabels: false,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              Formatters.percent(summary.occupancyRatio),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              AppIcons.forward,
              size: AppSizes.iconSm,
              color: status.neutral,
            ),
          ],
        ),
      ),
    );
  }
}
