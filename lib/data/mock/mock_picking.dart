import '../../models/models.dart';

/// Toplama görevleri — 6 görev.
///
/// Her satırın kaynak lokasyonunda **yeterli stok bulunduğu doğrulanmıştır**
/// (bkz. `test/mock_data_test.dart`). Aksi halde demo sırasında toplama
/// işlemi "yetersiz stok" hatasıyla durur, bu da tam senaryo ortasında
/// sunumu bozardı.
///
/// Yeni durumdaki siparişlerin (#10453, #10454, #10460) görevi yoktur —
/// kullanıcı "Siparişi Topla" dediğinde uygulama görevi kendisi oluşturur.
/// Demo 3 tam olarak bu akışı gösterir.
abstract final class MockPickingTasks {
  static List<PickingTask> build(DateTime now) => <PickingTask>[
    // --- Devam eden: demo senaryosunun ana görevi (#10452) ---
    // Şartname 14. bölümündeki üç adımlı örneğin birebir karşılığı.
    PickingTask(
      id: 'pk-102',
      code: 'PK-102',
      orderId: 'ord-10452',
      status: PickingStatus.inProgress,
      assignedUserId: 'usr-01',
      createdAt: now.subtract(const Duration(hours: 5, minutes: 40)),
      lines: const <PickingLine>[
        PickingLine(
          productId: 'p-01',
          locationId: 'loc-a0101',
          requestedQuantity: 2,
        ),
        PickingLine(
          productId: 'p-09',
          locationId: 'loc-b0102',
          requestedQuantity: 5,
        ),
        PickingLine(
          productId: 'p-10',
          locationId: 'loc-c0101',
          requestedQuantity: 1,
        ),
      ],
    ),

    // --- Devam eden: ilk satırı bitmiş, ikinci satırı bekliyor ---
    PickingTask(
      id: 'pk-107',
      code: 'PK-107',
      orderId: 'ord-10461',
      status: PickingStatus.inProgress,
      assignedUserId: 'usr-02',
      createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
      lines: const <PickingLine>[
        PickingLine(
          productId: 'p-12',
          locationId: 'loc-c0201',
          requestedQuantity: 10,
          pickedQuantity: 10,
        ),
        PickingLine(
          productId: 'p-11',
          locationId: 'loc-c0102',
          requestedQuantity: 4,
        ),
      ],
    ),

    // --- Tamamlanmış görevler ---
    PickingTask(
      id: 'pk-103',
      code: 'PK-103',
      orderId: 'ord-10455',
      status: PickingStatus.completed,
      assignedUserId: 'usr-01',
      createdAt: now.subtract(const Duration(days: 1, hours: 1)),
      completedAt: now.subtract(const Duration(hours: 22)),
      lines: const <PickingLine>[
        PickingLine(
          productId: 'p-02',
          locationId: 'loc-a0101',
          requestedQuantity: 3,
          pickedQuantity: 3,
        ),
        PickingLine(
          productId: 'p-12',
          locationId: 'loc-c0201',
          requestedQuantity: 6,
          pickedQuantity: 6,
        ),
      ],
    ),
    PickingTask(
      id: 'pk-104',
      code: 'PK-104',
      orderId: 'ord-10456',
      status: PickingStatus.completed,
      assignedUserId: 'usr-02',
      createdAt: now.subtract(const Duration(days: 1, hours: 4)),
      completedAt: now.subtract(const Duration(days: 1, hours: 3)),
      lines: const <PickingLine>[
        PickingLine(
          productId: 'p-05',
          locationId: 'loc-b0101',
          requestedQuantity: 2,
          pickedQuantity: 2,
        ),
      ],
    ),
    PickingTask(
      id: 'pk-105',
      code: 'PK-105',
      orderId: 'ord-10457',
      status: PickingStatus.completed,
      assignedUserId: 'usr-01',
      createdAt: now.subtract(const Duration(days: 2, hours: 2)),
      completedAt: now.subtract(const Duration(days: 1, hours: 20)),
      lines: const <PickingLine>[
        PickingLine(
          productId: 'p-09',
          locationId: 'loc-c0101',
          requestedQuantity: 20,
          pickedQuantity: 20,
        ),
        PickingLine(
          productId: 'p-15',
          locationId: 'loc-c0201',
          requestedQuantity: 3,
          pickedQuantity: 3,
        ),
      ],
    ),
    PickingTask(
      id: 'pk-106',
      code: 'PK-106',
      orderId: 'ord-10458',
      status: PickingStatus.completed,
      assignedUserId: 'usr-02',
      createdAt: now.subtract(const Duration(days: 3)),
      completedAt: now.subtract(const Duration(days: 2, hours: 20)),
      lines: const <PickingLine>[
        PickingLine(
          productId: 'p-07',
          locationId: 'loc-b0102',
          requestedQuantity: 2,
          pickedQuantity: 2,
        ),
      ],
    ),
  ];
}
