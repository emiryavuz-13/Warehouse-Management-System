import '../../models/models.dart';

/// Bildirim merkezi kayıtları — 7 bildirim, 4'ü okunmamış.
///
/// İçerikleri mock veriyle **tutarlıdır**: kritik stok bildirimindeki miktar
/// gerçekten o ürünün stoğudur, bahsedilen sipariş ve kabul numaraları
/// gerçekten vardır. Böylece kullanıcı bildirime dokunup ilgili kayda
/// gittiğinde anlattığı durumla karşılaşır.
abstract final class MockNotifications {
  static List<AppNotification> build(DateTime now) => <AppNotification>[
    AppNotification(
      id: 'ntf-01',
      title: 'Kritik stok',
      message: 'Logitech MX Master 3S stok seviyesi 3 adede düştü.',
      type: NotificationType.criticalStock,
      createdAt: now.subtract(const Duration(minutes: 25)),
      targetRoute: '/products/p-10',
    ),
    AppNotification(
      id: 'ntf-02',
      title: 'Yeni görev',
      message: 'Sipariş #10452 için PK-102 toplama görevi oluşturuldu.',
      type: NotificationType.newTask,
      createdAt: now.subtract(const Duration(hours: 5, minutes: 40)),
      targetRoute: '/orders/ord-10452',
    ),
    AppNotification(
      id: 'ntf-03',
      title: 'Mal kabul',
      message: 'GR-1024 için ABC Elektronik\'ten 50 adet ürün bekleniyor.',
      type: NotificationType.goodsReceipt,
      createdAt: now.subtract(const Duration(hours: 2, minutes: 5)),
      targetRoute: '/receiving/gr-1024',
    ),
    AppNotification(
      id: 'ntf-04',
      title: 'Kritik stok',
      message: 'Lenovo ThinkPad E14 stoğu tükendi.',
      type: NotificationType.criticalStock,
      createdAt: now.subtract(const Duration(hours: 9)),
      targetRoute: '/products/p-08',
    ),
    AppNotification(
      id: 'ntf-05',
      title: 'Sayım',
      message: 'C-02-01 sayımı tamamlandı, 2 üründe fark tespit edildi.',
      type: NotificationType.inventoryCount,
      createdAt: now.subtract(const Duration(hours: 6, minutes: 30)),
      isRead: true,
      targetRoute: '/counts/ic-030',
    ),
    AppNotification(
      id: 'ntf-06',
      title: 'Sevkiyat',
      message: 'Sipariş #10457 Aras Kargo ile sevk edildi.',
      type: NotificationType.shipment,
      createdAt: now.subtract(const Duration(days: 1, hours: 6)),
      isRead: true,
      targetRoute: '/shipments/shp-012',
    ),
    AppNotification(
      id: 'ntf-07',
      title: 'Yeni görev',
      message: 'A-01-01 lokasyonu için IC-2026-031 sayımı atandı.',
      type: NotificationType.newTask,
      createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
      targetRoute: '/counts/ic-031',
    ),
  ];
}
