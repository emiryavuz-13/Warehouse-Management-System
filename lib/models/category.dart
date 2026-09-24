import 'package:equatable/equatable.dart';

/// Ürün kategorisi. Ürün listesinde filtre olarak kullanılır.
class ProductCategory extends Equatable {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;

  /// İkonun adı, ör. `phone`, `laptop`.
  ///
  /// Model katmanı Flutter'dan bağımsız kalsın diye burada [IconData] değil
  /// metin anahtarı tutulur; UI katmanı bunu ikona çevirir.
  final String iconKey;

  ProductCategory copyWith({String? id, String? name, String? iconKey}) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, iconKey];
}
