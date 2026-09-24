import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Sayımdaki tek ürün satırı: sistemin bildiği miktar ile rafta sayılan
/// miktarın karşılaştırılması (şartname 16. bölüm).
class InventoryCountLine extends Equatable {
  const InventoryCountLine({
    required this.productId,
    required this.systemQuantity,
    this.countedQuantity,
  });

  final String productId;

  /// Sayım başladığı anda sistemde görünen miktar.
  ///
  /// Sayım sırasında dondurulur; aksi halde fark hesabı anlamsızlaşır.
  final int systemQuantity;

  /// Kullanıcının girdiği fiziksel miktar.
  ///
  /// Henüz sayılmamış satırlarda `null` olur — bu, "0 sayıldı" durumundan
  /// farklıdır ve ikisini ayırt edebilmek önemlidir.
  final int? countedQuantity;

  /// Sayım yapıldı mı?
  bool get isCounted => countedQuantity != null;

  /// Fiziksel - sistem farkı. Sayılmamışsa `null`.
  ///
  /// Negatif değer eksik, pozitif değer fazla stok anlamına gelir.
  int? get difference {
    final int? counted = countedQuantity;
    if (counted == null) return null;
    return counted - systemQuantity;
  }

  /// Sayım sistemle uyuşuyor mu?
  bool get hasDifference {
    final int? diff = difference;
    return diff != null && diff != 0;
  }

  InventoryCountLine copyWith({
    String? productId,
    int? systemQuantity,
    int? countedQuantity,
  }) {
    return InventoryCountLine(
      productId: productId ?? this.productId,
      systemQuantity: systemQuantity ?? this.systemQuantity,
      countedQuantity: countedQuantity ?? this.countedQuantity,
    );
  }

  /// Girilen sayımı temizleyip satırı "sayılmamış" haline döndürür.
  ///
  /// [copyWith] `null` ile bunu yapamaz (null "değiştirme" anlamına gelir),
  /// bu yüzden ayrı bir metot gerekir.
  InventoryCountLine clearCount() => InventoryCountLine(
    productId: productId,
    systemQuantity: systemQuantity,
  );

  @override
  List<Object?> get props => <Object?>[
    productId,
    systemQuantity,
    countedQuantity,
  ];
}

/// Bir lokasyon için açılmış sayım kaydı, ör. `IC-2026-031`.
class InventoryCount extends Equatable {
  const InventoryCount({
    required this.id,
    required this.code,
    required this.locationId,
    required this.lines,
    required this.status,
    required this.assignedUserId,
    required this.createdAt,
    this.completedAt,
  });

  final String id;

  /// Sayım numarası, ör. `IC-2026-031`.
  final String code;

  /// Sayımın yapıldığı lokasyon.
  final String locationId;

  final List<InventoryCountLine> lines;
  final CountStatus status;
  final String assignedUserId;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Sayılmış satır sayısı.
  int get countedLineCount =>
      lines.where((InventoryCountLine line) => line.isCounted).length;

  /// Sayım ilerlemesi (0.0 - 1.0).
  double get progress {
    if (lines.isEmpty) return 0;
    return (countedLineCount / lines.length).clamp(0.0, 1.0);
  }

  /// Sistemle uyuşmayan satır sayısı — özet kartında vurgulanır.
  int get differenceCount =>
      lines.where((InventoryCountLine line) => line.hasDifference).length;

  /// Tüm farkların toplamı. Negatif ise depoda beklenenden az mal var.
  int get netDifference => lines.fold(
    0,
    (int sum, InventoryCountLine line) => sum + (line.difference ?? 0),
  );

  /// Tüm satırlar sayıldı mı? Sayım ancak o zaman tamamlanabilir.
  bool get isFullyCounted =>
      lines.isNotEmpty &&
      lines.every((InventoryCountLine line) => line.isCounted);

  InventoryCount copyWith({
    String? id,
    String? code,
    String? locationId,
    List<InventoryCountLine>? lines,
    CountStatus? status,
    String? assignedUserId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return InventoryCount(
      id: id ?? this.id,
      code: code ?? this.code,
      locationId: locationId ?? this.locationId,
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
    locationId,
    lines,
    status,
    assignedUserId,
    createdAt,
    completedAt,
  ];
}
