import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
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
/// **Bölümler bağımsız yüklenir.** Üç ayrı provider kullanılıyor; özet
/// kartları hazır olduğunda gösteriliyor, kritik stok listesi kendi
/// iskeletini çiziyor. Tek bir provider olsaydı en yavaş sorgu tüm ekranı
/// bekletirdi.
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
            slivers: <Widget>[
              const SliverToBoxAdapter(child: DashboardHeader()),

              // --- Özet kartları ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: _MetricsSection(),
                ),
              ),

              // --- Hızlı işlemler ---
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: const SectionHeader(
                    title: 'Hızlı İşlemler',
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _QuickActionsSection()),

              // --- Kritik stok ---
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(child: _CriticalStockSection()),

              // --- Son hareketler ---
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(child: _RecentMovementsSection()),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Özet kartları bölümü.
class _MetricsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSummary> summary = ref.watch(
      dashboardSummaryProvider,
    );

    return AsyncValueView<DashboardSummary>(
      value: summary,
      onRetry: () => ref.invalidate(dashboardSummaryProvider),
      loading: const LoadingState(child: _MetricsSkeleton()),
      data: (DashboardSummary data) => DashboardMetrics(summary: data),
    );
  }
}

/// Özet kartlarının iskeleti.
///
/// Gerçek düzenle aynı: iki sütun, aynı kart yüksekliği. İçerik geldiğinde
/// sayfa zıplamaz.
class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return DashboardMetrics(
      summary: const DashboardSummary(
        totalProducts: 15,
        totalStock: 1248,
        criticalStockCount: 0,
        outOfStockCount: 0,
        pendingOrderCount: 3,
        pickingOrderCount: 2,
        readyToShipCount: 2,
        todayReceiptCount: 1,
        todayShipmentCount: 1,
        unreadNotificationCount: 0,
      ),
    );
  }
}

/// Hızlı işlemler bölümü.
///
/// Özet gelmeden de çizilir: rozet sayıları olmadan da kısayollar çalışır
/// ve şartname 34. bölümün "bir-iki dokunuş" hedefi yükleme sırasında da
/// geçerli kalır.
class _QuickActionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashboardSummary summary =
        ref.watch(dashboardSummaryProvider).value ??
        const DashboardSummary(
          totalProducts: 0,
          totalStock: 0,
          criticalStockCount: 0,
          outOfStockCount: 0,
          pendingOrderCount: 0,
          pickingOrderCount: 0,
          readyToShipCount: 0,
          todayReceiptCount: 0,
          todayShipmentCount: 0,
          unreadNotificationCount: 0,
        );

    return DashboardQuickActions(summary: summary);
  }
}

/// Kritik stok bölümü.
///
/// Kritik ürün yoksa bölüm **hiç çizilmez**. "Kritik stok yok" diye boş bir
/// kutu göstermek dashboard'u uzatır ve iyi haberi gereksiz yere vurgular.
class _CriticalStockSection extends ConsumerWidget {
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
            subtitle: 'Minimum seviyenin altındaki ürünler',
            actionLabel: 'Tümünü gör',
            onAction: () => context.go(AppRoutes.stock),
          ),
          AsyncValueView<List<ProductStockSummary>>(
            value: products,
            onRetry: () => ref.invalidate(criticalProductsProvider),
            loading: const LoadingState(child: _CriticalStockSkeleton()),
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

class _CriticalStockSkeleton extends StatelessWidget {
  const _CriticalStockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < 2; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          const AppCard(
            child: SizedBox(height: 44, child: Text('Ürün adı yükleniyor')),
          ),
        ],
      ],
    );
  }
}

/// Son hareketler bölümü (şartname 7. bölüm).
class _RecentMovementsSection extends ConsumerWidget {
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
            actionLabel: 'Tümünü gör',
            onAction: () => context.push(AppRoutes.movements),
          ),
          AsyncValueView<List<MovementDetail>>(
            value: movements,
            onRetry: () => ref.invalidate(recentMovementsProvider),
            loading: const LoadingState(child: _MovementsSkeleton()),
            isEmpty: (List<MovementDetail> items) => items.isEmpty,
            empty: const AppCard(
              child: EmptyState(
                message: 'Henüz stok hareketi yok.',
                title: 'Hareket bulunmuyor',
              ),
            ),
            data: (List<MovementDetail> items) => Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  MovementTile(
                    detail: items[i],
                    onTap: () => context.push(
                      AppRoutes.productDetail(items[i].product.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsSkeleton extends StatelessWidget {
  const _MovementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          const AppCard(
            child: SizedBox(
              height: 52,
              child: Text('Hareket kaydı yükleniyor'),
            ),
          ),
        ],
      ],
    );
  }
}
