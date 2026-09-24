import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../data/views.dart';
import '../../models/models.dart';
import '../utils/formatters.dart';
import 'app_card.dart';
import 'info_widgets.dart';
import 'status_badge.dart';

/// Ürün kartı (şartname 8. bölüm).
///
/// Gösterdikleri: görsel yerine ikon kutusu, ürün adı, SKU, stok miktarı,
/// ana lokasyon ve durum rozeti — şartnamedeki listenin birebir karşılığı.
///
/// Mock veride ürün görseli yok; kategori ikonu kullanılır. Gri bir kutu
/// koymaktansa kategoriyi göstermek, listede göz taramasını kolaylaştırır.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.summary,
    this.onTap,
    this.trailing,
    this.showLocation = true,
    super.key,
  });

  final ProductStockSummary summary;
  final VoidCallback? onTap;

  /// Sağ tarafa özel içerik — seçim onay kutusu, ok ikonu vb.
  final Widget? trailing;

  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockStatus stockStatus = summary.status;
    final Product product = summary.product;

    return AppCard(
      onTap: onTap,
      // Sorunlu stoklarda sol şerit: listede göz hemen oraya gider.
      accentColor: stockStatus == StockStatus.normal
          ? null
          : stockStatus.tone.foreground(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIconBox(
            icon: categoryIcon(summary.category?.iconKey ?? ''),
            background: status.neutralContainer,
            foreground: status.neutral,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    CodeChip(code: product.sku, compact: true),
                    if (showLocation && summary.primaryLocation != null)
                      CodeChip(
                        code: summary.primaryLocation!.code,
                        icon: AppIcons.locations,
                        compact: true,
                      ),
                    if (showLocation && summary.isMultiLocation)
                      Text(
                        '+${summary.locations.length - 1} lokasyon',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: status.neutral),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                Formatters.integer.format(summary.totalQuantity),
                style: AppTypography.metricMedium.copyWith(
                  color: stockStatus == StockStatus.normal
                      ? null
                      : stockStatus.tone.foreground(context),
                ),
              ),
              Text(
                product.unit,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
              const SizedBox(height: AppSpacing.sm),
              StockStatusBadge(status: stockStatus, compact: true),
            ],
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Sipariş kartı (şartname 13. bölüm).
///
/// Toplanmakta olan siparişlerde ilerleme çubuğu gösterilir; kullanıcı
/// listeye bakarak hangi işin ne kadar ilerlediğini görebilmeli.
class OrderCard extends StatelessWidget {
  const OrderCard({required this.order, this.onTap, super.key});

  final SalesOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool inProgress = order.status == OrderStatus.picking;

    return AppCard(
      onTap: onTap,
      accentColor: order.priority == OrderPriority.urgent
          ? status.danger
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Sol grup esnek: uzun sipariş numarası veya geniş öncelik rozeti
          // durum rozetini ekran dışına itmemeli.
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '#${order.orderNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (order.priority == OrderPriority.urgent ||
                        order.priority == OrderPriority.high) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      OrderPriorityBadge(priority: order.priority),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OrderStatusBadge(status: order.status, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Text(
            order.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Flexible(
                child: _MetaItem(
                  icon: AppIcons.products,
                  text: '${order.lineCount} çeşit',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: _MetaItem(
                  icon: AppIcons.stock,
                  text: Formatters.quantity(order.totalQuantity, 'adet'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  Formatters.relative(order.createdAt),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ),
            ],
          ),
          if (inProgress) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TaskProgressBar(
              completed: order.pickedQuantity,
              total: order.totalQuantity,
              label: 'Toplama',
            ),
          ],
        ],
      ),
    );
  }
}

/// Lokasyon kartı (şartname 18. bölüm).
///
/// Kapasite, doluluk, SKU sayısı ve toplam adet — şartnamedeki listenin
/// tamamı tek kartta.
class LocationCard extends StatelessWidget {
  const LocationCard({required this.summary, this.onTap, super.key});

  final LocationSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final WarehouseLocation location = summary.location;

