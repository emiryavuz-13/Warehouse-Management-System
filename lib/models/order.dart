import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'order_item.dart';

/// Müşteri siparişi (şartname 13. bölüm).
///
/// Sınıf adı bilerek `Order` değil `SalesOrder`: Flutter'ın kendi `Order`
/// tipiyle karışmasın ve okurken ne olduğu belli olsun.
class SalesOrder extends Equatable {
  const SalesOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.items,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.dueDate,
    this.shippedAt,
    this.note,
  });

  final String id;

  /// Görünen numara, ör. `10452`. Arayüzde başına `#` eklenir.
  final String orderNumber;

  final String customerName;
  final List<OrderItem> items;
  final OrderStatus status;
  final OrderPriority priority;
  final DateTime createdAt;

  /// Sevk edilmesi beklenen tarih.
  final DateTime? dueDate;

  /// Sevk edildiği an. Sevk edilmemiş siparişlerde boştur.
  final DateTime? shippedAt;

  final String? note;

  /// Farklı ürün sayısı (satır adedi).
  int get lineCount => items.length;

  /// Siparişteki toplam adet.
  int get totalQuantity =>
      items.fold(0, (int sum, OrderItem item) => sum + item.requestedQuantity);

  /// Toplanmış toplam adet.
  int get pickedQuantity =>
      items.fold(0, (int sum, OrderItem item) => sum + item.pickedQuantity);

  /// Toplama ilerlemesi (0.0 - 1.0). Picking ekranındaki çubuk bunu kullanır.
  double get pickProgress {
    if (totalQuantity == 0) return 0;
    return (pickedQuantity / totalQuantity).clamp(0.0, 1.0);
  }

  /// Tüm satırlar tamamlandı mı?
  ///
  /// Şartname 26. bölüm: tüm ürünler tamamlanmadan sipariş "Toplandı"
  /// durumuna geçemez.
  bool get isFullyPicked =>
      items.isNotEmpty && items.every((OrderItem item) => item.isPicked);

  /// Arama kutusunun eşleştirmesi için tek metin (sipariş no + müşteri).
  String get searchText => '$orderNumber $customerName'.toLowerCase();

  SalesOrder copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    List<OrderItem>? items,
    OrderStatus? status,
    OrderPriority? priority,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? shippedAt,
    String? note,
  }) {
    return SalesOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      shippedAt: shippedAt ?? this.shippedAt,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    orderNumber,
    customerName,
    items,
    status,
    priority,
    createdAt,
    dueDate,
    shippedAt,
    note,
  ];
}
