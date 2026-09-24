import 'package:equatable/equatable.dart';

/// Depo içindeki bölge, ör. `A Bölgesi`, `Sevkiyat Alanı`.
///
/// Lokasyonlar bölgelere bağlıdır; lokasyon ekranındaki ağaç yapısı
/// Depo → Bölge → Lokasyon şeklinde kurulur (şartname 18. bölüm).
class Zone extends Equatable {
  const Zone({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.name,
  });

  final String id;
  final String warehouseId;

  /// Tek harfli/kısa kod, ör. `A`, `S`.
  final String code;

  /// Görünen ad, ör. `A Bölgesi`.
  final String name;

  Zone copyWith({
    String? id,
    String? warehouseId,
    String? code,
    String? name,
  }) {
    return Zone(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      code: code ?? this.code,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, warehouseId, code, name];
}
