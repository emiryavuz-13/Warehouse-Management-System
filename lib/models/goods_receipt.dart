import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Mal kabul kaydındaki tek ürün satırı.
class GoodsReceiptLine extends Equatable {
  const GoodsReceiptLine({
    required this.productId,
    required this.expectedQuantity,
    this.receivedQuantity = 0,
    this.targetLocationId,
  });

  final String productId;

  /// Tedarikçiden beklenen adet.
  final int expectedQuantity;

  /// Fiilen kabul edilen adet.
  ///
  /// Şartname 26. bölüm: beklenenden fazla kabul edilirse kullanıcıya uyarı
  /// gösterilir, ancak işlem engellenmez — gerçek depoda fazla gelen mal
  /// kabul edilebilir.
  final int receivedQuantity;

  /// Putaway sonrası ürünün yerleştirildiği lokasyon (şartname 12. bölüm).
  ///
  /// Yerleştirme yapılmadan önce boştur.
  final String? targetLocationId;

  /// Henüz kabul edilmemiş adet.
  int get remainingQuantity {
    final int remaining = expectedQuantity - receivedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  /// Beklenenden fazla mal geldi mi? UI bunu uyarı olarak gösterir.
  bool get isOverReceived => receivedQuantity > expectedQuantity;

  /// Satır kabul edildi ve bir lokasyona yerleştirildi mi?
  bool get isPutAway => receivedQuantity > 0 && targetLocationId != null;

  bool get isCompleted => receivedQuantity >= expectedQuantity;

  GoodsReceiptLine copyWith({
    String? productId,
    int? expectedQuantity,
    int? receivedQuantity,
    String? targetLocationId,
  }) {
    return GoodsReceiptLine(
      productId: productId ?? this.productId,
      expectedQuantity: expectedQuantity ?? this.expectedQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      targetLocationId: targetLocationId ?? this.targetLocationId,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    productId,
    expectedQuantity,
    receivedQuantity,
    targetLocationId,
  ];
}

/// Depoya gelen malın kabul kaydı (şartname 11. bölüm).
class GoodsReceipt extends Equatable {
  const GoodsReceipt({
    required this.id,
    required this.code,
    required this.supplierName,
    required this.lines,
    required this.status,
    required this.expectedDate,
    this.completedAt,
    this.note,
  });

  final String id;

  /// Kabul numarası, ör. `GR-1024`.
  final String code;

  final String supplierName;
  final List<GoodsReceiptLine> lines;
  final ReceiptStatus status;

  /// Malın beklendiği tarih.
  final DateTime expectedDate;

  final DateTime? completedAt;
  final String? note;

  /// Beklenen toplam adet.
  int get totalExpected => lines.fold(
    0,
    (int sum, GoodsReceiptLine line) => sum + line.expectedQuantity,
  );

  /// Kabul edilen toplam adet.
  int get totalReceived => lines.fold(
    0,
    (int sum, GoodsReceiptLine line) => sum + line.receivedQuantity,
  );

  /// Kabul ilerlemesi (0.0 - 1.0).
  double get progress {
    if (totalExpected == 0) return 0;
    return (totalReceived / totalExpected).clamp(0.0, 1.0);
  }

  /// Tüm satırlar kabul edilip yerleştirildi mi?
  bool get isFullyReceived =>
      lines.isNotEmpty &&
      lines.every((GoodsReceiptLine line) => line.isCompleted);

  /// Herhangi bir satırda fazla kabul var mı?
  bool get hasOverReceipt =>
      lines.any((GoodsReceiptLine line) => line.isOverReceived);

  String get searchText => '$code $supplierName'.toLowerCase();

  GoodsReceipt copyWith({
    String? id,
    String? code,
    String? supplierName,
    List<GoodsReceiptLine>? lines,
    ReceiptStatus? status,
    DateTime? expectedDate,
    DateTime? completedAt,
    String? note,
  }) {
    return GoodsReceipt(
      id: id ?? this.id,
      code: code ?? this.code,
      supplierName: supplierName ?? this.supplierName,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      expectedDate: expectedDate ?? this.expectedDate,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    code,
    supplierName,
    lines,
    status,
    expectedDate,
    completedAt,
    note,
  ];
}
