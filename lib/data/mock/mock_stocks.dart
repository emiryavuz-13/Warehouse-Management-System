import '../../models/models.dart';

/// Lokasyon bazlı stok kayıtları — 26 kayıt, 15 ürün, 13 lokasyon.
///
/// Dağılım rastgele değildir, üç amacı vardır:
///
/// 1. **Üç stok durumu da görünür olmalı** (şartname 23. bölüm):
///    - Stok Yok  → Lenovo ThinkPad E14
///    - Kritik    → Galaxy S24, MacBook Pro M3, MX Master 3S, Sony WH-1000XM5
///    - Normal    → kalan 10 ürün
///
/// 2. **Çok lokasyonlu ürünler bulunmalı.** iPhone 15 şartname 8. bölümündeki
///    örnekle birebir aynıdır: A-01-01 → 18, B-03-02 → 6, toplam 24.
///
/// 3. **Picking görevlerinin kaynak lokasyonlarında yeterli stok olmalı.**
///    Aksi halde demo sırasında toplama işlemi "yetersiz stok" hatası verirdi.
abstract final class MockStocks {
  static const List<Stock> all = <Stock>[
    // --- iPhone 15: şartnamedeki örnek dağılım, toplam 24 ---
    Stock(id: 'stk-01', productId: 'p-01', locationId: 'loc-a0101', quantity: 18),
    Stock(id: 'stk-02', productId: 'p-01', locationId: 'loc-b0302', quantity: 6),

    // --- iPhone 15 Pro: toplam 16, Normal ---
    Stock(id: 'stk-03', productId: 'p-02', locationId: 'loc-a0101', quantity: 12),
    Stock(id: 'stk-04', productId: 'p-02', locationId: 'loc-a0102', quantity: 4),

    // --- Galaxy S24: 7 adet, minimum 8 → Kritik ---
    Stock(id: 'stk-05', productId: 'p-03', locationId: 'loc-a0102', quantity: 7),

    // --- iPad Air: iki depoya dağılmış ---
    Stock(id: 'stk-06', productId: 'p-04', locationId: 'loc-a0201', quantity: 14),
    Stock(id: 'stk-07', productId: 'p-04', locationId: 'loc-d0101', quantity: 3),

    // --- MacBook Air M3: iki depoya dağılmış ---
    Stock(id: 'stk-08', productId: 'p-05', locationId: 'loc-b0101', quantity: 9),
    Stock(id: 'stk-09', productId: 'p-05', locationId: 'loc-d0101', quantity: 4),

    // --- MacBook Pro M3: 2 adet, minimum 3 → Kritik ---
    Stock(id: 'stk-11', productId: 'p-06', locationId: 'loc-b0101', quantity: 2),

    // --- Dell XPS 13 ---
    Stock(id: 'stk-12', productId: 'p-07', locationId: 'loc-b0102', quantity: 11),
    Stock(id: 'stk-13', productId: 'p-07', locationId: 'loc-b0201', quantity: 2),

    // --- Lenovo ThinkPad E14: 0 adet → Stok Yok ---
    // Kayıt bilerek silinmedi: lokasyon detayında "bu rafta bu ürün var ama
    // tükenmiş" bilgisi korunur.
    Stock(id: 'stk-14', productId: 'p-08', locationId: 'loc-b0201', quantity: 0),

    // --- USB-C Kablo: en yüksek stoklu ürün, toplam 125 ---
    // B-01-02'deki miktar şartname 14. bölümündeki picking örneğine dayanır.
    Stock(id: 'stk-15', productId: 'p-09', locationId: 'loc-c0101', quantity: 85),
    Stock(id: 'stk-16', productId: 'p-09', locationId: 'loc-b0102', quantity: 40),

    // --- MX Master 3S: 3 adet, minimum 10 → Kritik (bildirim örneği) ---
    Stock(id: 'stk-17', productId: 'p-10', locationId: 'loc-c0101', quantity: 3),

    // --- Logitech K380 ---
    Stock(id: 'stk-18', productId: 'p-11', locationId: 'loc-c0102', quantity: 22),
    Stock(id: 'stk-19', productId: 'p-11', locationId: 'loc-c0201', quantity: 6),

    // --- Anker PowerBank ---
    Stock(id: 'stk-20', productId: 'p-12', locationId: 'loc-c0201', quantity: 48),
    Stock(id: 'stk-21', productId: 'p-12', locationId: 'loc-d0102', quantity: 12),

    // --- AirPods Pro 2 ---
    Stock(id: 'stk-22', productId: 'p-13', locationId: 'loc-a0201', quantity: 31),
    Stock(id: 'stk-23', productId: 'p-13', locationId: 'loc-c0101', quantity: 8),

    // --- Sony WH-1000XM5: 5 adet, minimum 6 → Kritik ---
    Stock(id: 'stk-24', productId: 'p-14', locationId: 'loc-b0201', quantity: 5),

    // --- JBL Flip 6 ---
    Stock(id: 'stk-25', productId: 'p-15', locationId: 'loc-c0201', quantity: 19),
    Stock(id: 'stk-26', productId: 'p-15', locationId: 'loc-d0102', quantity: 5),

    // --- Mal kabul alanında yerleştirme bekleyen mal ---
    // GR-1025 ile 120 adet kablo kabul edildi ama henüz rafa kaldırılmadı.
    // Putaway ekranı (şartname 12. bölüm) tam olarak bu kaydı işler.
    Stock(id: 'stk-27', productId: 'p-09', locationId: 'loc-m01', quantity: 120),
  ];
}
