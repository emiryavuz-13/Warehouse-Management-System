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

/// Ürün satırı (şartname 8. bölüm).
///
/// Gösterdikleri: kategori ikonu, ürün adı, SKU, ana lokasyon, stok miktarı
/// ve —yalnızca gerektiğinde— durum rozeti.
///
/// **Kart değil satır.** Uzun bir listede her ürüne çerçeve çizmek, otuz
/// üründe yüz yirmi kenar çizgisi demektir; ayraç aynı ayrımı tek çizgiyle
/// yapar ve göz ürün adlarını daha hızlı tarar.
///
/// **Rozet yalnızca sorunlu durumda.** Her satıra "Normal" rozeti basmak
/// listeyi yeşile boğar ve asıl dikkat edilmesi gerekenleri görünmez kılar.
/// Normal stokta rozet yok; miktar da nötr renkte. Kritik ve tükenmiş
/// ürünlerde hem miktar renklenir hem rozet çıkar.
///
/// Mock veride ürün görseli yok; kategori ikonu kullanılır. Gri bir kutu
/// koymaktansa kategoriyi göstermek listede göz taramasını kolaylaştırır.
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

  /// Sağ tarafa özel içerik — seçim onay kutusu vb.
  final Widget? trailing;

  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockStatus stockStatus = summary.status;
    final Product product = summary.product;
    final bool needsAttention = stockStatus != StockStatus.normal;

    final List<String> meta = <String>[
      product.sku,
      if (showLocation && summary.primaryLocation != null)
        summary.primaryLocation!.code,
      if (showLocation && summary.isMultiLocation)
        '+${summary.locations.length - 1} lokasyon',
    ];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            AppIconBox(
              icon: categoryIcon(summary.category?.iconKey ?? ''),
              size: 40,
              iconSize: 19,
              background: needsAttention
                  ? stockStatus.tone.background(context)
                  : status.neutralContainer,
              foreground: needsAttention
                  ? stockStatus.tone.foreground(context)
                  : status.neutral,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.join(' · '),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      Formatters.integer.format(summary.totalQuantity),
                      style: AppTypography.metricMedium.copyWith(
                        color: needsAttention
                            ? stockStatus.tone.foreground(context)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      product.unit,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                  ],
                ),
                if (needsAttention) ...<Widget>[
                  const SizedBox(height: 3),
                  StockStatusBadge(status: stockStatus, compact: true),
                ],
              ],
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Ürün satırlarını ayraçlarla dizer.
///
/// Listenin kendisi kaydırılabilir değildir; `SliverList` veya `Column`
/// içine konur. Ayraç yalnızca satır aralarına girer, listenin başına ve
/// sonuna değil.
class ProductList extends StatelessWidget {
  const ProductList({
    required this.products,
    required this.onProductTap,
    this.trailingBuilder,
    super.key,
  });

  final List<ProductStockSummary> products;
  final void Function(ProductStockSummary summary) onProductTap;
  final Widget? Function(ProductStockSummary summary)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Column(
      children: <Widget>[
        for (int i = 0; i < products.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          ProductCard(
            summary: products[i],
            trailing: trailingBuilder?.call(products[i]),
            onTap: () => onProductTap(products[i]),
          ),
        ],
      ],
    );
  }
}

/// Sipariş kartı (şartname 13. bölüm).
///
/// Toplanmakta olan siparişlerde ilerleme çubuğu gösterilir; kullanıcı
/// listeye bakarak hangi işin ne kadar ilerlediğini görebilmeli.
/// Sipariş satırı (şartname 13. bölüm).
///
/// Şartnamenin istediği altı alan: sipariş numarası, müşteri, ürün sayısı,
/// toplam adet, durum ve tarih.
///
/// Ürün ve stok listeleriyle aynı dil: kart değil ayraçla ayrılmış satır.
/// Acil siparişler kenarlıkla değil öncelik rozetiyle işaretlenir — kutusuz
/// bir listede renkli şerit tutunacak bir kenar bulamaz.
///
/// İlerleme çubuğu yalnızca toplanmakta olan siparişte çizilir: yeni bir
/// siparişte %0, sevk edilmişte %100 gösterir ve ikisi de bilgi taşımaz.
class OrderCard extends StatelessWidget {
  const OrderCard({required this.order, this.onTap, super.key});

  final SalesOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool inProgress = order.status == OrderStatus.picking;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Sol grup esnek: uzun sipariş numarası veya geniş öncelik
            // rozeti durum rozetini ekran dışına itmemeli.
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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
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

/// Hızlı işlem kısayolu (şartname 7, 29 ve 34. bölümler).
///
/// Kart değil, dikey ikon + etiket. Kısayollar bilgi taşımıyor, yalnızca
/// hedefe götürüyor; çerçeve vermek onları metriklerle aynı görsel ağırlığa
/// çıkarıyor ve ekranı gereksiz çizgiyle dolduruyordu.
///
/// [isPrimary] tek bir kısayolu dolgulu daireyle öne çıkarır. Şartname 34.
/// bölüm tarama işleminin en hızlı erişilen eylem olmasını istiyor.
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeCount,
    this.isPrimary = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Bekleyen iş sayısı — "2 sipariş toplanmayı bekliyor" gibi.
  final int? badgeCount;

  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Badge(
              isLabelVisible: badgeCount != null && badgeCount! > 0,
              label: Text('$badgeCount'),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isPrimary ? colors.primary : status.neutralContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isPrimary ? colors.onPrimary : colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
            ),
          ],
        ),
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
