import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';

/// Dashboard'un ana metrik bölümü (şartname 7. bölüm).
///
/// Şartname yedi metrik sayıyor. İlk tasarımda hepsi eşit boyutta, renkli
/// ikon kutulu kartlara dizilmişti; sonuç, hiçbirinin öne çıkmadığı ve
/// rengin anlam taşımadığı bir ızgaraydı.
///
/// Yeniden kurgulanırken üç kural uygulandı:
///
/// 1. **Tek hero.** Toplam stok, 48px'lik tek büyük sayı olarak dashboard'a
///    liderlik eder. Altı sayıyı eşit ağırlıkta dizmek hiyerarşi kurmaz.
/// 2. **Her metriğin bağlamı var.** Çıplak sayı ölü sayıdır; hero haftalık
///    net değişimi ve 7 günlük hareket trendini, bloklar ise alt etiketlerini
///    taşır.
/// 3. **Renk duruma ayrıldı.** Önceki sürümde "Bugünkü Mal Kabul" yeşildi —
///    iyi olduğu için değil, çeşitlilik olsun diye. Artık renk yalnızca
///    gerçek durumda kullanılıyor: stok uyarısı ve değişim yönü.
class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({
    required this.summary,
    required this.dailyMovements,
    super.key,
  });

  final DashboardSummary summary;

  /// Son 7 günün günlük hareketleri; hero'nun trendini besler.
  final List<DailyMovementPoint> dailyMovements;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    final int weekInbound = dailyMovements.fold(
      0,
      (int sum, DailyMovementPoint p) => sum + p.inbound,
    );
    final int weekOutbound = dailyMovements.fold(
      0,
      (int sum, DailyMovementPoint p) => sum + p.outbound,
    );

    // Günlük hacim: giriş + çıkış. Tek seri, tek hue — iki renk olsaydı
    // okuyucu bir kıyas arardı, oysa burada sorulan tek şey "hareketlilik
    // artıyor mu".
    final List<double> volumes = <double>[
      for (final DailyMovementPoint point in dailyMovements)
        (point.inbound + point.outbound).toDouble(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        HeroFigure(
          value: Formatters.integer.format(summary.totalStock),
          unit: 'adet',
          label: 'toplam stok',
          trend: volumes.isEmpty
              ? null
              : SparkBars(values: volumes, height: 36),
          trendLabel: 'son 7 gün hareket',
          delta: DeltaLabel(
            value: weekInbound - weekOutbound,
            period: 'bu hafta',
            unit: 'adet',
          ),
          breakdown: Text(
            '${Formatters.integer.format(weekInbound)} giriş · '
            '${Formatters.integer.format(weekOutbound)} çıkış',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ),

        if (summary.stockAlertCount > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          StockAlertStrip(summary: summary),
        ],

        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        StatRow(
          blocks: <Widget>[
            StatBlock(
              label: 'Ürün',
              value: Formatters.integer.format(summary.totalProducts),
              sublabel: '${summary.categoryCount} kategori',
              onTap: () => context.push(AppRoutes.products),
            ),
            StatBlock(
              label: 'Bekleyen',
              value: Formatters.integer.format(summary.pendingOrderCount),
              sublabel: 'sipariş',
              onTap: () => context.go(AppRoutes.orders),
            ),
            StatBlock(
              label: 'Toplanıyor',
              value: Formatters.integer.format(summary.pickingOrderCount),
              sublabel: 'sipariş',
              onTap: () => context.go(AppRoutes.orders),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        StatRow(
          blocks: <Widget>[
            StatBlock(
              label: 'Mal Kabul',
              value: Formatters.integer.format(summary.todayReceiptCount),
              sublabel: 'bugün',
              onTap: () => context.push(AppRoutes.receiving),
            ),
            StatBlock(
              label: 'Sevkiyat',
              value: Formatters.integer.format(summary.todayShipmentCount),
              sublabel: 'bugün',
              onTap: () => context.push(AppRoutes.shipments),
            ),
            StatBlock(
              label: 'Hareket',
              value: Formatters.integer.format(summary.todayMovementCount),
              sublabel: 'bugün',
              onTap: () => context.push(AppRoutes.movements),
            ),
          ],
        ),
      ],
    );
  }
}

/// Kritik stok uyarı şeridi.
///
/// Dashboard'daki tek renkli öğe olmasının sebebi var: diğer metrikler durum
/// bilgisi, bu ise **eylem gerektiren** tek metrik. Renk burada dekorasyon
/// değil, uyarının kendisi (şartname 5. bölüm).
///
/// Dokununca stok listesi açılır; kullanıcı uyarıyı gördükten sonra hangi
/// ürünler olduğunu ayrıca aramak zorunda kalmamalı.
class StockAlertStrip extends StatelessWidget {
  const StockAlertStrip({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final bool hasOutOfStock = summary.outOfStockCount > 0;
    final StatusTone tone = hasOutOfStock
        ? StatusTone.danger
        : StatusTone.warning;

    final List<String> parts = <String>[
      if (summary.criticalStockCount > 0)
        '${summary.criticalStockCount} kritik',
      if (summary.outOfStockCount > 0) '${summary.outOfStockCount} tükendi',
    ];

    return Material(
      color: tone.background(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => context.go(AppRoutes.stock),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                tone.icon,
                size: AppSizes.iconMd,
                color: tone.foreground(context),
              ),
              const SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${summary.stockAlertCount} üründe stok uyarısı',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.foreground(context),
                        ),
                      ),
                      TextSpan(
                        text: '  ${parts.join(' · ')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tone
                              .foreground(context)
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                AppIcons.forward,
                size: AppSizes.iconSm,
                color: tone.foreground(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hızlı işlemler (şartname 7 ve 34. bölümler).
///
/// Şartname 34. bölüm "Ürün Tara, Sipariş Topla, Stok Transferi"
/// işlemlerinin bir-iki dokunuşta bulunmasını istiyor.
///
/// Kart yerine dikey ikon+etiket kolonları: kısayollar bilgi taşımıyor,
/// yalnızca hedefe götürüyor. Çerçeve vermek onları metrik kartlarıyla aynı
/// görsel ağırlığa çıkarıyordu.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<QuickActionCard> actions = <QuickActionCard>[
      QuickActionCard(
        label: 'Tara',
        icon: AppIcons.scan,
        isPrimary: true,
        onTap: () => context.go(AppRoutes.scan),
      ),
      QuickActionCard(
        label: 'Mal Kabul',
        icon: AppIcons.receiving,
        badgeCount: summary.todayReceiptCount,
        onTap: () => context.push(AppRoutes.receiving),
      ),
      QuickActionCard(
        label: 'Topla',
        icon: AppIcons.picking,
        badgeCount: summary.pickingOrderCount,
        onTap: () => context.go(AppRoutes.orders),
      ),
      QuickActionCard(
        label: 'Transfer',
        icon: AppIcons.transfer,
        onTap: () => context.push(AppRoutes.transfer),
      ),
      QuickActionCard(
        label: 'Sayım',
        icon: AppIcons.count,
        onTap: () => context.push(AppRoutes.counts),
      ),
    ];

    // Beş kısayol tek satıra sığar; yatay kaydırma gerekmez ve kullanıcı
    // hepsini tek bakışta görür.
    return Row(
      children: <Widget>[
        for (final QuickActionCard action in actions) Expanded(child: action),
      ],
    );
  }
}

/// Kritik stok bölümü (şartname 7. bölüm).
///
/// Kart yerine ayraçla bölünmüş satırlar. Dört ayrı kart yerine tek bir
/// liste, hem daha az çizgi hem daha hızlı taranan bir blok veriyor.
class DashboardCriticalStock extends StatelessWidget {
  const DashboardCriticalStock({
    required this.products,
    required this.onProductTap,
    super.key,
  });

  final List<ProductStockSummary> products;
  final void Function(ProductStockSummary summary) onProductTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Column(
      children: <Widget>[
        for (int i = 0; i < products.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          _CriticalStockRow(
            summary: products[i],
            onTap: () => onProductTap(products[i]),
          ),
        ],
      ],
    );
  }
}

/// Kritik stok satırı.
///
/// Önemli olan "ne kadar eksik" olduğu; o yüzden minimum seviyeye uzaklık
/// yazılıyor. Sağdaki sayı durum renginde — burada renk gerçekten durumu
/// gösteriyor.
class _CriticalStockRow extends StatelessWidget {
  const _CriticalStockRow({required this.summary, required this.onTap});

  final ProductStockSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockStatus stockStatus = summary.status;
    final int shortage = summary.product.minStock - summary.totalQuantity;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            // İnce durum noktası: rozet kadar yer kaplamadan durumu taşır.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: stockStatus.tone.foreground(context),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    summary.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    shortage > 0
                        ? '$shortage ${summary.product.unit} eksik · '
                              'min. ${summary.product.minStock}'
                        : 'min. ${summary.product.minStock} '
                              '${summary.product.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              Formatters.integer.format(summary.totalQuantity),
              style: AppTypography.metricMedium.copyWith(
                color: stockStatus.tone.foreground(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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

/// Dashboard'un son hareketler listesi (şartname 7. bölüm).
///
/// Ayrı kartlar yerine ayraçla bölünmüş satırlar. Beş hareket için beş kart,
/// ekranda yirmi kenar çizgisi demekti; liste hem sakinleşti hem daha hızlı
/// taranıyor.
///
/// Hareket listesinin tam hâli `MovementTile` kartlarını kullanmaya devam
/// ediyor: orada satırlar filtrelenip tek tek incelendiği için kart sınırı
/// işe yarıyor, dashboard'da ise yalnızca göz gezdiriliyor.
class DashboardMovementList extends StatelessWidget {
  const DashboardMovementList({
    required this.movements,
    required this.onTap,
    super.key,
  });

  final List<MovementDetail> movements;
  final void Function(MovementDetail detail) onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Column(
      children: <Widget>[
        for (int i = 0; i < movements.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          _MovementRow(detail: movements[i], onTap: () => onTap(movements[i])),
        ],
      ],
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.detail, required this.onTap});

  final MovementDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockMovement movement = detail.movement;
    final StatusTone tone = movement.type.tone;
    final String? route = detail.routeLabel;

    // Transferde toplam stok değişmediği için işaret yanıltıcı olurdu;
    // yön zaten "A-01-01 → B-03-02" satırında görünür.
    final bool signed = movement.type.direction != MovementDirection.internal;
    final String quantityText = signed
        ? Formatters.signedInteger(movement.quantity)
        : Formatters.integer.format(movement.quantity.abs());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              movement.type.icon,
              size: AppSizes.iconMd,
              color: tone.foreground(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        quantityText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.foreground(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm - 2),
                      Expanded(
                        child: Text(
                          detail.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    <String>[
                      movement.type.label,
                      movement.reference,
                      ?route,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
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
      ),
    );
  }
}