    return AppCard(
      onTap: onTap,
      accentColor: summary.isNearlyFull ? status.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconBox(
                icon: location.type.icon,
                size: 40,
                background: status.neutralContainer,
                foreground: status.neutral,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      location.code,
                      style: AppTypography.code.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      summary.zone?.name ?? location.type.label,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                  ],
                ),
              ),
              if (summary.isEmpty)
                StatusBadge(
                  label: 'Boş',
                  tone: StatusTone.neutral,
                  compact: true,
                  showIcon: false,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${summary.skuCount} çeşit',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                    Text(
                      Formatters.quantity(summary.usedQuantity, 'adet'),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OccupancyBar(used: summary.usedQuantity, capacity: location.capacity),
        ],
      ),
    );
  }
}

/// Stok hareketi satırı (şartname 19. bölüm).
///
/// Listede en önemli bilgi **yön ve miktar**: `+10` yeşil, `-2` turuncu.
/// Şartnamedeki örnek gösterim birebir korundu:
/// miktar + ürün / hareket türü + referans / tarih.
class MovementTile extends StatelessWidget {
  const MovementTile({required this.detail, this.onTap, super.key});

  final MovementDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockMovement movement = detail.movement;
    final StatusTone tone = movement.type.tone;
    final String? route = detail.routeLabel;

    // Transferde toplam değişmediği için işaretsiz miktar gösterilir;
    // yön zaten "A-01-01 → B-03-02" satırında görünür.
    final bool signed = movement.type.direction != MovementDirection.internal;
    final String quantityText = signed
        ? Formatters.signedInteger(movement.quantity)
        : Formatters.integer.format(movement.quantity.abs());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIconBox(
            icon: movement.type.icon,
            size: 40,
            background: tone.background(context),
            foreground: tone.foreground(context),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      quantityText,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: tone.foreground(context)),
                    ),
                    const SizedBox(width: AppSpacing.sm - 2),
                    Expanded(
                      child: Text(
                        detail.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${movement.type.label} · ${movement.reference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                if (route != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm - 2),
                  CodeChip(code: route, compact: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Formatters.time.format(movement.timestamp),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ],
      ),
    );
  }
}

/// Dashboard özet kartı (şartname 7. bölüm).
///
/// Şartname "büyük ve okunabilir sayılar" istiyor; metrik [AppTypography]
/// içindeki özel stille çizilir.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
    this.suffix,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusTone? tone;

  /// Sayının yanındaki birim, ör. `adet`.
  final String? suffix;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StatusTone resolved = tone ?? StatusTone.neutral;
    final Color accent = tone == null
        ? Theme.of(context).colorScheme.primary
        : resolved.foreground(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconBox(
                icon: icon,
                size: 32,
                iconSize: 16,
                background: tone == null
                    ? accent.withValues(alpha: 0.12)
                    : resolved.background(context),
                foreground: accent,
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  AppIcons.forward,
                  size: AppSizes.iconSm,
                  color: status.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metricLarge,
                ),
              ),
              if (suffix != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  suffix!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ],
      ),
    );
  }
}

/// Dashboard hızlı işlem kartı (şartname 7 ve 34. bölümler).
///
/// Şartname 34. bölüm "Ürün Tara, Sipariş Topla, Stok Transferi" işlemlerinin
/// bir-iki dokunuşta bulunmasını istiyor; bu kartlar o kısayolu sağlar.
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone,
    this.badgeCount,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final StatusTone? tone;

  /// Bekleyen iş sayısı — "3 sipariş toplanmayı bekliyor" gibi.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final StatusTone resolved = tone ?? StatusTone.info;
    final Color accent = resolved.foreground(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Badge(
            isLabelVisible: badgeCount != null && badgeCount! > 0,
            label: Text('$badgeCount'),
            child: AppIconBox(
              icon: icon,
              size: 44,
              iconSize: 20,
              background: resolved.background(context),
              foreground: accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Kart içindeki küçük ikon + metin çifti.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppSizes.iconSm, color: status.neutral),
        const SizedBox(width: AppSpacing.xs + 1),
        // Metin esnek: dar ekranda kırpılır, satırı taşırmaz.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ),
      ],
    );
  }
}
