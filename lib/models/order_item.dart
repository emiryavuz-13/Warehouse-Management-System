import 'package:equatable/equatable.dart';

/// Siparişteki tek bir ürün satırı.
class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.requestedQuantity,
    this.pickedQuantity = 0,
  });

  final String productId;

  /// Müşterinin istediği adet.
  final int requestedQuantity;

  /// Şu ana kadar toplanan adet.
  ///
  /// Şartname 26. bölüm: toplanan miktar istenen miktarı aşamaz.
  final int pickedQuantity;

  /// Toplanması gereken kalan adet.
  int get remainingQuantity {
    final int remaining = requestedQuantity - pickedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  /// Bu satır tamamen toplandı mı?
  bool get isPicked => pickedQuantity >= requestedQuantity;

  OrderItem copyWith({
    String? productId,
    int? requestedQuantity,
    int? pickedQuantity,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      pickedQuantity: pickedQuantity ?? this.pickedQuantity,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    productId,
    requestedQuantity,
    pickedQuantity,
  ];
}
