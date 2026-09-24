import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';

/// Dashboard özet kartları (şartname 7. bölüm).
///
/// Şartname yedi metrik sayıyor. Hepsini eşit boyutta ızgaraya dizmek
/// yerine kritik stok uyarısı tam genişlikte bir şerit olarak ayrıldı:
/// diğerleri "durum bilgisi", bu ise **eylem gerektiren** tek metrik.
/// Kalan altı kart iki sütuna düzgün oturuyor, tek başına kalan yedinci
/// kartın yarattığı boşluk da ortadan kalkıyor.
class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      SummaryCard(
        label: 'Toplam Ürün',
        value: Formatters.integer.format(summary.totalProducts),
        suffix: 'çeşit',
        icon: AppIcons.products,
        onTap: () => context.push(AppRoutes.products),
      ),
      SummaryCard(
        label: 'Toplam Stok',
        value: Formatters.integer.format(summary.totalStock),
        suffix: 'adet',
        icon: AppIcons.stock,
        onTap: () => context.go(AppRoutes.stock),
      ),
      SummaryCard(
        label: 'Bekleyen Sipariş',
        value: Formatters.integer.format(summary.pendingOrderCount),
        icon: AppIcons.orders,
        tone: StatusTone.info,
        onTap: () => context.go(AppRoutes.orders),
      ),
      SummaryCard(
        label: 'Toplanıyor',
        value: Formatters.integer.format(summary.pickingOrderCount),
        icon: AppIcons.picking,
        tone: StatusTone.warning,
        onTap: () => context.go(AppRoutes.orders),
      ),
      SummaryCard(
        label: 'Bugünkü Mal Kabul',
        value: Formatters.integer.format(summary.todayReceiptCount),
        icon: AppIcons.receiving,
        tone: StatusTone.success,
        onTap: () => context.push(AppRoutes.receiving),
      ),
      SummaryCard(
        label: 'Bugünkü Sevkiyat',
        value: Formatters.integer.format(summary.todayShipmentCount),
        icon: AppIcons.shipment,
        tone: StatusTone.neutral,
        onTap: () => context.push(AppRoutes.shipments),
      ),
    ];

    return Column(
      children: <Widget>[
        if (summary.stockAlertCount > 0) ...<Widget>[
          _StockAlertBanner(summary: summary),
          const SizedBox(height: AppSpacing.md),
        ],
        _MetricGrid(
          // Tablet ve yatay modda üç sütun; telefonda iki.
          columns: context.isWide ? 3 : 2,
          children: cards,
        ),
      ],
    );
  }
}

/// Kritik stok uyarı şeridi.
///
/// Tam genişlikte ve uyarı renginde: şartname 5. bölüm rengin durum
/// göstergesi olmasını istiyor ve bu, dashboard'daki tek "hemen bak"
/// metriği. Dokununca stok listesi kritik filtresiyle açılır — kullanıcı
/// uyarıyı gördükten sonra hangi ürünler olduğunu aramak zorunda kalmamalı.
class _StockAlertBanner extends StatelessWidget {
  const _StockAlertBanner({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool hasOutOfStock = summary.outOfStockCount > 0;
    final StatusTone tone = hasOutOfStock
        ? StatusTone.danger
        : StatusTone.warning;

    final List<String> parts = <String>[
      if (summary.criticalStockCount > 0)
        '${summary.criticalStockCount} kritik',
      if (summary.outOfStockCount > 0) '${summary.outOfStockCount} tükendi',
    ];

    return AppCard(
      onTap: () => context.go(AppRoutes.stock),
      accentColor: tone.foreground(context),
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: <Widget>[
          AppIconBox(
            icon: tone.icon,
            size: 40,
            iconSize: 20,
            background: tone.background(context),
            foreground: tone.foreground(context),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${summary.stockAlertCount} üründe stok uyarısı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: AppSizes.iconMd, color: status.neutral),
        ],
      ),
    );
  }
}

