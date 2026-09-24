import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';
import '../../providers/stock_providers.dart';

/// Stok listesinin filtre paneli (şartname 9. bölüm).
///
/// Ürün listesinden farkı **kategori filtresinin olmaması**: stok ekranı
/// katalog değil operasyon görünümü. Depo çalışanı "hangi raf" ve "hangi
/// durum" diye sorar, "hangi kategori" diye sormaz — kategoriyle daraltmak
/// isteyen ürün listesini kullanır.
///
/// Durum daraltması listenin üstündeki sayaç şeridinden de yapılabildiği
/// için burada ikinci kez sunulur; panel açıkken kullanıcının şeridi
/// hatırlaması beklenmemeli.
class StockFilterSheet extends ConsumerWidget {
  const StockFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return FilterSheet.show(
      context: context,
      builder: (BuildContext context) => const StockFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StockFilter filter = ref.watch(stockFilterProvider);
    final StockFilterController controller = ref.read(
      stockFilterProvider.notifier,
    );

    final List<LocationSummary> locations =
        ref.watch(locationsProvider).value ?? const <LocationSummary>[];

    return FilterSheet(
      title: 'Stok Filtresi',
      onApply: () => Navigator.of(context).pop(),
      onClear: filter.isActive ? controller.clearFilters : null,
      sections: <Widget>[
        FilterSection<StockStatus>(
          title: 'Stok Durumu',
          options: StockStatus.values,
          selected: filter.status,
          labelBuilder: (StockStatus s) => s.label,
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
      ],
    );
  }
}

/// Stok listesindeki etkin filtre çipleri.
///
/// Durum çipi burada gösterilmez: durum zaten sayaç şeridinde işaretli
/// duruyor, iki yerde aynı bilgiyi tekrarlamak gürültü olur.
class StockActiveFilterChips extends ConsumerWidget {
  const StockActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StockFilter filter = ref.watch(stockFilterProvider);
    if (filter.locationId == null) return const SizedBox.shrink();

    final List<LocationSummary> locations =
        ref.watch(locationsProvider).value ?? const <LocationSummary>[];
    final String? code = locations
        .where((LocationSummary l) => l.location.id == filter.locationId)
        .map((LocationSummary l) => l.location.code)
        .firstOrNull;

    if (code == null) return const SizedBox.shrink();

    return RemovableChip(
      label: code,
      onRemove: () =>
          ref.read(stockFilterProvider.notifier).toggleLocation(null),
    );
  }
}
