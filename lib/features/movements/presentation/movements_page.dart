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
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../providers/movement_providers.dart';

/// Stok hareketleri (şartname 19. bölüm).
///
/// *"Tüm stok hareketleri zaman sıralı gösterilmelidir."*
///
/// **Gün başlıkları listeyi zaman çizelgesine çevirir.** Düz bir liste
/// "24.09.2026 12:42" damgalarını her satırda tekrarlar; başlık altında
/// yalnızca saat kalır ve göz tarihi bir kez okur. Başlık ayrıca o günün
/// giriş/çıkış toplamını taşıyor — hareket listesine bakmanın en sık nedeni
/// "bugün ne oldu" sorusudur.
class MovementsPage extends ConsumerStatefulWidget {
  const MovementsPage({this.productId, super.key});

  /// Ürün detayından gelindiğinde liste o ürüne kilitlenir.
  final String? productId;

  @override
  ConsumerState<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends ConsumerState<MovementsPage> {
  @override
  void initState() {
    super.initState();
    // Filtre durumu global; ürün kısıtı ekran **her açılışında** yazılır.
    // `widget.productId` null geldiğinde de yazıldığı için, ürün detayından
    // gelinip sonra menüden girildiğinde eski kısıt kendiliğinden düşer —
    // bunun için `dispose` içinde temizlik yapmaya gerek yok. (Denendi:
    // `dispose` içinde `ref` kullanmak Riverpod'da güvensiz, widget o anda
    // ağaçtan çıkmış oluyor.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(movementFilterProvider.notifier)
          .setProduct(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MovementDetail>> movements = ref.watch(
      movementListProvider,
    );
    final MovementFilter filter = ref.watch(movementFilterProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Hareketleri')),
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
              hintText: 'Ürün, SKU veya referans',
              initialValue: filter.query,
              onChanged: ref.read(movementFilterProvider.notifier).setQuery,
            ),
          ),
          const _TypeFilterStrip(),
          Divider(height: 1, color: status.border),
          Expanded(
            child: AsyncValueView<List<MovementDetail>>(
              value: movements,
              onRetry: () => ref.invalidate(movementListProvider),
              loading: const LoadingIndicator(message: 'Hareketler'),
              isEmpty: (List<MovementDetail> items) => items.isEmpty,
              empty: filter.query.trim().isNotEmpty
                  ? EmptyState.noResults(query: filter.query)
                  : EmptyState(
                      icon: AppIcons.movements,
                      title: 'Hareket yok',
                      message: 'Seçili daraltmalarla eşleşen stok hareketi '
                          'bulunamadı.',
                      actionLabel: filter.isActive ? 'Filtreleri temizle' : null,
                      onAction: filter.isActive
                          ? ref
                                .read(movementFilterProvider.notifier)
                                .clearFilters
                          : null,
                    ),
              data: (_) => const _MovementTimeline(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hareket türü şeridi — yatay kaydırılabilir çoklu seçim.
///
/// Yedi tür var; stok ekranındaki gibi eşit sütunlara bölseydik her etiket
/// kısalırdı ("SAYIM DÜZEL…"). Kaydırılabilir çipler etiketleri tam
/// bırakıyor.
class _TypeFilterStrip extends ConsumerWidget {
  const _TypeFilterStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<MovementType> selected = ref.watch(
      movementFilterProvider.select((MovementFilter f) => f.types),
    );
    final MovementFilterController controller = ref.read(
      movementFilterProvider.notifier,
    );
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        itemCount: MovementType.values.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return _TypeChip(
              label: 'Tümü',
              isSelected: selected.isEmpty,
              foreground: colors.primary,
              border: status.border,
              onTap: () => controller.setTypes(const <MovementType>{}),
            );
          }

          final MovementType type = MovementType.values[index - 1];
          return _TypeChip(
            label: type.label,
            icon: type.icon,
            isSelected: selected.contains(type),
            foreground: type.tone.foreground(context),
            border: status.border,
            onTap: () => controller.toggleType(type),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.foreground,
    required this.border,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final Color foreground;
  final Color border;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? foreground.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSelected ? foreground : border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: isSelected ? foreground : null),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? foreground
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gün başlıklarıyla zaman çizelgesi.
class _MovementTimeline extends ConsumerWidget {
  const _MovementTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MovementDayGroup> groups = ref.watch(movementsByDayProvider);
    final AppStatusColors status = Theme.of(context).status;

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          for (final MovementDayGroup group in groups) ...<Widget>[
            _DayHeader(group: group),
            for (int i = 0; i < group.movements.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _MovementRow(detail: group.movements[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final MovementDayGroup group;

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
            Formatters.dayHeader(group.day).toUpperCaseTr(),
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(height: 1, color: status.border)),
          const SizedBox(width: AppSpacing.md),
          // Günün net hareketi: listeye bakmanın en sık nedeni budur.
          if (group.inbound > 0) ...<Widget>[
            Text(
              '+${group.inbound}',
              style: AppTypography.overline.copyWith(color: status.success),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (group.outbound > 0)
            Text(
              '−${group.outbound}',
              style: AppTypography.overline.copyWith(color: status.warning),
            ),
        ],
      ),
    );
  }
}

/// Şartnamenin istediği yedi bilgiyi taşıyan hareket satırı.
class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.detail});

  final MovementDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockMovement movement = detail.movement;
    final StatusTone tone = movement.type.tone;
    final String? route = detail.routeLabel;

    final bool signed = movement.type.direction != MovementDirection.internal;
    final String quantityText = signed
        ? Formatters.signedInteger(movement.quantity)
        : Formatters.integer.format(movement.quantity.abs());
    final Color quantityColor = switch (movement.quantity) {
      > 0 when signed => status.success,
      < 0 when signed => status.warning,
      _ => Theme.of(context).colorScheme.onSurface,
    };

    return InkWell(
      onTap: () => context.push(AppRoutes.productDetail(detail.product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppIconBox(
              icon: movement.type.icon,
              size: 40,
              iconSize: 19,
              background: tone.background(context),
              foreground: tone.foreground(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          detail.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        quantityText,
                        style: AppTypography.metricMedium.copyWith(
                          fontSize: 17,
                          color: quantityColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[movement.type.label, movement.reference]
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      if (route != null) ...<Widget>[
                        Flexible(
                          child: Text(
                            route,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.code.copyWith(
                              fontSize: 11.5,
                              color: status.neutral,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      if (detail.user != null) ...<Widget>[
                        Icon(
                          AppIcons.profile,
                          size: 11,
                          color: status.neutral,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            detail.user!.firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: status.neutral,
                                  fontSize: 11.5,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      // Gün başlığı tarihi verdiği için satırda yalnızca
                      // saat kalır.
                      Text(
                        Formatters.time.format(movement.timestamp),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: status.neutral, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
