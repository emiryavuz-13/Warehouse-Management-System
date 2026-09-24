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
