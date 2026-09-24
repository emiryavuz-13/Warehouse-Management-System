import '../../models/models.dart';

/// Sevkiyat kayıtları — 4 kayıt, dört durumun her birinden bir tane.
///
/// Her sevkiyat bir siparişe bağlıdır ve ürün listesini kopyalamaz; müşteri,
/// ürünler ve adetler sipariş kaydından okunur.
///
/// `SH-2026-013` Demo 6'nın hedefidir: #10456 siparişi toplanmış, ürünler
/// S-01 sevkiyat alanında bekliyor, kullanıcı "Sevk Et" diyebilir.
abstract final class MockShipments {
  static List<Shipment> build(DateTime now) => <Shipment>[
    // --- Sevke Hazır: Demo 6'nın başlangıcı ---
    Shipment(
      id: 'shp-013',
      code: 'SH-2026-013',
      orderId: 'ord-10456',
      packageCount: 1,
      carrier: 'Yurtiçi Kargo',
      status: ShipmentStatus.ready,
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),

    // --- Hazırlanıyor: sipariş toplandı, paketleme sürüyor ---
    Shipment(
      id: 'shp-014',
      code: 'SH-2026-014',
      orderId: 'ord-10455',
      packageCount: 2,
      carrier: 'Aras Kargo',
      status: ShipmentStatus.preparing,
      createdAt: now.subtract(const Duration(hours: 20)),
    ),

    // --- Sevk Edildi ---
    Shipment(
      id: 'shp-012',
      code: 'SH-2026-012',
      orderId: 'ord-10457',
      packageCount: 4,
      carrier: 'Aras Kargo',
      status: ShipmentStatus.shipped,
      createdAt: now.subtract(const Duration(days: 1, hours: 18)),
      shippedAt: now.subtract(const Duration(days: 1, hours: 6)),
      trackingNumber: 'ARS4820193755',
    ),

    // --- Teslim Edildi ---
    Shipment(
      id: 'shp-011',
      code: 'SH-2026-011',
      orderId: 'ord-10458',
      packageCount: 1,
      carrier: 'MNG Kargo',
      status: ShipmentStatus.delivered,
      createdAt: now.subtract(const Duration(days: 2, hours: 18)),
      shippedAt: now.subtract(const Duration(days: 2, hours: 3)),
      trackingNumber: 'MNG9911204466',
    ),
  ];
}
