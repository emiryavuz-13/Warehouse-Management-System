/// Lokasyon modülünün durumu ve veri kaynakları (şartname 18. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Lokasyon ekranında görüntülenen depo.
///
/// Uygulamanın "çalıştığı" depo ([currentWarehouseIdProvider]) değil, yalnızca
/// bu ekranda gezilen depo. Lokasyon listesi bir tarama ekranı; başka bir
/// depoya bakmak kullanıcının operasyon deposunu değiştirmemeli.
class BrowsedWarehouse extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String warehouseId) => state = warehouseId;
}

final NotifierProvider<BrowsedWarehouse, String?> browsedWarehouseProvider =
    NotifierProvider<BrowsedWarehouse, String?>(BrowsedWarehouse.new);

/// Lokasyon kodu araması.
class LocationQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value.trim();
}

final NotifierProvider<LocationQuery, String> locationQueryProvider =
    NotifierProvider<LocationQuery, String>(LocationQuery.new);

/// Depolar — birden fazlaysa ekranda seçici gösterilir.
final FutureProvider<List<Warehouse>> warehousesProvider =
    FutureProvider<List<Warehouse>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(warehouseRepositoryProvider).getWarehouses();
    });

/// Görüntülenen deponun bölgeleri.
final FutureProvider<List<Zone>> browsedZonesProvider =
    FutureProvider<List<Zone>>((Ref ref) async {
      ref.watch(dataRevisionProvider);
      final String warehouseId = await ref.watch(
        effectiveWarehouseIdProvider.future,
      );
      return ref
          .watch(warehouseRepositoryProvider)
          .getZones(warehouseId: warehouseId);
    });

/// Ekranda gezilen depo; seçim yapılmadıysa kullanıcının kendi deposu.
final FutureProvider<String> effectiveWarehouseIdProvider =
    FutureProvider<String>((Ref ref) async {
      final String? browsed = ref.watch(browsedWarehouseProvider);
      if (browsed != null) return browsed;
      return ref.watch(currentWarehouseIdProvider);
    });

/// Şartname 18. bölümdeki ağaç: bölge → lokasyonlar.
///
/// Gruplama veri katmanında değil burada yapılıyor: repository düz bir
/// lokasyon listesi döner, çünkü yerleştirme ve transfer ekranları da aynı
/// listeyi bölgesiz kullanıyor. Ağaç yalnızca bu ekranın ihtiyacı.
final FutureProvider<List<ZoneGroup>> locationTreeProvider =
    FutureProvider<List<ZoneGroup>>((Ref ref) async {
      ref.watch(dataRevisionProvider);

      final String warehouseId = await ref.watch(
        effectiveWarehouseIdProvider.future,
      );
      final String query = ref.watch(locationQueryProvider);

      final List<Zone> zones = await ref.watch(browsedZonesProvider.future);
      final List<LocationSummary> locations = await ref
          .watch(warehouseRepositoryProvider)
          .getLocations(warehouseId: warehouseId, query: query);

      final List<ZoneGroup> groups = <ZoneGroup>[
        for (final Zone zone in zones)
          ZoneGroup(
            zone: zone,
            locations: locations
                .where((LocationSummary l) => l.location.zoneId == zone.id)
                .toList(),
          ),
      ];

      // Arama sonucu boşalan bölgeler gizlenir; "A Bölgesi (0)" satırları
      // sonucu bulmayı zorlaştırır.
      return groups.where((ZoneGroup g) => g.locations.isNotEmpty).toList();
    });

/// Tek bir lokasyonun özeti.
final locationSummaryProvider =
    FutureProvider.family<LocationSummary?, String>((Ref ref, String id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(warehouseRepositoryProvider).getLocationById(id);
    });

/// Bir lokasyondaki ürünler (şartname 18. bölüm:
/// "lokasyona girildiğinde o lokasyondaki ürünleri göster").
final locationContentsProvider =
    FutureProvider.family<List<LocationStockLine>, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(dataRevisionProvider);
      return ref.watch(warehouseRepositoryProvider).getLocationContents(id);
    });

/// Bir bölge ve içindeki lokasyonlar.
class ZoneGroup {
  const ZoneGroup({required this.zone, required this.locations});

  final Zone zone;
  final List<LocationSummary> locations;

  int get totalQuantity => locations.fold(
    0,
    (int sum, LocationSummary l) => sum + l.usedQuantity,
  );

  int get totalCapacity => locations.fold(
    0,
    (int sum, LocationSummary l) => sum + l.location.capacity,
  );

  /// Bölgedeki dolu raf sayısı — başlıkta "3 / 5 dolu" olarak gösterilir.
  int get occupiedCount =>
      locations.where((LocationSummary l) => !l.isEmpty).length;
}
