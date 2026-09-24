import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/status_tone_colors.dart';
import '../utils/formatters.dart';

/// Teknik kod gösterimi: SKU, barkod, lokasyon kodu.
///
/// Monospace font kullanır. `A-01-01` ile `A-01-11` normal fontta birbirine
/// çok benzer; depo çalışanı yanlış rafa gitmemeli.
class CodeChip extends StatelessWidget {
  const CodeChip({
    required this.code,
    this.icon,
    this.tone,
    this.compact = false,
    super.key,
  });

  final String code;
  final IconData? icon;
  final Color? tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Color foreground = tone ?? status.neutral;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md - 2,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: status.neutralContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 11 : 13, color: foreground),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          // Uzun kodlar (ör. `A-01-01 → B-03-02` yol etiketi) dar ekranda
          // taşmasın diye esnek; kısalması gerekirse sonu kırpılır.
          Flexible(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.code.copyWith(
                color: foreground,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detay ekranlarındaki etiket/değer satırı.
///
/// Ürün detayı, sipariş detayı, sevkiyat detayı ve profil ekranı aynı düzeni
/// kullanır: etiket solda gri, değer sağda vurgulu.
class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.label,
    required this.value,
    this.valueWidget,
    this.icon,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;

  /// Metin yerine widget gösterilecekse — rozet, kod çipi vb.
  final Widget? valueWidget;

  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: AppSizes.iconSm, color: status.neutral),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: status.neutral),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valueWidget ??
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı: "Son Hareketler", "Kritik Stok", "Lokasyonlar".
///
/// Sağdaki eylem genellikle "Tümünü gör" bağlantısıdır.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTypography.sectionTitle),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  Icon(AppIcons.forward, size: AppSizes.iconSm),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// İlerleme çubuğu — toplama görevi, mal kabul ve sayım ilerlemesi.
///
/// Yüzde yerine **kaç / kaç** gösterir. Depo çalışanı için "%67" değil
/// "2 / 3" anlamlıdır; kaç iş kaldığını doğrudan söyler.
class TaskProgressBar extends StatelessWidget {
  const TaskProgressBar({
    required this.completed,
    required this.total,
    this.label,
    this.tone,
    super.key,
  });

  final int completed;
  final int total;
  final String? label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final double ratio = total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);
    final Color color =
        tone ??
        (ratio >= 1 ? status.success : Theme.of(context).colorScheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (label != null)
              Expanded(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              )
            else
              const Spacer(),
            Text(
              '$completed / $total',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm - 2),
        // Uzunluk değişimi animasyonlu: kullanıcı ilerlediğini hissetmeli
        // (şartname 33. bölüm, "picking ilerleme animasyonu").
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: color,
                backgroundColor: status.neutralContainer,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Lokasyon doluluk göstergesi (şartname 18. bölüm).
///
/// Burada yüzde anlamlıdır: kullanıcı rafın ne kadar dolu olduğunu değil,
/// kaç adet daha sığacağını merak eder — ikisi de gösterilir.
///
/// Kapasitenin %85'i aşıldığında çubuk uyarı rengine döner; kullanıcı
/// yerleştirme yaparken dolan rafları önceden görmeli.
class OccupancyBar extends StatelessWidget {
  const OccupancyBar({
    required this.used,
    required this.capacity,
    this.showLabels = true,
    super.key,
  });

  final int used;
  final int capacity;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final double ratio = capacity == 0 ? 0 : (used / capacity).clamp(0.0, 1.0);

    final Color color = switch (ratio) {
      >= 0.95 => status.danger,
      >= 0.85 => status.warning,
      _ => status.success,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLabels) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${Formatters.integer.format(used)} / '
                  '${Formatters.integer.format(capacity)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ),
              Text(
                Formatters.percent(ratio),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm - 3),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            color: color,
            backgroundColor: status.neutralContainer,
          ),
        ),
      ],
    );
  }
}
