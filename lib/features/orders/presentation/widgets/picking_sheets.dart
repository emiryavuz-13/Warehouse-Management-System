import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';

/// Görevdeki tüm kalemleri listeleyen panel (şartname 14. bölüm).
///
/// Toplama ekranı tek seferde tek ürün gösterir — depo çalışanı koridorda
/// yürürken liste değil talimat ister. Ama sırayı **zorlamak** gerçek depoya
/// uymuyor: çalışan yanından geçtiği rafa uğramak, ya da elindeki kolinin
/// kalemine atlamak isteyebilir.
///
/// Bu panel sırayı bir öneri hâline getiriyor: sıradaki kalem işaretli
/// gelir, ama çalışan istediğine atlayabilir.
///
/// Toplanmış kalemler de açılabilir — çalışan ne aldığını gözden geçirmek
/// isteyebilir; o adımda onay düğmesi kapalı olur.
class PickingStepsSheet extends ConsumerWidget {
  const PickingStepsSheet({
    required this.task,
    required this.currentIndex,
    super.key,
  });

  final PickingTask task;

  /// Ekranda o an açık olan satırın sırası.
  final int currentIndex;

  /// Paneli açar; seçilen satırın sırasını döner.
  static Future<int?> show({
    required BuildContext context,
    required PickingTask task,
    required int currentIndex,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) =>
          PickingStepsSheet(task: task, currentIndex: currentIndex),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Görev Kalemleri',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${task.lines.length} kalem · '
                  'istediğiniz kalemden başlayabilirsiniz',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: status.border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              itemCount: task.lines.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: AppSpacing.lg, color: status.border),
              itemBuilder: (BuildContext context, int index) => _StepRow(
                line: task.lines[index],
                index: index,
                isCurrent: index == currentIndex,
                onTap: () => Navigator.of(context).pop(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends ConsumerWidget {
  const _StepRow({
    required this.line,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  final PickingLine line;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ProductStockSummary? summary =
        ref.watch(productSummaryProvider(line.productId)).value;
    final String locationCode =
        ref
            .watch(locationsProvider)
            .value
            ?.where((LocationSummary l) => l.location.id == line.locationId)
            .map((LocationSummary l) => l.location.code)
            .firstOrNull ??
        '—';

    final bool isDone = line.isCompleted;

    return Material(
      color: isCurrent
          ? colors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? status.successContainer
                      : status.neutralContainer,
                  shape: BoxShape.circle,
                ),
                child: isDone
                    ? Icon(
                        AppIcons.confirm,
                        size: 15,
                        color: status.success,
                      )
                    : Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary?.product.name ?? 'Ürün',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locationCode,
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
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${line.pickedQuantity} / ${line.requestedQuantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDone ? status.success : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kaynak raf seçme paneli.
///
/// Aynı ürün birden fazla rafta durabilir — USB-C kablonun üç ayrı rafta
/// stoğu var. Görev açılırken en çok stoğun bulunduğu raf **önerilir**, ama
/// çalışan başka bir raftan alabilir: önerilen raf kapalı olabilir, forklift
/// bekliyordur, ya da çalışan zaten başka bir rafın önündedir.
///
/// Miktara yetmeyen raflar gizlenmez, kilitlenir — "böyle bir raf yok" ile
/// "var ama yetmiyor" farklı bilgilerdir.
class PickingLocationSheet extends ConsumerWidget {
  const PickingLocationSheet({
    required this.summary,
    required this.selectedLocationId,
    required this.quantity,
    super.key,
  });

  final ProductStockSummary summary;
  final String selectedLocationId;

  /// Alınacak miktar — yetmeyen raflar buna göre kilitlenir.
  final int quantity;

  static Future<String?> show({
    required BuildContext context,
    required ProductStockSummary summary,
    required String selectedLocationId,
    required int quantity,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => PickingLocationSheet(
        summary: summary,
        selectedLocationId: selectedLocationId,
        quantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Hangi raftan alıyorsunuz?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${summary.product.name} · '
                  '${summary.locations.length} rafta bulunuyor',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: status.border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              itemCount: summary.locations.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: AppSpacing.lg, color: status.border),
              itemBuilder: (BuildContext context, int index) {
                final LocationStock stock = summary.locations[index];
                final bool fits = stock.quantity >= quantity;

                return _LocationRow(
                  stock: stock,
                  unit: summary.product.unit,
                  isSelected: stock.location.id == selectedLocationId,
                  fits: fits,
                  onTap: fits
                      ? () => Navigator.of(context).pop(stock.location.id)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.stock,
    required this.unit,
    required this.isSelected,
    required this.fits,
    required this.onTap,
  });

  final LocationStock stock;
  final String unit;
  final bool isSelected;
  final bool fits;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: fits ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                isSelected ? AppIcons.radioSelected : AppIcons.radioUnselected,
                size: AppSizes.iconMd,
                color: isSelected ? colors.primary : status.neutral,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        stock.location.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.code.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!fits) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusBadge(
                        label: 'Yetersiz',
                        tone: StatusTone.danger,
                        compact: true,
                        showIcon: false,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.quantity(stock.quantity, unit),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
