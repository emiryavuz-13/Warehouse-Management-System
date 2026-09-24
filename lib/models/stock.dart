import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Bir ürünün **belirli bir lokasyondaki** miktarı.
///
/// Bu uygulamadaki tek stok gerçeğidir. "Toplam stok" diye saklanan ayrı bir
/// alan yoktur; toplam her zaman ilgili `Stock` kayıtlarının toplanmasıyla
/// bulunur. Böylece transfer sonrası toplamın bozulması imkânsız hale gelir
/// (şartname 15. bölüm: transferde toplam değişmez, sadece dağılım değişir).
class Stock extends Equatable {
  const Stock({
    required this.id,
    required this.productId,
    required this.locationId,
    required this.quantity,
  });

  final String id;
  final String productId;
  final String locationId;

  /// Bu lokasyondaki adet. Şartname 26. bölüm gereği asla negatif olamaz;
  /// bu kural `WarehouseDatabase` tarafından korunur.
  final int quantity;

  /// Ürünün minimum stok eşiğine göre bu kaydın durumu.
  ///
  /// Durum saklanmaz, her zaman hesaplanır — böylece miktar değiştiğinde
  /// durumun güncellenmeyi unutması mümkün değildir.
  StockStatus statusFor(int minStock) =>
      StockStatus.fromQuantity(quantity, minStock);

  Stock copyWith({
    String? id,
    String? productId,
    String? locationId,
    int? quantity,
  }) {
    return Stock(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, productId, locationId, quantity];
}
