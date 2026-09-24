import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';
import '../../providers/product_providers.dart';

/// Ürün listesinin filtre paneli (şartname 8. bölüm).
///
/// Şartnamenin istediği dört daraltma burada: kategori, stok durumu,
/// lokasyon ve sıralama.
///
/// **Filtreler anında uygulanır.** Panel açıkken bir çipe dokunulduğunda
/// arkadaki liste hemen güncellenir; "Uygula" yalnızca paneli kapatır.
/// Kullanıcı seçiminin sonucunu görmek için paneli kapatmak zorunda
/// kalmamalı — özellikle "sonuç yok" durumunda, nedenini görmeden panelden
/// çıkmak kafa karıştırır.
class ProductFilterSheet extends ConsumerWidget {
  const ProductFilterSheet({super.key});

  /// Paneli açar.
  static Future<void> show(BuildContext context) {
    return FilterSheet.show(
      context: context,
      builder: (BuildContext context) => const ProductFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductFilter filter = ref.watch(productFilterProvider);
    final ProductFilterController controller = ref.read(
      productFilterProvider.notifier,
    );

    final List<ProductCategory> categories =
        ref.watch(categoriesProvider).value ?? const <ProductCategory>[];
    final List<LocationSummary> locations =
        ref.watch(locationsProvider).value ?? const <LocationSummary>[];

    return FilterSheet(
      onApply: () => Navigator.of(context).pop(),
      onClear: filter.isActive ? controller.clearFilters : null,
      sections: <Widget>[
        FilterSection<ProductCategory>(
          title: 'Kategori',
          options: categories,
          selected: categories
              .where((ProductCategory c) => c.id == filter.categoryId)
              .firstOrNull,
          labelBuilder: (ProductCategory c) => c.name,
          iconBuilder: (ProductCategory c) => categoryIcon(c.iconKey),
          onSelected: (ProductCategory? c) => controller.toggleCategory(c?.id),
        ),

        FilterSection<StockStatus>(
          title: 'Stok Durumu',
          options: StockStatus.values,
          selected: filter.status,
          labelBuilder: (StockStatus s) => s.label,
          // Durum çipleri kendi renklerinde: "Kritik" filtresi turuncu,
          // "Stok Yok" kırmızı görünür.
          toneBuilder: (StockStatus s) => s.tone,
          onSelected: controller.toggleStatus,
        ),

        FilterSection<LocationSummary>(
          title: 'Lokasyon',
          options: locations,
          selected: locations
              .where((LocationSummary l) => l.location.id == filter.locationId)
              .firstOrNull,
          labelBuilder: (LocationSummary l) => l.location.code,
          onSelected: (LocationSummary? l) =>
              controller.toggleLocation(l?.location.id),
        ),

        FilterSection<ProductSort>(
          title: 'Sıralama',
          options: ProductSort.values,
          selected: filter.sort,
          labelBuilder: (ProductSort s) => s.label,
          // Sıralama her zaman bir değere sahiptir; "Tümü" seçeneği yok.
          allowNone: false,
          onSelected: (ProductSort? s) {
            if (s != null) controller.setSort(s);
          },
        ),
      ],
    );
  }
}

/// Listenin üstünde duran etkin filtre özeti.
///
/// Kullanıcı filtre panelini kapattıktan sonra hangi daraltmaların açık
/// olduğunu görmeli; aksi halde "neden bu kadar az ürün var" sorusunun
/// cevabı paneli tekrar açmaktan geçer. Her çip tek dokunuşla kaldırılır.
class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductFilter filter = ref.watch(productFilterProvider);
    if (!filter.isActive) return const SizedBox.shrink();

    final ProductFilterController controller = ref.read(
      productFilterProvider.notifier,
    );
    final List<ProductCategory> categories =
        ref.watch(categoriesProvider).value ?? const <ProductCategory>[];
    final List<LocationSummary> locations =
        ref.watch(locationsProvider).value ?? const <LocationSummary>[];

    final String? categoryName = categories
        .where((ProductCategory c) => c.id == filter.categoryId)
        .map((ProductCategory c) => c.name)
        .firstOrNull;
    final String? locationCode = locations
        .where((LocationSummary l) => l.location.id == filter.locationId)
        .map((LocationSummary l) => l.location.code)
        .firstOrNull;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (categoryName != null)
          RemovableChip(
            label: categoryName,
            onRemove: () => controller.toggleCategory(null),
          ),
        if (filter.status != null)
          RemovableChip(
            label: filter.status!.label,
            tone: filter.status!.tone,
            onRemove: () => controller.toggleStatus(null),
          ),
        if (locationCode != null)
          RemovableChip(
            label: locationCode,
            onRemove: () => controller.toggleLocation(null),
          ),
      ],
    );
  }
}
