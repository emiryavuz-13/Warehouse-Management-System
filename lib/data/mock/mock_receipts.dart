import '../../models/models.dart';

/// Mal kabul kayıtları — 6 kayıt.
///
/// Üç durumun hepsi temsil edilir: Bekliyor (3), Kabul Ediliyor (1),
/// Tamamlandı (2).
///
/// `GR-1024` şartname 11. bölümündeki örnek kaydın aynısıdır ve Demo 2'nin
/// başlangıç noktasıdır: 50 adet iPhone 15 bekleniyor, henüz hiçbiri kabul
/// edilmemiş. Kullanıcı bunu kabul edip A-01-01'e yerleştirdiğinde stok
/// 24'ten 74'e çıkar.
abstract final class MockGoodsReceipts {
  static List<GoodsReceipt> build(DateTime now) => <GoodsReceipt>[
    // --- Bekliyor: Demo 2'nin başlangıcı ---
    GoodsReceipt(
      id: 'gr-1024',
      code: 'GR-1024',
      supplierName: 'ABC Elektronik',
      status: ReceiptStatus.pending,
      expectedDate: now,
      lines: const <GoodsReceiptLine>[
        GoodsReceiptLine(productId: 'p-01', expectedQuantity: 50),
      ],
    ),

    // --- Kabul Ediliyor: kısmen kabul edilmiş, yerleştirme bekliyor ---
    GoodsReceipt(
      id: 'gr-1025',
      code: 'GR-1025',
      supplierName: 'Teknosa Toptan',
      status: ReceiptStatus.receiving,
      expectedDate: now.subtract(const Duration(hours: 4)),
      lines: const <GoodsReceiptLine>[
        // Kabul edildi ama henüz rafa kaldırılmadı: mal kabul alanında (M-01)
        // bekliyor. targetLocationId boş olduğu için putaway listesinde çıkar.
        GoodsReceiptLine(
          productId: 'p-09',
          expectedQuantity: 200,
          receivedQuantity: 120,
        ),
        GoodsReceiptLine(productId: 'p-11', expectedQuantity: 40),
      ],
      note: 'Kalan 80 adet kablo ikinci araçla gelecek.',
    ),

    // --- Bekliyor ---
    GoodsReceipt(
      id: 'gr-1026',
      code: 'GR-1026',
      supplierName: 'Sony Türkiye',
      status: ReceiptStatus.pending,
      expectedDate: now.add(const Duration(days: 1)),
      lines: const <GoodsReceiptLine>[
        GoodsReceiptLine(productId: 'p-14', expectedQuantity: 25),
      ],
    ),
    GoodsReceipt(
      id: 'gr-1027',
      code: 'GR-1027',
      supplierName: 'Dell Türkiye',
      status: ReceiptStatus.pending,
      expectedDate: now.add(const Duration(days: 2)),
      lines: const <GoodsReceiptLine>[
        GoodsReceiptLine(productId: 'p-07', expectedQuantity: 15),
        GoodsReceiptLine(productId: 'p-08', expectedQuantity: 12),
      ],
      note: 'ThinkPad stoğu tükendi, öncelikli karşılanacak.',
    ),

    // --- Tamamlanmış kayıtlar: stok bunları zaten içeriyor ---
    GoodsReceipt(
      id: 'gr-1022',
      code: 'GR-1022',
      supplierName: 'Anker Türkiye',
      status: ReceiptStatus.completed,
      expectedDate: now.subtract(const Duration(days: 2)),
      completedAt: now.subtract(const Duration(days: 2, hours: 3)),
      lines: const <GoodsReceiptLine>[
        GoodsReceiptLine(
          productId: 'p-12',
          expectedQuantity: 60,
          receivedQuantity: 60,
          targetLocationId: 'loc-c0201',
        ),
      ],
    ),
    GoodsReceipt(
      id: 'gr-1023',
      code: 'GR-1023',
      supplierName: 'Logitech Dağıtım',
      status: ReceiptStatus.completed,
      expectedDate: now.subtract(const Duration(days: 1)),
      completedAt: now.subtract(const Duration(days: 1, hours: 2)),
      lines: const <GoodsReceiptLine>[
        GoodsReceiptLine(
          productId: 'p-11',
          expectedQuantity: 30,
          receivedQuantity: 30,
          targetLocationId: 'loc-c0102',
        ),
      ],
    ),
  ];
}
