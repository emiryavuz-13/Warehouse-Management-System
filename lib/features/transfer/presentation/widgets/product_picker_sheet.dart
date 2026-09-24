import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../providers/transfer_providers.dart';

/// Transfer için ürün seçme paneli (şartname 15. bölüm, "Ürün Seç").
///
/// Ürün listesinin kendisini yeniden kullanmıyorum: orada filtre, sıralama
/// ve durum rozetleri var; burada tek bir soru sorulur — "hangi ürün".
/// Panel arama ve stok miktarından ibaret kalırsa seçim tek dokunuşa iner.
///
/// Stoksuz ürünler hiç listelenmez ([transferableProductsProvider]).
class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({super.key});

  /// Paneli açar; seçilen ürünün özetini döner.
  static Future<ProductStockSummary?> show(BuildContext context) {
    return showModalBottomSheet<ProductStockSummary>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => const ProductPickerSheet(),
    );
  }

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final AsyncValue<List<ProductStockSummary>> products = ref.watch(
      transferableProductsProvider,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ürün Seç',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSearchBar(
                  hintText: 'Ürün adı, SKU veya barkod',
                  // Filtre ve tarama kısayolu yok: panelin tek işi seçim.
                  onChanged: (String value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: status.border),
          Flexible(
            child: AsyncValueView<List<ProductStockSummary>>(
              value: products,
              onRetry: () => ref.invalidate(transferableProductsProvider),
              data: (List<ProductStockSummary> items) {
                final List<ProductStockSummary> filtered = _query.isEmpty
                    ? items
                    : items
                          .where(
                            (ProductStockSummary s) =>
                                s.product.searchText.contains(_query),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return EmptyState.noResults(query: _query);
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: status.border),
                  itemBuilder: (BuildContext context, int index) => ProductCard(
                    summary: filtered[index],
                    onTap: () => Navigator.of(context).pop(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
