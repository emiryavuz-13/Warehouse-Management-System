import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../providers/dashboard_providers.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_metrics.dart';

/// Ana sayfa (şartname 7. bölüm).
///
/// Uygulamanın operasyon merkezi: kullanıcı ne durumda olduğunu görür ve
/// sık yaptığı işlere buradan başlar.
///
/// **Bölümler bağımsız yüklenir.** Dört ayrı provider kullanılıyor; özet
/// hazır olduğunda metrikler, hareket verisi geldiğinde trend çubukları
/// çiziliyor. Tek provider olsaydı en yavaş sorgu tüm ekranı bekletirdi.
///
/// Aşağı çekerek yenileme tüm veriyi tazeler (şartname 33. bölüm).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppRefreshIndicator(
          onRefresh: () async {
            ref.read(warehouseActionsProvider).refreshAll();
            // Yenileme göstergesinin hemen kaybolmaması için: veri zaten
            // yerelde, anında dönerse kullanıcı yenilendiğini fark etmez.
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            // Veri kısa olsa bile aşağı çekme çalışmalı.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: const <Widget>[
              SliverToBoxAdapter(child: DashboardHeader()),
              SliverToBoxAdapter(child: _MetricsSection()),
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(child: _QuickActionsSection()),
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(child: _CriticalStockSection()),
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(child: _RecentMovementsSection()),
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero figürü ve KPI blokları.
///
/// İki provider'ı birleştirir: özet sayıları ve 7 günlük hareket verisi.
/// Trend verisi henüz gelmemişse hero yine çizilir, yalnızca çubuklar
/// eksik kalır — sayı için trendi beklemek gereksiz.
class _MetricsSection extends ConsumerWidget {
  const _MetricsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSummary> summary = ref.watch(
      dashboardSummaryProvider,
    );
    final List<DailyMovementPoint> daily =
        ref.watch(dailyMovementsProvider).value ?? const <DailyMovementPoint>[];

    return Padding(
      padding: AppSpacing.screenPadding,
      child: AsyncValueView<DashboardSummary>(
        // Dashboard'un her bölümü bir bölüm; hiçbiri "ekranın tamamı"
        // değil. Üçü de tam boy hata gösterince aynı mesaj ekranda üst
        // üste tekrarlanıyor ve çalışan kısımlar (hızlı işlemler) aşağıya
        // itiliyordu.
        compactError: true,
        value: summary,
        onRetry: () => ref.invalidate(dashboardSummaryProvider),
        loading: const LoadingState(child: _MetricsSkeleton()),
        data: (DashboardSummary data) =>
            DashboardMetrics(summary: data, dailyMovements: daily),
      ),
    );
  }
}

/// Metriklerin iskeleti.
///
/// Gerçek düzenle aynı: aynı hero yüksekliği, aynı ayraç konumları. İçerik
/// geldiğinde sayfa zıplamaz.
class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();

    return DashboardMetrics(
      summary: const DashboardSummary.empty(),
      dailyMovements: <DailyMovementPoint>[
        for (int i = 6; i >= 0; i--)
          DailyMovementPoint(
            day: today.subtract(Duration(days: i)),
            inbound: 0,
            outbound: 0,
            transferCount: 0,
          ),
      ],
    );
  }
}

/// Hızlı işlemler bölümü.
///
/// Özet gelmeden de çizilir: rozet sayıları olmadan da kısayollar çalışır
/// ve şartname 34. bölümün "bir-iki dokunuş" hedefi yükleme sırasında da
/// geçerli kalır.
class _QuickActionsSection extends ConsumerWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashboardSummary summary =
        ref.watch(dashboardSummaryProvider).value ??
        const DashboardSummary.empty();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: DashboardQuickActions(summary: summary),
    );
  }
}

/// Kritik stok bölümü (şartname 7. bölüm).
///
/// Kritik ürün yoksa bölüm **hiç çizilmez**. "Kritik stok yok" diye boş bir
/// kutu göstermek dashboard'u uzatır ve iyi haberi gereksiz yere vurgular.
class _CriticalStockSection extends ConsumerWidget {
  const _CriticalStockSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductStockSummary>> products = ref.watch(
      criticalProductsProvider,
    );

    final List<ProductStockSummary>? data = products.value;
    if (data != null && data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Kritik Stok',
            actionLabel: 'Tümü',
            onAction: () => context.go(AppRoutes.stock),
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          ),
          AsyncValueView<List<ProductStockSummary>>(
            compactError: true,
            value: products,
            onRetry: () => ref.invalidate(criticalProductsProvider),
            loading: const LoadingState(child: _ListSkeleton(rows: 3)),
            isEmpty: (List<ProductStockSummary> items) => items.isEmpty,
            empty: const SizedBox.shrink(),
            data: (List<ProductStockSummary> items) => DashboardCriticalStock(
              products: items,
              onProductTap: (ProductStockSummary summary) =>
                  context.push(AppRoutes.productDetail(summary.product.id)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Son hareketler bölümü (şartname 7. bölüm).
class _RecentMovementsSection extends ConsumerWidget {
  const _RecentMovementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MovementDetail>> movements = ref.watch(
      recentMovementsProvider,
    );

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Son Hareketler',
            actionLabel: 'Tümü',
            onAction: () => context.push(AppRoutes.movements),
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          ),
          AsyncValueView<List<MovementDetail>>(
            compactError: true,
            value: movements,
            onRetry: () => ref.invalidate(recentMovementsProvider),
            loading: const LoadingState(child: _ListSkeleton(rows: 4)),
            isEmpty: (List<MovementDetail> items) => items.isEmpty,
            empty: const EmptyState(
              message: 'Henüz stok hareketi yok.',
              title: 'Hareket bulunmuyor',
            ),
            data: (List<MovementDetail> items) => DashboardMovementList(
              movements: items,
              onTap: (MovementDetail detail) =>
                  context.push(AppRoutes.productDetail(detail.product.id)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ayraçla bölünmüş liste iskeleti.
///
/// Kritik stok ve son hareketler aynı düzeni kullandığı için tek iskelet
/// ikisine de hizmet ediyor.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: Text('Kayıt yükleniyor'),
            ),
          ),
        ],
      ],
    );
  }
}
