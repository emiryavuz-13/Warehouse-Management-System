import 'package:equatable/equatable.dart';

/// Depoda tutulan fiziksel ürün.
///
/// Ürün, stok miktarını **taşımaz**. Miktar her zaman lokasyon bazında
/// `Stock` kayıtlarında durur; çünkü aynı ürün birden fazla lokasyonda
/// bulunabilir (şartname 9. bölüm). Toplam stok bu kayıtların toplamıdır.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.barcode,
    required this.brand,
    required this.categoryId,
    required this.unit,
    required this.minStock,
    this.description,
  });

  final String id;

  /// Stok sistemindeki benzersiz kod, ör. `IP15-128-BLK`.
  final String sku;

  final String name;

  /// Tarayıcının eşleştirdiği kod, ör. `8691234567890`.
  final String barcode;

  final String brand;
  final String categoryId;

  /// Ölçü birimi: `adet`, `kutu`, `metre` gibi.
  final String unit;

  /// Kritik stok eşiği. Toplam miktar bu değere inerse ürün "Kritik" sayılır
  /// (şartname 26. bölüm).
  final int minStock;

  final String? description;

  /// Ürün görseli olmadığında kart üzerinde gösterilecek baş harfler.
  ///
  /// Demo'da gerçek görsel bulunmadığı için placeholder üretir.
  String get initials {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  /// Arama kutusunun eşleştirmesi için tek bir metin.
  ///
  /// Şartname 31. bölüm: arama ürün adı, SKU ve barkod üzerinde çalışmalı.
  String get searchText => '$name $sku $barcode $brand'.toLowerCase();

  Product copyWith({
    String? id,
    String? sku,
    String? name,
    String? barcode,
    String? brand,
    String? categoryId,
    String? unit,
    int? minStock,
    String? description,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      categoryId: categoryId ?? this.categoryId,
      unit: unit ?? this.unit,
      minStock: minStock ?? this.minStock,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    sku,
    name,
    barcode,
    brand,
    categoryId,
    unit,
    minStock,
    description,
  ];
}
