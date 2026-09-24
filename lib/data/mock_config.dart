import '../core/constants/app_constants.dart';
import 'warehouse_exception.dart';

/// Mock repository'lerin davranışını ayarlar.
///
/// İki işi vardır:
///
/// 1. **Gecikme.** Gerçek bir API çağrısı anında dönmez. Gecikme olmasaydı
///    loading ekranları hiç görünmez, şartname 25. bölümündeki "Loading
///    state" maddesi kâğıt üstünde kalırdı.
///
/// 2. **Hata simülasyonu.** [simulateErrors] açıkken her okuma başarısız
///    olur. Demo sırasında profil ekranındaki anahtarla açılarak error
///    state'lerin gerçekten çalıştığı gösterilebilir.
class MockConfig {
  MockConfig({
    this.simulateErrors = false,
    this.readLatency = AppConstants.mockLatency,
    this.longReadLatency = AppConstants.mockLatencyLong,
    this.writeLatency = AppConstants.mockWriteLatency,
  });

  /// Gecikmesiz ve hatasız yapılandırma — testler için.
  ///
  /// Testlerde her çağrıda yarım saniye beklemek anlamsızdır ve test
  /// süresini gereksiz uzatır.
  factory MockConfig.instant() => MockConfig(
    readLatency: Duration.zero,
    longReadLatency: Duration.zero,
    writeLatency: Duration.zero,
  );

  /// Açıkken tüm okuma işlemleri [WarehouseException.simulatedFailure] ile
  /// başarısız olur. Yazma işlemleri etkilenmez — demo sırasında kullanıcı
  /// yaptığı transferi kaybetmesin.
  bool simulateErrors;

  Duration readLatency;
  Duration longReadLatency;
  Duration writeLatency;

  /// Okuma çağrılarının başında beklenir; hata simülasyonu açıksa fırlatır.
  Future<void> beforeRead({bool long = false}) async {
    final Duration delay = long ? longReadLatency : readLatency;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (simulateErrors) {
      throw WarehouseException.simulatedFailure();
    }
  }

  /// Yazma çağrılarının başında beklenir.
  ///
  /// İş kuralı doğrulaması gecikmeden **sonra** çalışır; böylece kullanıcı
  /// onay butonuna bastığında önce yükleniyor durumunu, sonra sonucu görür.
  Future<void> beforeWrite() async {
    if (writeLatency > Duration.zero) {
      await Future<void>.delayed(writeLatency);
    }
  }
}
