import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Toplanmış siparişin depodan çıkış kaydı (şartname 17. bölüm).
///
/// Sevkiyat siparişin kendisini kopyalamaz; [orderId] üzerinden ona bağlanır.
/// Ürün listesi, adetler ve müşteri bilgisi sipariş kaydından okunur.
class Shipment extends Equatable {
  const Shipment({
    required this.id,
    required this.code,
    required this.orderId,
    required this.packageCount,
    required this.carrier,
    required this.status,
    required this.createdAt,
    this.shippedAt,
    this.trackingNumber,
  });

  final String id;

  /// Sevkiyat numarası, ör. `SH-2026-014`.
  final String code;

  final String orderId;

  /// Koli/paket adedi.
  final int packageCount;

  /// Taşıyıcı firma, ör. `Aras Kargo`.
  final String carrier;

  final ShipmentStatus status;
  final DateTime createdAt;

  /// Sevk edildiği an. Sevk edilmemişse boştur.
  final DateTime? shippedAt;

  final String? trackingNumber;

  /// Sevk işlemi yapılabilir mi?
  ///
  /// Şartname 26. bölüm: sevk edilen sipariş yeniden sevk edilemez.
  bool get canShip => !status.isShipped;

  String get searchText =>
      '$code $carrier ${trackingNumber ?? ''}'.toLowerCase();

  Shipment copyWith({
    String? id,
    String? code,
    String? orderId,
    int? packageCount,
    String? carrier,
    ShipmentStatus? status,
    DateTime? createdAt,
    DateTime? shippedAt,
    String? trackingNumber,
  }) {
    return Shipment(
      id: id ?? this.id,
      code: code ?? this.code,
      orderId: orderId ?? this.orderId,
      packageCount: packageCount ?? this.packageCount,
      carrier: carrier ?? this.carrier,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      shippedAt: shippedAt ?? this.shippedAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    code,
    orderId,
    packageCount,
    carrier,
    status,
    createdAt,
    shippedAt,
    trackingNumber,
  ];
}
