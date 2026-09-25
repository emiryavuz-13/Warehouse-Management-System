import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../providers/report_providers.dart';

/// Raporlar (şartname 22. bölüm).
///
/// Şartnamenin istediği beş rapor: son 7 gün girişleri, çıkışları, transfer
/// sayısı, günlük sevkiyat ve kritik stoklar.
///
/// *"Grafik kullanılıyorsa sade ve okunaklı olmalıdır."* Bu cümle grafik
/// seçimini belirledi:
///
/// - **Gruplu çubuk, çizgi değil.** Yedi gün az sayıda nokta; çizgi grafiği
///   aradaki günlerde olmayan bir süreklilik ima eder. Çubuk her günü ayrı
///   bir olay olarak gösterir.
/// - **Izgara çizgisi yok, eksen etiketi az.** Değerler çubukların üstünde
///   değil; kullanıcı kesin sayıyı çubuğa dokunarak alır. Sürekli görünen
///   on dört sayı grafiği tablolaştırırdı.
/// - **Renk yalnızca yön için:** giriş yeşil, çıkış turuncu. Gün ayrımı
///   boşlukla yapılıyor.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DailyMovementPoint>> daily = ref.watch(
      dailyMovementsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: AsyncValueView<List<DailyMovementPoint>>(
        value: daily,
        onRetry: () => ref.invalidate(dailyMovementsProvider),
        loading: const LoadingIndicator(message: 'Raporlar hazırlanıyor'),
        data: (List<DailyMovementPoint> points) => _Body(points: points),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.points});

  final List<DailyMovementPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final DashboardSummary summary =
        ref.watch(dashboardSummaryProvider).value ??
        const DashboardSummary.empty();

    final int inbound = points.fold(
      0,
      (int sum, DailyMovementPoint p) => sum + p.inbound,
    );
    final int outbound = points.fold(
      0,
      (int sum, DailyMovementPoint p) => sum + p.outbound,
    );
    final int transfers = points.fold(
      0,
      (int sum, DailyMovementPoint p) => sum + p.transferCount,
    );

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          // Net değişim hero: yedi günün tek cümlelik özeti.
          HeroFigure(
            value: Formatters.signedInteger(inbound - outbound),
            unit: 'adet',
            label: 'son 7 gün net değişim',
            breakdown: Text(
              '${Formatters.integer.format(inbound)} giriş · '
              '${Formatters.integer.format(outbound)} çıkış',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: 'Giriş ve Çıkış',
            subtitle: 'Günlük adet · çubuğa dokunarak kesin sayıyı görün',
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
          ),
          _InOutChart(points: points),
          const SizedBox(height: AppSpacing.md),
          const _ChartLegend(),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(
            title: 'Haftalık Özet',
            padding: EdgeInsets.only(bottom: AppSpacing.md),
          ),
          StatRow(
            blocks: <Widget>[
              StatBlock(
                label: 'Giriş',
                value: Formatters.integer.format(inbound),
                sublabel: 'adet',
              ),
              StatBlock(
                label: 'Çıkış',
                value: Formatters.integer.format(outbound),
                sublabel: 'adet',
              ),
              StatBlock(
                label: 'Transfer',
                value: '$transfers',
                sublabel: 'işlem',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),
          StatRow(
            blocks: <Widget>[
              StatBlock(
                label: 'Bugün sevkiyat',
                value: '${summary.todayShipmentCount}',
                sublabel: 'sipariş',
              ),
              StatBlock(
                label: 'Bugün mal kabul',
                value: '${summary.todayReceiptCount}',
                sublabel: 'kayıt',
              ),
              StatBlock(
                label: 'Bugün hareket',
                value: '${summary.todayMovementCount}',
                sublabel: 'işlem',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: 'Kritik Stok',
            subtitle: summary.stockAlertCount == 0
                ? 'Dikkat gerektiren ürün yok'
                : '${summary.criticalStockCount} kritik · '
                      '${summary.outOfStockCount} tükenmiş',
            actionLabel: summary.stockAlertCount == 0 ? null : 'Listeye git',
            onAction: summary.stockAlertCount == 0
                ? null
                : () => context.push(AppRoutes.products),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
          ),
          const _CriticalStockReport(),
        ],
      ),
    );
  }
}

/// Günlük giriş/çıkış çubuk grafiği.
class _InOutChart extends StatelessWidget {
  const _InOutChart({required this.points});

  final List<DailyMovementPoint> points;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    if (points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Gösterilecek hareket yok.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ),
      );
    }

    final double maxValue = points
        .expand<int>((DailyMovementPoint p) => <int>[p.inbound, p.outbound])
        .fold<int>(0, (int a, int b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          // Üstte biraz pay: en yüksek çubuk tavana yapışmamalı.
          maxY: maxValue == 0 ? 10 : maxValue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => status.neutral,
              getTooltipItem:
                  (
                    BarChartGroupData group,
                    int groupIndex,
                    BarChartRodData rod,
                    int rodIndex,
                  ) {
                    final DailyMovementPoint point = points[groupIndex];
                    return BarTooltipItem(
                      '${Formatters.shortDate.format(point.day)}\n'
                      '${rodIndex == 0 ? 'Giriş' : 'Çıkış'}: '
                      '${rod.toY.round()} adet',
                      Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      Formatters.shortDate.format(points[index].day),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral, fontSize: 10.5),
                    ),
                  );
                },
              ),
            ),
          ),
          // Izgara ve çerçeve yok: grafiğin çizgileri veriden daha görünür
          // olmamalı.
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: points[i].inbound.toDouble(),
                    color: status.success,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                  BarChartRodData(
                    toY: points[i].outbound.toDouble(),
                    color: status.warning,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _LegendDot(color: status.success, label: 'Giriş'),
        const SizedBox(width: AppSpacing.lg),
        _LegendDot(color: status.warning, label: 'Çıkış'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm - 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: status.neutral),
        ),
      ],
    );
  }
}

/// Kritik stok raporu — dashboard'dakinin tam listesi.
class _CriticalStockReport extends ConsumerWidget {
  const _CriticalStockReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final List<ProductStockSummary> items =
        ref.watch(allCriticalProductsProvider).value ??
        const <ProductStockSummary>[];

    if (items.isEmpty) {
      return Row(
        children: <Widget>[
          Icon(AppIcons.confirm, size: AppSizes.iconMd, color: status.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Tüm ürünler minimum stok seviyesinin üzerinde.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          _CriticalRow(summary: items[i]),
        ],
      ],
    );
  }
}

class _CriticalRow extends StatelessWidget {
  const _CriticalRow({required this.summary});

  final ProductStockSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Product product = summary.product;
    final StockStatus stockStatus = summary.status;
    final int shortfall = product.minStock - summary.totalQuantity;

    return InkWell(
      onTap: () => context.push(AppRoutes.productDetail(product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
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
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    shortfall > 0
                        ? '$shortfall adet eksik · min. ${product.minStock}'
                        : 'min. ${product.minStock}',
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
              Formatters.integer.format(summary.totalQuantity),
              style: AppTypography.metricMedium.copyWith(
                color: stockStatus.tone.foreground(context),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
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