/// Kartları sabit sütun sayısında dizer.
///
/// `GridView` yerine `Row` + `Expanded` kullanılıyor: GridView sabit bir en
/// boy oranı ister, kart içeriği (uzun etiket, büyük sayı) değiştiğinde ya
/// taşar ya boşluk bırakır. Bu yöntemde satır yüksekliği içeriğe uyar.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children, required this.columns});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < children.length; i += columns) {
      final List<Widget> slice = children.sublist(
        i,
        (i + columns).clamp(0, children.length),
      );

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int j = 0; j < columns; j++) ...<Widget>[
                if (j > 0) const SizedBox(width: AppSpacing.md),
                // Eksik hücreler boş Expanded ile doldurulur; son satırdaki
                // kart tek başına ekranı kaplamasın.
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );

      if (i + columns < children.length) {
        rows.add(const SizedBox(height: AppSpacing.md));
      }
    }

    return Column(children: rows);
  }
}

/// Hızlı işlemler (şartname 7 ve 34. bölümler).
///
/// Şartname 34. bölüm "Ürün Tara, Sipariş Topla, Stok Transferi"
/// işlemlerinin bir-iki dokunuşta bulunmasını istiyor. Beş kısayol tek
/// satırda yatay kaydırılabilir şekilde duruyor; dikey ızgara olsaydı
/// dashboard'un yarısını kaplardı.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({required this.summary, super.key});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = <Widget>[
      QuickActionCard(
        label: 'Ürün Tara',
        icon: AppIcons.scan,
        tone: StatusTone.info,
        onTap: () => context.go(AppRoutes.scan),
      ),
      QuickActionCard(
        label: 'Mal Kabul',
        icon: AppIcons.receiving,
        tone: StatusTone.success,
        badgeCount: summary.todayReceiptCount,
        onTap: () => context.push(AppRoutes.receiving),
      ),
      QuickActionCard(
        label: 'Sipariş Topla',
        icon: AppIcons.picking,
        tone: StatusTone.warning,
        badgeCount: summary.pickingOrderCount,
        onTap: () => context.go(AppRoutes.orders),
      ),
      QuickActionCard(
        label: 'Transfer',
        icon: AppIcons.transfer,
        tone: StatusTone.transfer,
        onTap: () => context.push(AppRoutes.transfer),
      ),
      QuickActionCard(
        label: 'Sayım',
        icon: AppIcons.count,
        tone: StatusTone.neutral,
        onTap: () => context.push(AppRoutes.counts),
      ),
    ];

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) =>
            SizedBox(width: 96, child: actions[index]),
      ),
    );
  }
}

/// Kritik stok bölümü (şartname 7. bölüm).
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
    return Column(
      children: <Widget>[
        for (int i = 0; i < products.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _CriticalStockCard(
            summary: products[i],
            onTap: () => onProductTap(products[i]),
          ),
        ],
      ],
    );
  }
}

/// Kritik stok kartı.
///
/// Ürün kartının sadeleştirilmiş hali: dashboard'da lokasyon dökümü ve
/// kategori bilgisi gürültü yaratır. Burada önemli olan **ne kadar
/// eksik** olduğudur, o yüzden minimum stoğa uzaklık gösteriliyor.
class _CriticalStockCard extends StatelessWidget {
  const _CriticalStockCard({required this.summary, required this.onTap});

  final ProductStockSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockStatus stockStatus = summary.status;
    final int shortage = summary.product.minStock - summary.totalQuantity;

    return AppCard(
      onTap: onTap,
      accentColor: stockStatus.tone.foreground(context),
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  summary.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  shortage > 0
                      ? 'Minimum seviyenin $shortage ${summary.product.unit} '
                            'altında'
                      : 'Minimum: ${summary.product.minStock} '
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                Formatters.integer.format(summary.totalQuantity),
                style: AppTypography.metricMedium.copyWith(
                  color: stockStatus.tone.foreground(context),
                ),
              ),
              const SizedBox(height: 2),
              StockStatusBadge(status: stockStatus, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
