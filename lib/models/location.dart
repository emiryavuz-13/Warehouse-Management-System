import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Depodaki fiziksel konum, ör. `A-01-01`.
///
/// Stok her zaman bir lokasyona bağlıdır; transfer, putaway ve picking
/// işlemleri lokasyonlar arasında gerçekleşir.
class WarehouseLocation extends Equatable {
  const WarehouseLocation({
    required this.id,
    required this.code,
    required this.zoneId,
    required this.warehouseId,
    required this.type,
    required this.capacity,
  });

  final String id;

  /// Okunabilir konum kodu, ör. `A-01-01`.
  final String code;

  final String zoneId;
  final String warehouseId;

  /// Lokasyonun işlevi: raf, mal kabul alanı, sevkiyat alanı, karantina.
  final LocationType type;

  /// Lokasyonun alabileceği toplam adet.
  ///
  /// Doluluk oranı, lokasyondaki stok toplamının bu değere bölünmesiyle
  /// hesaplanır (şartname 18. bölüm: "kapasite" ve "doluluk").
  final int capacity;

  /// Verilen miktara göre doluluk oranı (0.0 - 1.0 arası).
  ///
  /// Kapasite aşılsa bile 1.0'da sınırlanır; ilerleme çubuğu taşmaz.
  double occupancyRatio(int usedQuantity) {
    if (capacity <= 0) return 0;
    final double ratio = usedQuantity / capacity;
    return ratio.clamp(0.0, 1.0);
  }

  /// Bu lokasyona en fazla kaç adet daha konulabilir.
  int availableCapacity(int usedQuantity) {
    final int remaining = capacity - usedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  /// Lokasyonun ait olduğu bölgenin kodu, ör. `A-01-01` için `A`.
  ///
  /// Zone kaydına erişmeden hızlı gruplama yapmak için kullanılır.
  String get zonePrefix => code.split('-').first;

  WarehouseLocation copyWith({
    String? id,
    String? code,
    String? zoneId,
    String? warehouseId,
    LocationType? type,
    int? capacity,
  }) {
    return WarehouseLocation(
      id: id ?? this.id,
      code: code ?? this.code,
      zoneId: zoneId ?? this.zoneId,
      warehouseId: warehouseId ?? this.warehouseId,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    code,
    zoneId,
    warehouseId,
    type,
    capacity,
  ];
}
