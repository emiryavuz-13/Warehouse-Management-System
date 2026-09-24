import 'package:equatable/equatable.dart';

/// Fiziksel depo. Birden fazla bölge ve lokasyon içerir.
class Warehouse extends Equatable {
  const Warehouse({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    this.isDefault = false,
  });

  final String id;

  /// Kısa kod, ör. `MRK`.
  final String code;

  /// Görünen ad, ör. `Merkez Depo`.
  final String name;

  final String city;

  /// Kullanıcının varsayılan deposu. Profilde ve dashboard başlığında
  /// bu depo gösterilir.
  final bool isDefault;

  Warehouse copyWith({
    String? id,
    String? code,
    String? name,
    String? city,
    bool? isDefault,
  }) {
    return Warehouse(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      city: city ?? this.city,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, code, name, city, isDefault];
}
