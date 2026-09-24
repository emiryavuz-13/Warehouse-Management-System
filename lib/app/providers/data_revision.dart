import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Veri sürümü sayacı — uygulamanın yenilenme mekanizması.
///
/// **Çözdüğü sorun:** kullanıcı bir transfer yaptığında yalnızca transfer
/// ekranı değil, dashboard özeti, ürün detayı, stok listesi, lokasyon
/// doluluğu ve hareket geçmişi de değişir. Bu ekranları elle `invalidate`
/// etmek, yeni bir ekran eklendiğinde birini unutmak demektir — ve unutulan
/// ekran sessizce eski veriyi göstermeye devam eder.
///
/// **Çözüm:** tüm okuma provider'ları bu sayacı izler:
///
/// ```dart
/// final productsProvider = FutureProvider((ref) {
///   ref.watch(dataRevisionProvider);   // ← yenilenme aboneliği
///   return ref.watch(productRepositoryProvider).getProducts();
/// });
/// ```
///
/// Her yazma işleminden sonra sayaç bir artar ve **tüm** okuma provider'ları
/// kendiliğinden yeniden çalışır. Yeni bir ekran eklendiğinde tek yapılması
/// gereken bu satırı yazmaktır; hangi işlemin onu etkilediğini bilmek
/// gerekmez.
///
/// Sayacı artırma işi [WarehouseActions] sınıfına bırakılmıştır; böylece
/// yazma yapan her yerde tek tek hatırlanması gerekmez.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  /// Veride değişiklik olduğunu bildirir.
  void bump() => state = state + 1;
}

/// Kaçıncı veri sürümünde olduğumuz. Değeri anlamlı değildir, yalnızca
/// değişmesi önemlidir.
final NotifierProvider<DataRevision, int> dataRevisionProvider =
    NotifierProvider<DataRevision, int>(DataRevision.new);
