/// Dashboard'un veri kaynakları (şartname 7. bölüm).
///
/// Hepsi [dataRevisionProvider]'ı izler: kullanıcı bir transfer yapıp geri
/// döndüğünde özet kartları, son hareketler ve kritik stok listesi
/// kendiliğinden güncel gelir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/views.dart';

/// Üst bölümdeki özet metrikleri.
final FutureProvider<DashboardSummary> dashboardSummaryProvider =
    FutureProvider<DashboardSummary>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(movementRepositoryProvider).getDashboardSummary();
    });

/// "Son Hareketler" bölümü.
final FutureProvider<List<MovementDetail>> recentMovementsProvider =
    FutureProvider<List<MovementDetail>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref
          .watch(movementRepositoryProvider)
          .getRecentMovements(limit: AppConstants.dashboardRecentMovementCount);
    });

/// "Kritik Stok" bölümü — tükenenler en üstte.
final FutureProvider<List<ProductStockSummary>> criticalProductsProvider =
    FutureProvider<List<ProductStockSummary>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref
          .watch(productRepositoryProvider)
          .getCriticalProducts(limit: AppConstants.dashboardCriticalStockCount);
    });

/// Hero figürünün trend çubuklarını besleyen son 7 günlük hareket verisi
/// (şartname 22. bölüm).
///
/// Özet metriklerinden ayrı bir sağlayıcı: hero'nun sayısı hazır olduğunda
/// gösterilebilir, trend biraz sonra gelse de ekran bekletilmez.
final FutureProvider<List<DailyMovementPoint>> dailyMovementsProvider =
    FutureProvider<List<DailyMovementPoint>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref
          .watch(movementRepositoryProvider)
          .getDailyMovements(days: AppConstants.reportDayRange);
    });
