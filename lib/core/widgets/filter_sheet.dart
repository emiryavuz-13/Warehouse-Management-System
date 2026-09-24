import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../models/enums.dart';
import 'app_buttons.dart';

/// Filtre panelinin iskeleti (şartname 29. bölüm).
///
/// Ürün, stok, sipariş ve hareket listeleri farklı filtreler kullanır ama
/// panelin düzeni her yerde aynıdır: başlık, "temizle" kısayolu, filtre
/// grupları ve uygula butonu. Bu sınıf o çerçeveyi verir; içerik [sections]
/// ile geçilir.
///
/// Panel yüksekliği ekranın %80'iyle sınırlıdır ve içerik kaydırılabilir;
/// çok filtreli listelerde uygula butonu ekran dışında kalmamalı.
class FilterSheet extends StatelessWidget {
  const FilterSheet({
    required this.sections,
    required this.onApply,
    this.onClear,
    this.title = 'Filtrele',
    this.applyLabel = 'Uygula',
    super.key,
  });

  final List<Widget> sections;
  final VoidCallback onApply;
  final VoidCallback? onClear;
  final String title;
  final String applyLabel;

  /// Paneli alttan açar ve kapanmasını bekler.
  static Future<void> show({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onClear != null)
                  TextButton(onPressed: onClear, child: const Text('Temizle')),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sections,
              ),
            ),
          ),
          BottomActionBar(
            children: <Widget>[
              PrimaryButton(label: applyLabel, onPressed: onApply),
            ],
          ),
        ],
      ),
    );
  }
}

/// Filtre panelindeki tek bir grup: başlık + seçenek çipleri.
class FilterSection<T> extends StatelessWidget {
  const FilterSection({
    required this.title,
    required this.options,
    required this.labelBuilder,
    required this.selected,
    required this.onSelected,
    this.iconBuilder,
    this.toneBuilder,
    this.allowNone = true,
    this.noneLabel = 'Tümü',
    super.key,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelBuilder;

  /// Seçili değer; `null` ise hiçbir seçenek seçili değildir.
  final T? selected;

  /// Seçim değiştiğinde çağrılır. Seçili çipe tekrar dokunulursa `null`
  /// gelir — kullanıcı filtreyi kaldırmak için ayrı bir düğme aramamalı.
  final ValueChanged<T?> onSelected;

  final IconData Function(T option)? iconBuilder;

  /// Durum filtrelerinde çipi ilgili renge boyar; "Kritik" filtresi turuncu,
  /// "Stok Yok" kırmızı görünür.
  final StatusTone Function(T option)? toneBuilder;

  /// "Tümü" çipini gösterir.
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            if (allowNone)
              _Chip(
                label: noneLabel,
                isSelected: selected == null,
                onTap: () => onSelected(null),
              ),
            for (final T option in options)
              _Chip(
                label: labelBuilder(option),
                icon: iconBuilder?.call(option),
                tone: toneBuilder?.call(option),
                isSelected: selected == option,
                onTap: () => onSelected(selected == option ? null : option),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Çoklu seçim yapılabilen filtre grubu — sipariş durumu gibi birden fazla
/// değerin aynı anda seçilebildiği yerlerde.
class MultiFilterSection<T> extends StatelessWidget {
  const MultiFilterSection({
    required this.title,
    required this.options,
    required this.labelBuilder,
    required this.selected,
    required this.onChanged,
    this.toneBuilder,
    super.key,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelBuilder;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final StatusTone Function(T option)? toneBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final T option in options)
              _Chip(
                label: labelBuilder(option),
                tone: toneBuilder?.call(option),
                isSelected: selected.contains(option),
                onTap: () {
                  final Set<T> next = Set<T>.of(selected);
                  if (!next.remove(option)) next.add(option);
                  onChanged(next);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.tone,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Color accent = tone?.foreground(context) ?? colors.primary;
    final Color background = isSelected
        ? (tone?.background(context) ?? colors.primary.withValues(alpha: 0.12))
        : Colors.transparent;
    final Color border = isSelected ? accent : status.border;
    final Color foreground = isSelected ? accent : colors.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: border, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppSizes.iconSm, color: foreground),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
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

/// Etkin filtreyi gösteren, tek dokunuşla kaldırılabilen çip.
///
/// Liste ekranlarında filtre panelinin dışında, başlığın hemen altında
/// durur. Kullanıcı hangi daraltmaların açık olduğunu paneli açmadan
/// görebilmeli; aksi halde "neden bu kadar az kayıt var" sorusunun cevabı
/// gizli kalır.
class RemovableChip extends StatelessWidget {
  const RemovableChip({
    required this.label,
    required this.onRemove,
    this.tone,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  /// Durum filtrelerinde çip ilgili renge boyanır.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Color foreground = tone?.foreground(context) ?? status.neutral;
    final Color background =
        tone?.background(context) ?? status.neutralContainer;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm - 2,
            AppSpacing.sm,
            AppSpacing.sm - 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(AppIcons.close, size: 14, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
