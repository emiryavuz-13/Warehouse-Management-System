import '../../models/models.dart';

/// Ürün kategorileri. Ürün listesindeki filtre çipleri bunları kullanır.
abstract final class MockCategories {
  static const List<ProductCategory> all = <ProductCategory>[
    ProductCategory(id: 'c-01', name: 'Telefon & Tablet', iconKey: 'phone'),
    ProductCategory(id: 'c-02', name: 'Bilgisayar', iconKey: 'laptop'),
    ProductCategory(id: 'c-03', name: 'Aksesuar', iconKey: 'cable'),
    ProductCategory(id: 'c-04', name: 'Ses & Görüntü', iconKey: 'headphones'),
  ];
}
