import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Toplama görevinin tek adımı: "şu üründen, şu lokasyondan, şu kadar al".
///
/// Sipariş satırından farkı **lokasyon bilgisi taşımasıdır**. Sipariş
/// "2 adet iPhone" der; picking satırı "A-01-01 rafından 2 adet iPhone" der.
class PickingLine extends Equatable {
  const PickingLine({
    required this.productId,
    required this.locationId,
    required this.requestedQuantity,
    this.pickedQuantity = 0,
  });

  final String productId;

  /// Ürünün alınacağı lokasyon.
  ///
  /// Şartname 26. bölüm: "ürün doğru lokasyondan alınmalıdır".
  final String locationId;

  final int requestedQuantity;
  final int pickedQuantity;

  int get remainingQuantity {
    final int remaining = requestedQuantity - pickedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isCompleted => pickedQuantity >= requestedQuantity;

  PickingLine copyWith({
    String? productId,
    String? locationId,
    int? requestedQuantity,
    int? pickedQuantity,
  }) {
    return PickingLine(
      productId: productId ?? this.productId,
      locationId: locationId ?? this.locationId,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      pickedQuantity: pickedQuantity ?? this.pickedQuantity,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    productId,
    locationId,
    requestedQuantity,
    pickedQuantity,
  ];
}

/// Bir sipariş için oluşturulan toplama görevi (şartname 14. bölüm).
///
/// Picking ekranı bu görevi adım adım yürütür: `1 / 3`, `2 / 3`, `3 / 3`.
class PickingTask extends Equatable {
  const PickingTask({
    required this.id,
    required this.code,
    required this.orderId,
    required this.lines,
    required this.status,
    required this.assignedUserId,
    required this.createdAt,
    this.completedAt,
  });

  final String id;

  /// Görev kodu, ör. `PK-102`.
  final String code;

  final String orderId;
  final List<PickingLine> lines;
  final PickingStatus status;
  final String assignedUserId;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Tamamlanmış satır sayısı.
  int get completedLineCount =>
      lines.where((PickingLine line) => line.isCompleted).length;

  /// Toplam satır sayısı — ekrandaki `x / y` göstergesinin paydası.
  int get totalLineCount => lines.length;

  /// Görev ilerlemesi (0.0 - 1.0).
  double get progress {
    if (lines.isEmpty) return 0;
    return (completedLineCount / lines.length).clamp(0.0, 1.0);
  }

  /// Sıradaki toplanacak satırın indeksi.
  ///
  /// Tüm satırlar bittiyse `-1` döner; picking ekranı bunu "tamamlandı"
  /// olarak yorumlar.
  int get currentLineIndex =>
      lines.indexWhere((PickingLine line) => !line.isCompleted);

  /// Sıradaki satır, yoksa `null`.
  PickingLine? get currentLine {
    final int index = currentLineIndex;
    return index == -1 ? null : lines[index];
  }

  /// Tüm satırlar toplandı mı?
  bool get isFullyPicked =>
      lines.isNotEmpty && lines.every((PickingLine line) => line.isCompleted);

  PickingTask copyWith({
    String? id,
    String? code,
    String? orderId,
    List<PickingLine>? lines,
    PickingStatus? status,
    String? assignedUserId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return PickingTask(
      id: id ?? this.id,
      code: code ?? this.code,
      orderId: orderId ?? this.orderId,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    code,
    orderId,
    lines,
    status,
    assignedUserId,
    createdAt,
    completedAt,
  ];
}
