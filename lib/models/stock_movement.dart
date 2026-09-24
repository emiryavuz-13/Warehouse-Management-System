import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Stoktaki her değişikliğin kaydı (şartname 19. bölüm).
///
/// Uygulamadaki **denetim izidir**: mal kabul, picking, transfer, sayım
/// düzeltmesi ve sevkiyat işlemlerinin her biri en az bir hareket üretir.
/// Şartname 24. bölümün "işlem gerçekten state'i değiştirmeli" maddesinin
/// kanıtı da budur — hareket listesinde kayıt görünmüyorsa işlem olmamıştır.
class StockMovement extends Equatable {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.type,
    required this.userId,
    required this.timestamp,
    required this.reference,
    this.sourceLocationId,
    this.targetLocationId,
    this.note,
  });

  final String id;
  final String productId;

  /// İşaretli miktar: giriş için pozitif, çıkış için negatif.
  ///
  /// Transfer hareketlerinde miktar pozitif yazılır, çünkü toplam stok
  /// değişmez; yön bilgisi [sourceLocationId] → [targetLocationId] ile verilir.
  final int quantity;

  final MovementType type;

  /// İşlemi yapan kullanıcı.
  final String userId;

  final DateTime timestamp;

  /// Hareketin kaynağını anlatan metin, ör. `Sipariş #10452`,
  /// `ABC Elektronik`, `GR-1024`.
  final String reference;

  /// Çıkış yapılan lokasyon. Mal kabulde boştur.
  final String? sourceLocationId;

  /// Giriş yapılan lokasyon. Sevkiyat ve picking çıkışında boştur.
  final String? targetLocationId;

  final String? note;

  /// Hareketin toplam stok üzerindeki net etkisi.
  ///
  /// Transfer depo içi taşıma olduğu için 0 döner; raporlardaki
  /// "giriş / çıkış" grafikleri bu değere dayanır.
  int get netEffect {
    return switch (type.direction) {
      MovementDirection.inbound => quantity.abs(),
      MovementDirection.outbound => -quantity.abs(),
      MovementDirection.internal => 0,
      MovementDirection.adjustment => quantity,
    };
  }

  /// Listede `A-01-01 → B-03-02` biçiminde gösterilecek yol bilgisi.
  ///
  /// Tek taraflı hareketlerde yalnızca ilgili lokasyon döner, hiçbiri yoksa
  /// `null` döner ve UI o satırı çizmez.
  String? routeLabel({String? sourceCode, String? targetCode}) {
    if (sourceCode != null && targetCode != null) {
      return '$sourceCode → $targetCode';
    }
    return targetCode ?? sourceCode;
  }

  StockMovement copyWith({
    String? id,
    String? productId,
    int? quantity,
    MovementType? type,
    String? userId,
    DateTime? timestamp,
    String? reference,
    String? sourceLocationId,
    String? targetLocationId,
    String? note,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      reference: reference ?? this.reference,
      sourceLocationId: sourceLocationId ?? this.sourceLocationId,
      targetLocationId: targetLocationId ?? this.targetLocationId,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    productId,
    quantity,
    type,
    userId,
    timestamp,
    reference,
    sourceLocationId,
    targetLocationId,
    note,
  ];
}
