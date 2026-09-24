import '../../models/models.dart';

/// Depolar ve bölgeler (şartname 18. bölüm).
///
/// Lokasyon ekranındaki ağaç yapısı buradan kurulur:
/// Merkez Depo → A Bölgesi → A-01-01
abstract final class MockWarehouses {
  /// Uygulamanın varsayılan olarak çalıştığı depo.
  static const String defaultWarehouseId = 'w-01';

  static const List<Warehouse> all = <Warehouse>[
    Warehouse(
      id: 'w-01',
      code: 'MRK',
      name: 'Merkez Depo',
      city: 'İstanbul',
      isDefault: true,
    ),
    Warehouse(
      id: 'w-02',
      code: 'AND',
      name: 'Anadolu Depo',
      city: 'Ankara',
    ),
  ];

  static const List<Zone> allZones = <Zone>[
    // Merkez Depo
    Zone(id: 'z-a', warehouseId: 'w-01', code: 'A', name: 'A Bölgesi'),
    Zone(id: 'z-b', warehouseId: 'w-01', code: 'B', name: 'B Bölgesi'),
    Zone(id: 'z-c', warehouseId: 'w-01', code: 'C', name: 'C Bölgesi'),
    Zone(id: 'z-m', warehouseId: 'w-01', code: 'M', name: 'Mal Kabul Alanı'),
    Zone(id: 'z-s', warehouseId: 'w-01', code: 'S', name: 'Sevkiyat Alanı'),

    // Anadolu Depo
    Zone(id: 'z-d', warehouseId: 'w-02', code: 'D', name: 'D Bölgesi'),
  ];
}
