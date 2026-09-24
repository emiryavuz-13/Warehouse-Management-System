import '../../models/models.dart';

/// Depo lokasyonları — 15 konum, 6 bölgeye dağılmış.
///
/// Kapasiteler bilinçli olarak farklıdır: raf lokasyonları dar, mal kabul ve
/// sevkiyat alanları geniştir. Lokasyon kartındaki doluluk göstergesi böylece
/// gerçekçi bir dağılım gösterir (şartname 18. bölüm).
abstract final class MockLocations {
  static const List<WarehouseLocation> all = <WarehouseLocation>[
    // --- A Bölgesi: telefon ve tablet rafları ---
    WarehouseLocation(
      id: 'loc-a0101',
      code: 'A-01-01',
      zoneId: 'z-a',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 120,
    ),
    WarehouseLocation(
      id: 'loc-a0102',
      code: 'A-01-02',
      zoneId: 'z-a',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 120,
    ),
    WarehouseLocation(
      id: 'loc-a0201',
      code: 'A-02-01',
      zoneId: 'z-a',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 150,
    ),

    // --- B Bölgesi: bilgisayar rafları ---
    WarehouseLocation(
      id: 'loc-b0101',
      code: 'B-01-01',
      zoneId: 'z-b',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 60,
    ),
    WarehouseLocation(
      id: 'loc-b0102',
      code: 'B-01-02',
      zoneId: 'z-b',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 100,
    ),
    WarehouseLocation(
      id: 'loc-b0201',
      code: 'B-02-01',
      zoneId: 'z-b',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 80,
    ),
    WarehouseLocation(
      id: 'loc-b0302',
      code: 'B-03-02',
      zoneId: 'z-b',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 90,
    ),

    // --- C Bölgesi: aksesuar rafları, yüksek kapasiteli ---
    WarehouseLocation(
      id: 'loc-c0101',
      code: 'C-01-01',
      zoneId: 'z-c',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 200,
    ),
    WarehouseLocation(
      id: 'loc-c0102',
      code: 'C-01-02',
      zoneId: 'z-c',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 200,
    ),
    WarehouseLocation(
      id: 'loc-c0201',
      code: 'C-02-01',
      zoneId: 'z-c',
      warehouseId: 'w-01',
      type: LocationType.storage,
      capacity: 180,
    ),

    // --- Mal Kabul Alanı: gelen mal önce buraya iner ---
    WarehouseLocation(
      id: 'loc-m01',
      code: 'M-01',
      zoneId: 'z-m',
      warehouseId: 'w-01',
      type: LocationType.receiving,
      capacity: 800,
    ),

    // --- Sevkiyat Alanı: toplanan sipariş buraya çıkar ---
    WarehouseLocation(
      id: 'loc-s01',
      code: 'S-01',
      zoneId: 'z-s',
      warehouseId: 'w-01',
      type: LocationType.shipping,
      capacity: 500,
    ),
    WarehouseLocation(
      id: 'loc-s02',
      code: 'S-02',
      zoneId: 'z-s',
      warehouseId: 'w-01',
      type: LocationType.shipping,
      capacity: 500,
    ),

    // --- Anadolu Depo ---
    WarehouseLocation(
      id: 'loc-d0101',
      code: 'D-01-01',
      zoneId: 'z-d',
      warehouseId: 'w-02',
      type: LocationType.storage,
      capacity: 100,
    ),
    WarehouseLocation(
      id: 'loc-d0102',
      code: 'D-01-02',
      zoneId: 'z-d',
      warehouseId: 'w-02',
      type: LocationType.storage,
      capacity: 100,
    ),
  ];
}
