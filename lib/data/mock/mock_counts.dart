import '../../models/models.dart';

/// Sayım kayıtları — 4 kayıt, üç durumun hepsi temsil edilir.
///
/// `IC-2026-031` Demo 5'in başlangıcıdır: A-01-01 lokasyonu sayılıyor, hiçbir
/// satır henüz girilmemiş. Kullanıcı iPhone 15 için 18 yerine 17 girdiğinde
/// fark −1 çıkar ve onayladığında stok gerçekten 17'ye düşer.
///
/// Not: Sayım **lokasyon bazlıdır**, ürünün tüm depodaki toplamı üzerinden
/// değil. Bu yüzden A-01-01 sayımında iPhone 15'in sistem miktarı 24 değil,
/// o raftaki 18'dir. Gerçek depo sayımı da böyle yapılır — sayan kişi tek bir
/// rafın önünde durur.
///
/// Tamamlanmış sayımlarda girilen miktar mevcut stokla birebir örtüşür;
/// çünkü sayım onaylandığında stok o değere çekilmiştir.
abstract final class MockInventoryCounts {
  static List<InventoryCount> build(DateTime now) => <InventoryCount>[
    // --- Devam Ediyor: Demo 5'in başlangıcı ---
    InventoryCount(
      id: 'ic-031',
      code: 'IC-2026-031',
      locationId: 'loc-a0101',
      status: CountStatus.inProgress,
      assignedUserId: 'usr-01',
      createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
      lines: const <InventoryCountLine>[
        InventoryCountLine(productId: 'p-01', systemQuantity: 18),
        InventoryCountLine(productId: 'p-02', systemQuantity: 12),
      ],
    ),

    // --- Bekliyor: henüz başlanmamış ---
    InventoryCount(
      id: 'ic-032',
      code: 'IC-2026-032',
      locationId: 'loc-b0101',
      status: CountStatus.pending,
      assignedUserId: 'usr-02',
      createdAt: now.subtract(const Duration(minutes: 40)),
      lines: const <InventoryCountLine>[
        InventoryCountLine(productId: 'p-05', systemQuantity: 9),
        InventoryCountLine(productId: 'p-06', systemQuantity: 2),
      ],
    ),

    // --- Tamamlandı, fark çıkmış ---
    // K380 klavyeden 2, JBL hoparlörden 1 adet eksik çıktı; stok bu değerlere
    // çekildi ve iki sayım düzeltmesi hareketi oluştu.
    InventoryCount(
      id: 'ic-030',
      code: 'IC-2026-030',
      locationId: 'loc-c0201',
      status: CountStatus.completed,
      assignedUserId: 'usr-01',
      createdAt: now.subtract(const Duration(hours: 7)),
      completedAt: now.subtract(const Duration(hours: 6, minutes: 30)),
      lines: const <InventoryCountLine>[
        InventoryCountLine(
          productId: 'p-11',
          systemQuantity: 8,
          countedQuantity: 6,
        ),
        InventoryCountLine(
          productId: 'p-12',
          systemQuantity: 48,
          countedQuantity: 48,
        ),
        InventoryCountLine(
          productId: 'p-15',
          systemQuantity: 20,
          countedQuantity: 19,
        ),
      ],
    ),

    // --- Tamamlandı, fark yok ---
    InventoryCount(
      id: 'ic-029',
      code: 'IC-2026-029',
      locationId: 'loc-c0101',
      status: CountStatus.completed,
      assignedUserId: 'usr-02',
      createdAt: now.subtract(const Duration(days: 1, hours: 8)),
      completedAt: now.subtract(const Duration(days: 1, hours: 7)),
      lines: const <InventoryCountLine>[
        InventoryCountLine(
          productId: 'p-09',
          systemQuantity: 85,
          countedQuantity: 85,
        ),
        InventoryCountLine(
          productId: 'p-10',
          systemQuantity: 3,
          countedQuantity: 3,
        ),
        InventoryCountLine(
          productId: 'p-13',
          systemQuantity: 8,
          countedQuantity: 8,
        ),
      ],
    ),
  ];
}
