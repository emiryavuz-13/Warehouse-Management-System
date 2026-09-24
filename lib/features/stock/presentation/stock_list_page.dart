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
import '../providers/stock_providers.dart';
import 'widgets/stock_filter_sheet.dart';
import 'widgets/stock_row.dart';

/// Stok ekranı (şartname 9. bölüm).
///
/// *"Stok ekranı ürünlerden bağımsız olarak depo stokunun operasyonel
/// görünümünü sağlamalıdır."* Ürün listesi katalogdur — neyi satıyoruz.
/// Bu ekran operasyondur — neyin bitmek üzere olduğu, nerede durduğu.
///
/// Üç tasarım kararı bu farktan çıkıyor:
///
/// 1. **Sorunlu stoklar üstte.** Liste alfabetik değil; tükenmiş, sonra
///    kritik, sonra normal. Depo sorumlusunun ekranı açma nedeni genellikle
///    bir eksiktir, listenin sonuna kaydırarak bulmamalı.
/// 2. **Sayaç şeridi aynı zamanda filtre.** Sayılar hem özet veriyor hem
///    daraltma yapıyor; ayrı bir "özet kartları" bloğu koymak aynı sayıları
///    iki kez göstermek olurdu.
/// 3. **Satırlar yerinde açılıyor**, ayrı detay sayfası yok — gerekçesi
///    [StockRow] içinde.
class StockListPage extends ConsumerWidget {
  const StockListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductStockSummary>> stocks = ref.watch(
      stockListProvider,
    );
    final StockFilter filter = ref.watch(stockFilterProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok'),
        actions: <Widget>[
          // Lokasyonlar stok ekranının kardeşi: biri "ne kadar var",
          // diğeri "nerede duruyor" sorusunu yanıtlar.
          IconButton(
            icon: const Icon(AppIcons.locations),
            tooltip: 'Lokasyonlar',
            onPressed: () => context.push(AppRoutes.locations),
          ),
          IconButton(
            icon: const Icon(AppIcons.count),
            tooltip: 'Stok sayımı',
            onPressed: () => context.push(AppRoutes.counts),
          ),
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
                  activeFilterCount: filter.locationId == null ? 0 : 1,
                  onChanged: ref.read(stockFilterProvider.notifier).setQuery,
                  onFilterTap: () => StockFilterSheet.show(context),
                  onScanTap: () => context.go(AppRoutes.scan),
                ),
                if (filter.locationId != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: StockActiveFilterChips(),
                  ),
                ],
              ],
            ),
          ),

          const _StatusFilterStrip(),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: status.border),

          _StockSummaryLine(stocks: stocks),
          Divider(height: 1, color: status.border),

          Expanded(
            child: AsyncValueView<List<ProductStockSummary>>(
              value: stocks,
              onRetry: () => ref.invalidate(stockBaseProvider),
              loading: const _StockListSkeleton(),
              isEmpty: (List<ProductStockSummary> items) => items.isEmpty,
              empty: _EmptyForFilter(filter: filter),
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
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: status.border),
                  itemBuilder: (BuildContext context, int index) {
                    final ProductStockSummary summary = items[index];
                    final String productId = summary.product.id;

                    return StockRow(
                      // Satır açık/kapalı durumu listeler arası karışmasın
                      // diye ürüne bağlanır; filtre değişince doğru satır
                      // açık kalır.
                      key: ValueKey<String>(productId),
                      summary: summary,
                      onOpenProduct: () =>
                          context.push(AppRoutes.productDetail(productId)),
                      onTransfer: () =>
                          context.push(AppRoutes.transferForProduct(productId)),
                      onOpenLocation: (String locationId) =>
                          context.push(AppRoutes.locationDetail(locationId)),
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

/// Durum sayaçları şeridi — hem özet hem filtre (şartname 9. bölüm).
///
/// Sayılar durum filtresinden etkilenmez: "Kritik"e basıldığında şerit
/// `Normal 10 · Kritik 4 · Stok Yok 1` olarak kalır. Aksi halde kullanıcı
/// filtreyi açtığı anda geri dönmek için neyi kaybettiğini göremezdi.
///
/// Renk yalnızca gerçek durumda: "Tümü" ve "Normal" nötr, "Kritik" turuncu,
/// "Stok Yok" kırmızı — ve sayaç sıfırsa renk de sönük kalır, çünkü sıfır
/// kritik ürün bir uyarı değildir.
class _StatusFilterStrip extends ConsumerWidget {
  const _StatusFilterStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<StockStatus, int> counts = ref.watch(stockStatusCountsProvider);
    final StockStatus? selected = ref.watch(
      stockFilterProvider.select((StockFilter f) => f.status),
    );
    final StockFilterController controller = ref.read(
      stockFilterProvider.notifier,
    );

    final int total = counts.values.fold(0, (int a, int b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: StatRow(
        blocks: <Widget>[
          StatBlock(
            label: 'Tümü',
            value: Formatters.integer.format(total),
            sublabel: 'ürün',
            isSelected: selected == null,
            onTap: () => controller.toggleStatus(null),
          ),
          for (final StockStatus stockStatus in StockStatus.values)
            StatBlock(
              label: stockStatus.label,
              value: Formatters.integer.format(counts[stockStatus] ?? 0),
              sublabel: 'ürün',
              // Sıfır sayaç uyarı değildir; renk yalnızca gerçekten
              // dikkat gereken durumda görünür.
              tone: stockStatus == StockStatus.normal ||
                      (counts[stockStatus] ?? 0) == 0
                  ? null
                  : stockStatus.tone,
              isSelected: selected == stockStatus,
              onTap: () => controller.toggleStatus(stockStatus),
            ),
        ],
      ),
    );
  }
}

/// Listenin üstündeki bağlam satırı.
///
/// Ürün sayısının yanında **toplam adet** ve **stok kaydı sayısı** da var:
/// bir lokasyon filtrelendiğinde "bu rafta ne kadar mal, kaç kalem var"
/// sorusunun cevabı listeyi toplamadan görünmeli.
class _StockSummaryLine extends StatelessWidget {
  const _StockSummaryLine({required this.stocks});

  final AsyncValue<List<ProductStockSummary>> stocks;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final List<ProductStockSummary> items =
        stocks.value ?? const <ProductStockSummary>[];

    if (items.isEmpty) return const SizedBox(height: AppSpacing.sm);

    final int totalStock = items.fold(
      0,
      (int sum, ProductStockSummary s) => sum + s.totalQuantity,
    );
    final int lineCount = items.fold(
      0,
      (int sum, ProductStockSummary s) => sum + s.locations.length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.lg,
        AppSpacing.sm + 2,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${Formatters.integer.format(totalStock)} adet · '
              '$lineCount stok kaydı',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
          // Sıralama alfabetik olmadığı için söylenmeli; aksi halde
          // kullanıcı listenin neden bu sırada olduğunu anlamaz.
          Text(
            'sorunlular üstte',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: status.neutral,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş durum — hangi daraltmanın sonucu boşalttığını söyler.
///
/// "Kayıt yok" demek yetmez; kullanıcı neyi geri alacağını bilmeli.
class _EmptyForFilter extends ConsumerWidget {
  const _EmptyForFilter({required this.filter});

  final StockFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StockFilterController controller = ref.read(
      stockFilterProvider.notifier,
    );

    if (filter.query.trim().isNotEmpty) {
      return EmptyState.noResults(
        query: filter.query,
        onClear: filter.isActive ? controller.clearFilters : null,
      );
    }

    if (filter.status != null) {
      return EmptyState(
        icon: AppIcons.stock,
        title: '${filter.status!.label} ürün yok',
        message: 'Bu durumda hiçbir ürün bulunmuyor — iyi haber.',
        actionLabel: 'Filtreyi kaldır',
        onAction: () => controller.toggleStatus(null),
      );
    }

    return EmptyState(
      icon: AppIcons.stock,
      title: 'Stok kaydı yok',
      message: 'Seçili daraltmalarla eşleşen stok bulunamadı.',
      actionLabel: filter.isActive ? 'Filtreleri temizle' : null,
      onAction: filter.isActive ? controller.clearFilters : null,
    );
  }
}

/// Yükleme iskeleti — gerçek satırla aynı yükseklikte.
class _StockListSkeleton extends StatelessWidget {
  const _StockListSkeleton();

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
            child: Text('Stok kaydı yükleniyor'),
          ),
        ),
      ),
    );
  }
}
