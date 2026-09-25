/// Veri katmanının bağlandığı yer.
///
/// Şartname 36. bölüm: gerçek API'ye geçildiğinde **yalnızca bu dosya**
/// değişir. `MockProductRepository` yerine `ApiProductRepository` yazılır;
/// ekranlar ve provider'lar `ProductRepository` arayüzünü gördüğü için hiç
/// dokunulmaz.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_data.dart';
import '../../data/mock_config.dart';
import '../../data/repositories/repositories.dart';
import '../../data/warehouse_database.dart';
import 'data_revision.dart';

/// Mock servis ayarları: gecikme süreleri ve hata simülasyonu.
final Provider<MockConfig> mockConfigProvider = Provider<MockConfig>(
  (Ref ref) => MockConfig(),
);

/// Uygulamanın tek veri kaynağı.
///
/// Oturum boyunca yaşar; kullanıcının yaptığı transferler, kabuller ve
/// sayımlar burada birikir. Uygulama yeniden başlatıldığında temiz demo
/// senaryosuna dönülür.
final Provider<WarehouseDatabase> warehouseDatabaseProvider =
    Provider<WarehouseDatabase>((Ref ref) => WarehouseDatabase());

/// Oturum açmış kullanıcının kimliği.
///
/// Demo'da gerçek kimlik doğrulama yok; sabit kullanıcı kabul edilir
/// (şartname 21. bölüm). Stok hareketleri bu kullanıcıya yazılır.
final Provider<String> currentUserIdProvider = Provider<String>(
  (Ref ref) => MockUsers.currentUserId,
);

/// Kullanıcının çalıştığı depo.
final Provider<String> currentWarehouseIdProvider = Provider<String>(
  (Ref ref) => MockWarehouses.defaultWarehouseId,
);

// --- Repository'ler ---

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>(
      (Ref ref) => MockProductRepository(
        ref.watch(warehouseDatabaseProvider),
        ref.watch(mockConfigProvider),
      ),
    );

final Provider<StockRepository> stockRepositoryProvider =
    Provider<StockRepository>(
      (Ref ref) => MockStockRepository(
        ref.watch(warehouseDatabaseProvider),
        ref.watch(mockConfigProvider),
      ),
    );

final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>(
      (Ref ref) => MockOrderRepository(
        ref.watch(warehouseDatabaseProvider),
        ref.watch(mockConfigProvider),
      ),
    );

final Provider<WarehouseRepository> warehouseRepositoryProvider =
    Provider<WarehouseRepository>(
      (Ref ref) => MockWarehouseRepository(
        ref.watch(warehouseDatabaseProvider),
        ref.watch(mockConfigProvider),
        ref.watch(currentUserIdProvider),
      ),
    );

final Provider<MovementRepository> movementRepositoryProvider =
    Provider<MovementRepository>(
      (Ref ref) => MockMovementRepository(
        ref.watch(warehouseDatabaseProvider),
        ref.watch(mockConfigProvider),
      ),
    );

/// Hata simülasyonu anahtarı (şartname 25. bölüm).
///
/// Arayüzde bir düğmesi yok: demo sırasında yanlışlıkla açılıp ekranların
/// hata vermesi, anlatılmak istenen şeyi gölgeliyordu. Mekanizma duruyor —
/// hata ekranları testlerden bu anahtarla sürülüyor.
///
/// Profil ekranından açılır. Açıkken tüm okuma işlemleri başarısız olur ve
/// ekranların error durumları demo sırasında gösterilebilir. Yazma işlemleri
/// etkilenmez — kullanıcı yaptığı transferi kaybetmemeli.
class ErrorSimulation extends Notifier<bool> {
  @override
  bool build() => ref.read(mockConfigProvider).simulateErrors;

  void set(bool value) {
    if (value == state) return;
    state = value;
    // MockConfig düz bir nesne olduğu için değişikliği kendisi duyuramaz;
    // ekranların yeniden okuması için veri sürümü artırılır.
    ref.read(mockConfigProvider).simulateErrors = value;
    ref.read(dataRevisionProvider.notifier).bump();
  }

  void toggle() => set(!state);
}

final NotifierProvider<ErrorSimulation, bool> errorSimulationProvider =
    NotifierProvider<ErrorSimulation, bool>(ErrorSimulation.new);
