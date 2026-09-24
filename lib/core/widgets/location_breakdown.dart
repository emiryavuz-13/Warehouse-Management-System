import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../data/views.dart';
import '../utils/formatters.dart';

/// Bir ürünün lokasyon bazlı stok dökümü (şartname 8. ve 9. bölümler).
///
/// Şartname 9. bölüm: *"Aynı ürün birden fazla lokasyonda bulunabiliyorsa
/// bunlar ayrı gösterilmelidir."* Bu bileşen o kuralın tek karşılığı; ürün
/// detayı ve stok listesi aynı görünümü paylaşır.
///
/// Her satırda miktarın yanında **payı** da gösterilir: kullanıcı "24 adedin
/// 18'i A-01-01'de" bilgisini oran çubuğundan bir bakışta alır, rakamları
/// zihninde oranlamak zorunda kalmaz.
///
/// Ürünün tek lokasyonu varsa çubuk çizilmez: tek satırda %100'lük bir
/// çubuk bilgi taşımaz, yalnızca yer kaplar.
class LocationBreakdown extends StatelessWidget {
  const LocationBreakdown({
    required this.summary,
    this.dense = false,
    this.onLocationTap,
    super.key,
  });

  final ProductStockSummary summary;

  /// Liste içine gömülü kullanımda satır aralığını daraltır.
  final bool dense;

  /// Lokasyon koduna dokunulduğunda çağrılır — lokasyon detayına gider.
  final void Function(String locationId)? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final int total = summary.totalQuantity;
    final bool showBars = summary.locations.length > 1;
    final double gap = dense ? AppSpacing.sm : AppSpacing.md;

    return Column(
      children: <Widget>[
        for (int i = 0; i < summary.locations.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          _LocationRow(
            stock: summary.locations[i],
            share: total == 0 ? 0 : summary.locations[i].quantity / total,
            unit: summary.product.unit,
            borderColor: status.border,
            showBar: showBars,
            onTap: onLocationTap == null
                ? null
                : () => onLocationTap!(summary.locations[i].location.id),
          ),
        ],
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.stock,
    required this.share,
    required this.unit,
    required this.borderColor,
    required this.showBar,
    this.onTap,
  });

  final LocationStock stock;
  final double share;
  final String unit;
  final Color borderColor;
  final bool showBar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Widget content = Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              stock.location.type.icon,
              size: AppSizes.iconSm,
              color: status.neutral,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                stock.location.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.code.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showBar) ...<Widget>[
              Text(
                Formatters.percent(share),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Text(
              Formatters.quantity(stock.quantity, unit),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (showBar) ...<Widget>[
          const SizedBox(height: AppSpacing.sm - 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 4,
              color: colors.primary,
              backgroundColor: borderColor,
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}
