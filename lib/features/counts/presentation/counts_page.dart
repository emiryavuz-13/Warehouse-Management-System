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
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../providers/count_providers.dart';

/// Sayım listesi (şartname 16. bölüm).
///
/// Şartnamenin örneği tek bir kaydı gösteriyor: sayım numarası, lokasyon ve
/// durum. Listeye iki şey daha eklendi:
///
/// - **İlerleme**, çünkü sayım yarıda bırakılabilen tek işlem. Depo çalışanı
///   rafın önünden ayrılıp dönebilir; nerede kaldığını listeden görmeli.
/// - **Fark sayısı**, çünkü tamamlanmış bir sayımın tek anlamlı çıktısı odur.
///   "Tamamlandı" rozeti sayımın sonucunu söylemez, sadece bittiğini söyler.
class CountsPage extends ConsumerWidget {
  const CountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InventoryCount>> counts = ref.watch(countsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Sayımı')),
      body: AsyncValueView<List<InventoryCount>>(
        value: counts,
        onRetry: () => ref.invalidate(countsProvider),
        loading: const LoadingIndicator(message: 'Sayımlar yükleniyor'),
        isEmpty: (List<InventoryCount> items) => items.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.count,
          title: 'Sayım kaydı yok',
          message: 'Açık bir stok sayımı bulunmuyor.',
        ),
        data: (List<InventoryCount> items) => _CountList(counts: items),
      ),
    );
  }
}

class _CountList extends ConsumerWidget {
  const _CountList({required this.counts});

  final List<InventoryCount> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;

    final List<InventoryCount> open = counts
        .where((InventoryCount c) => !c.status.isCompleted)
        .toList();
    final List<InventoryCount> done = counts
        .where((InventoryCount c) => c.status.isCompleted)
        .toList();

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          if (open.isNotEmpty) ...<Widget>[
            _GroupHeader(label: 'Açık sayımlar', count: open.length),
            for (int i = 0; i < open.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _CountRow(count: open[i]),
            ],
          ],
          if (done.isNotEmpty) ...<Widget>[
            _GroupHeader(label: 'Tamamlananlar', count: done.length),
            for (int i = 0; i < done.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _CountRow(count: done[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

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
            label.toUpperCaseTr(),
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$count',
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(height: 1, color: status.border)),
        ],
      ),
    );
  }
}

class _CountRow extends ConsumerWidget {
  const _CountRow({required this.count});

  final InventoryCount count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final bool isDone = count.status.isCompleted;

    // Lokasyon kodu sayım kaydında değil, ayrı bir kayıtta duruyor.
    final String locationCode =
        ref
            .watch(locationsProvider)
            .value
            ?.where(
              (LocationSummary l) => l.location.id == count.locationId,
            )
            .map((LocationSummary l) => l.location.code)
            .firstOrNull ??
        '—';

    return InkWell(
      onTap: () => context.push(AppRoutes.countDetail(count.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    count.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.code.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: count.status.label,
                  tone: count.status.tone,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            Row(
              children: <Widget>[
                Icon(
                  AppIcons.locations,
                  size: 14,
                  color: status.neutral,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    locationCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.code.copyWith(
                      fontSize: 12,
                      color: status.neutral,
                    ),
                  ),
                ),
                // Tamamlanmış sayımın tek anlamlı çıktısı fark sayısıdır.
                if (isDone)
                  _DifferenceSummary(count: count)
                else
                  Text(
                    '${count.lines.length} ürün',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.forward,
                  size: AppSizes.iconSm,
                  color: status.neutral,
                ),
              ],
            ),
            if (!isDone) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              TaskProgressBar(
                completed: count.countedLineCount,
                total: count.lines.length,
                label: 'Sayılan ürün',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tamamlanmış sayımın sonucu: kaç üründe fark çıktı.
class _DifferenceSummary extends StatelessWidget {
  const _DifferenceSummary({required this.count});

  final InventoryCount count;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    if (count.differenceCount == 0) {
      return Text(
        'Fark yok',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: status.success, fontWeight: FontWeight.w600),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(StatusTone.warning.icon, size: 13, color: status.warning),
        const SizedBox(width: 4),
        Text(
          '${count.differenceCount} üründe fark',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: status.warning, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
