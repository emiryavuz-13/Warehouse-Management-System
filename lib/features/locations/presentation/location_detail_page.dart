import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../providers/location_providers.dart';

/// Lokasyon detayı (şartname 18. bölüm).
///
/// *"Lokasyona girildiğinde o lokasyondaki ürünleri göster."*
///
/// **Hero figürü doluluk, toplam adet değil.** Bu ekrana gelen kişinin
/// sorusu "bu rafta kaç adet var" değil, "bu rafa daha ne sığar" ya da
/// "burası dolu mu". Adet zaten dökümün toplamı; asıl karar veren sayı
/// boş kapasite.
class LocationDetailPage extends ConsumerWidget {
  const LocationDetailPage({required this.locationId, super.key});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LocationSummary?> summary = ref.watch(
      locationSummaryProvider(locationId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(summary.value?.location.code ?? 'Lokasyon'),
      ),
      body: AsyncValueView<LocationSummary?>(
        value: summary,
        onRetry: () => ref.invalidate(locationSummaryProvider(locationId)),
        loading: const LoadingIndicator(message: 'Lokasyon yükleniyor'),
        isEmpty: (LocationSummary? value) => value == null,
        empty: const EmptyState(
          icon: AppIcons.locations,
          title: 'Lokasyon bulunamadı',
          message: 'Bu lokasyon kayıtlarda yok.',
        ),
        data: (LocationSummary? value) => _Body(summary: value!),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary});

  final LocationSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final WarehouseLocation location = summary.location;
    final AsyncValue<List<LocationStockLine>> contents = ref.watch(
      locationContentsProvider(location.id),
    );

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconBox(
                icon: location.type.icon,
                size: 48,
                iconSize: 22,
                background: status.neutralContainer,
                foreground: status.neutral,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary.zone?.name ?? 'Bölge tanımsız',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Flexible(child: CodeChip(code: location.code)),
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
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Kararı veren sayı boş kapasite: "buraya daha ne sığar".
          // Dolu/kapasite ve yüzde hemen altındaki çubukta duruyor, hero
          // kırılımında tekrarlanmıyor.
          HeroFigure(
            value: Formatters.integer.format(summary.availableCapacity),
            unit: 'adet',
            label: 'boş kapasite',
          ),

          const SizedBox(height: AppSpacing.lg),
          OccupancyBar(
            used: summary.usedQuantity,
            capacity: location.capacity,
          ),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.sm),

          InfoRow(
            label: 'Lokasyon kodu',
            value: location.code,
            valueWidget: CodeChip(code: location.code),
          ),
          InfoRow(label: 'Tip', value: location.type.label),
          InfoRow(
            label: 'Bölge',
            value: summary.zone?.name ?? 'Tanımsız',
          ),
          InfoRow(
            label: 'Kapasite',
            value: Formatters.quantity(location.capacity, 'adet'),
          ),
          InfoRow(label: 'Farklı ürün', value: '${summary.skuCount}'),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: 'Bu Lokasyondaki Ürünler',
            subtitle: summary.skuCount == 0
                ? null
                : '${summary.skuCount} farklı ürün · '
                      '${Formatters.quantity(summary.usedQuantity, 'adet')}',
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          AsyncValueView<List<LocationStockLine>>(
            value: contents,
            onRetry: () =>
                ref.invalidate(locationContentsProvider(location.id)),
            loading: const LoadingState(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('Ürünler yükleniyor'),
              ),
            ),
            isEmpty: (List<LocationStockLine> items) => items.isEmpty,
            empty: _EmptyShelf(locationCode: location.code),
            data: (List<LocationStockLine> items) => Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: status.border),
                  _ProductRow(
                    line: items[i],
                    // Pay, rafın ne kadarını bu ürünün kapladığını gösterir:
                    // "62 adedin 18'i iPhone".
                    share: summary.usedQuantity == 0
                        ? 0
                        : items[i].quantity / summary.usedQuantity,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş raf — bir hata değil, kullanılabilir bir kaynak.
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.locationCode});

  final String locationCode;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.empty, size: AppSizes.iconMd, color: status.neutral),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$locationCode boş. Mal kabul ve transfer ekranlarında '
              'hedef olarak seçilebilir.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raftaki tek ürün satırı.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.line, required this.share});

  final LocationStockLine line;
  final double share;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.push(AppRoutes.productDetail(line.product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        line.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line.product.sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.code.copyWith(
                          fontSize: 11.5,
                          color: status.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  Formatters.percent(share),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  Formatters.quantity(line.quantity, line.product.unit),
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
            const SizedBox(height: AppSpacing.sm - 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 4,
                color: colors.primary,
                backgroundColor: status.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
