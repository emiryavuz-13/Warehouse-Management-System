import '../../models/models.dart';

/// Müşteri siparişleri — 10 sipariş.
///
/// Şartname 23. bölüm gereği altı sipariş durumunun **hepsi** temsil edilir:
/// Yeni (3), Toplanıyor (2), Toplandı (1), Hazır (1), Sevk Edildi (2),
/// İptal (1). Böylece sipariş listesindeki her filtre boş sonuç vermez.
///
/// `#10452` şartname 13. bölümündeki örnek siparişin aynısıdır.
abstract final class MockOrders {
  static List<SalesOrder> build(DateTime now) => <SalesOrder>[
    // --- Toplanıyor: demo senaryosunun ana siparişi ---
    SalesOrder(
      id: 'ord-10452',
      orderNumber: '10452',
      customerName: 'ABC Teknoloji',
      status: OrderStatus.picking,
      priority: OrderPriority.normal,
      createdAt: now.subtract(const Duration(hours: 6)),
      dueDate: now.add(const Duration(days: 1)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-01', requestedQuantity: 2),
        OrderItem(productId: 'p-09', requestedQuantity: 5),
        OrderItem(productId: 'p-10', requestedQuantity: 1),
      ],
    ),

    // --- Yeni ---
    SalesOrder(
      id: 'ord-10453',
      orderNumber: '10453',
      customerName: 'Mavi Elektronik',
      status: OrderStatus.newOrder,
      priority: OrderPriority.high,
      createdAt: now.subtract(const Duration(hours: 3, minutes: 20)),
      dueDate: now.add(const Duration(days: 1)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-05', requestedQuantity: 1),
        OrderItem(productId: 'p-09', requestedQuantity: 10),
      ],
    ),
    SalesOrder(
      id: 'ord-10454',
      orderNumber: '10454',
      customerName: 'Deniz Bilişim',
      status: OrderStatus.newOrder,
      priority: OrderPriority.normal,
      createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      dueDate: now.add(const Duration(days: 2)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-13', requestedQuantity: 4),
        OrderItem(productId: 'p-11', requestedQuantity: 2),
      ],
    ),
    SalesOrder(
      id: 'ord-10460',
      orderNumber: '10460',
      customerName: 'Başkent Teknoloji',
      status: OrderStatus.newOrder,
      priority: OrderPriority.urgent,
      createdAt: now.subtract(const Duration(minutes: 35)),
      dueDate: now.add(const Duration(hours: 8)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-14', requestedQuantity: 2),
        OrderItem(productId: 'p-13', requestedQuantity: 3),
      ],
      note: 'Müşteri aynı gün teslimat talep etti.',
    ),

    // --- Toplanıyor (kısmen toplanmış) ---
    SalesOrder(
      id: 'ord-10461',
      orderNumber: '10461',
      customerName: 'Marmara Dağıtım',
      status: OrderStatus.picking,
      priority: OrderPriority.normal,
      createdAt: now.subtract(const Duration(hours: 4)),
      dueDate: now.add(const Duration(days: 1)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-12', requestedQuantity: 10, pickedQuantity: 10),
        OrderItem(productId: 'p-11', requestedQuantity: 4),
      ],
    ),

    // --- Toplandı: sevkiyata hazırlanıyor ---
    SalesOrder(
      id: 'ord-10455',
      orderNumber: '10455',
      customerName: 'Yıldız AVM',
      status: OrderStatus.picked,
      priority: OrderPriority.urgent,
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      dueDate: now.add(const Duration(hours: 10)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-02', requestedQuantity: 3, pickedQuantity: 3),
        OrderItem(productId: 'p-12', requestedQuantity: 6, pickedQuantity: 6),
      ],
    ),

    // --- Hazır: ürünler sevkiyat alanında (S-01) bekliyor ---
    SalesOrder(
      id: 'ord-10456',
      orderNumber: '10456',
      customerName: 'Teknoloji Merkezi',
      status: OrderStatus.ready,
      priority: OrderPriority.normal,
      createdAt: now.subtract(const Duration(days: 1, hours: 5)),
      dueDate: now.add(const Duration(hours: 20)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-05', requestedQuantity: 2, pickedQuantity: 2),
      ],
    ),

    // --- Sevk Edildi ---
    SalesOrder(
      id: 'ord-10457',
      orderNumber: '10457',
      customerName: 'Anadolu Ticaret',
      status: OrderStatus.shipped,
      priority: OrderPriority.normal,
      createdAt: now.subtract(const Duration(days: 2, hours: 4)),
      dueDate: now.subtract(const Duration(days: 1)),
      shippedAt: now.subtract(const Duration(days: 1, hours: 6)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-09', requestedQuantity: 20, pickedQuantity: 20),
        OrderItem(productId: 'p-15', requestedQuantity: 3, pickedQuantity: 3),
      ],
    ),
    SalesOrder(
      id: 'ord-10458',
      orderNumber: '10458',
      customerName: 'Ege Bilgisayar',
      status: OrderStatus.shipped,
      priority: OrderPriority.low,
      createdAt: now.subtract(const Duration(days: 3, hours: 1)),
      dueDate: now.subtract(const Duration(days: 2)),
      shippedAt: now.subtract(const Duration(days: 2, hours: 3)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-07', requestedQuantity: 2, pickedQuantity: 2),
      ],
    ),

    // --- İptal ---
    SalesOrder(
      id: 'ord-10459',
      orderNumber: '10459',
      customerName: 'Karadeniz Elektronik',
      status: OrderStatus.cancelled,
      priority: OrderPriority.normal,
      createdAt: now.subtract(const Duration(days: 2, hours: 8)),
      items: const <OrderItem>[
        OrderItem(productId: 'p-06', requestedQuantity: 1),
      ],
      note: 'Müşteri talebiyle iptal edildi.',
    ),
  ];
}
