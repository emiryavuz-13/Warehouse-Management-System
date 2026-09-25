import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../providers/product_providers.dart';
import 'widgets/product_filter_sheet.dart';

/// Ürün listesi (şartname 8. bölüm).
///
/// Arama, kategori/stok durumu/lokasyon filtresi ve sıralama içerir.
///
/// **Arama çubuğu sabit, liste kayar.** Depo çalışanı listeyi tararken
/// aramaya dönmek için başa kaydırmak zorunda kalmamalı; bu ekranın asıl
/// işi arama.
class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductStockSummary>> products = ref.watch(
      productListProvider,
    );
    final ProductFilter filter = ref.watch(productFilterProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürünler'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(AppIcons.scan),
            tooltip: 'Barkod tara',
            onPressed: () => context.go(AppRoutes.scan),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: <Widget>[
                AppSearchBar(
                  hintText: 'Ürün adı, SKU veya barkod',
                  initialValue: filter.query,
                  activeFilterCount: filter.activeCount,
                  onChanged: ref.read(productFilterProvider.notifier).setQuery,
                  onFilterTap: () => ProductFilterSheet.show(context),
                  onScanTap: () => context.go(AppRoutes.scan),
                ),
                if (filter.isActive) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ActiveFilterChips(),
                  ),
                ],
              ],
            ),
          ),

          // Sonuç sayısı: filtreleme sonrası "kaç ürün kaldı" bilgisi,
          // listeyi saymadan görülmeli.
          _ResultSummary(products: products),
          Divider(height: 1, color: status.border),

          Expanded(
            child: AsyncValueView<List<ProductStockSummary>>(
              value: products,
              onRetry: () => ref.invalidate(productListProvider),
              loading: const _ProductListSkeleton(),
              isEmpty: (List<ProductStockSummary> items) => items.isEmpty,
              empty: EmptyState.noResults(
                query: filter.query,
                onClear: filter.isActive
                    ? ref.read(productFilterProvider.notifier).clearFilters
                    : null,
              ),
              data: (List<ProductStockSummary> items) => AppRefreshIndicator(
                onRefresh: () async {
                  ref.read(warehouseActionsProvider).refreshAll();
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.xxl,
                  ),
                  // Uzun listelerde yalnızca görünen satırlar çizilir
                  // (şartname 32. bölüm).
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: status.border),
                  itemBuilder: (BuildContext context, int index) {
                    final ProductStockSummary summary = items[index];
                    return ListEntrance(
                      index: index,
                      child: ProductCard(
                        summary: summary,
                        onTap: () => context.push(
                          AppRoutes.productDetail(summary.product.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste başındaki sonuç özeti.
///
/// Yalnızca sayı değil, toplam stoğu da gösterir: kullanıcı bir kategoriyi
/// filtrelediğinde "bu kategoride ne kadar mal var" sorusunun cevabını
/// listeyi toplamadan alır.
class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.products});

  final AsyncValue<List<ProductStockSummary>> products;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final List<ProductStockSummary> items =
        products.value ?? const <ProductStockSummary>[];

    if (items.isEmpty) return const SizedBox(height: AppSpacing.sm);

    final int totalStock = items.fold(
      0,
      (int sum, ProductStockSummary s) => sum + s.totalQuantity,
    );
    final int alertCount = items
        .where((ProductStockSummary s) => s.status != StockStatus.normal)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${items.length} ürün · '
              '${Formatters.integer.format(totalStock)} adet',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
          if (alertCount > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(StatusTone.warning.icon, size: 13, color: status.warning),
                const SizedBox(width: 4),
                Text(
                  '$alertCount uyarı',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: status.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Ürün listesinin iskeleti — gerçek satırla aynı yükseklikte.
class _ProductListSkeleton extends StatelessWidget {
  const _ProductListSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return LoadingState(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, _) => Divider(height: 1, color: status.border),
        itemBuilder: (BuildContext context, int index) => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: SizedBox(
            height: 40,
            width: double.infinity,
            child: Text('Ürün adı yükleniyor'),
          ),
        ),
      ),
    );
  }
}
