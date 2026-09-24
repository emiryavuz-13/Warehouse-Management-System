/// Birden fazla ekranın paylaştığı okuma provider'ları.
///
/// Modüle özgü provider'lar kendi feature klasörlerinde yaşar; burada
/// yalnızca her yerde gereken veriler bulunur.
///
/// Hepsi [dataRevisionProvider]'ı izler: bir transfer veya kabul sonrası
/// kendiliğinden yenilenirler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/views.dart';
import '../../models/models.dart';
import 'data_revision.dart';
import 'repository_providers.dart';

/// Oturum açmış kullanıcı (şartname 21. bölüm).
final FutureProvider<AppUser> currentUserProvider = FutureProvider<AppUser>((
  Ref ref,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(warehouseRepositoryProvider).getCurrentUser();
});

/// Kullanıcının bağlı olduğu depo.
final FutureProvider<Warehouse?> currentWarehouseProvider =
    FutureProvider<Warehouse?>((Ref ref) async {
      ref.watch(dataRevisionProvider);
      final AppUser user = await ref.watch(currentUserProvider.future);
      final List<Warehouse> all = await ref
          .watch(warehouseRepositoryProvider)
          .getWarehouses();
      for (final Warehouse warehouse in all) {
        if (warehouse.id == user.warehouseId) return warehouse;
      }
      return all.isEmpty ? null : all.first;
    });

/// Ürün kategorileri — filtre panellerinde kullanılır.
final FutureProvider<List<ProductCategory>> categoriesProvider =
    FutureProvider<List<ProductCategory>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(productRepositoryProvider).getCategories();
    });

/// Tüm lokasyonlar, doluluk bilgisiyle (şartname 18. bölüm).
final FutureProvider<List<LocationSummary>> locationsProvider =
    FutureProvider<List<LocationSummary>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(warehouseRepositoryProvider).getLocations();
    });

/// Okunmamış bildirim sayısı — bottom bar ve dashboard rozetleri.
final FutureProvider<int> unreadNotificationCountProvider = FutureProvider<int>(
  (Ref ref) {
    ref.watch(dataRevisionProvider);
    return ref.watch(warehouseRepositoryProvider).getUnreadNotificationCount();
  },
);

/// Bildirim listesi (şartname 20. bölüm).
final FutureProvider<List<AppNotification>> notificationsProvider =
    FutureProvider<List<AppNotification>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(warehouseRepositoryProvider).getNotifications();
    });

/// Tek bir ürünün stok özeti — ürün detayı, tarama sonucu ve transfer
/// ekranlarının ortak ihtiyacı.
// Family provider'larda tip çıkarımı kullanılır: FutureProviderFamily sınıfı
// flutter_riverpod'dan dışa aktarılmıyor, generic argümanlar zaten
// FutureProvider.family çağrısında açıkça belirtiliyor.
final productSummaryProvider =
    FutureProvider.family<ProductStockSummary?, String>((
      Ref ref,
      String productId,
    ) {
      ref.watch(dataRevisionProvider);
      return ref.watch(productRepositoryProvider).getProductById(productId);
    });
