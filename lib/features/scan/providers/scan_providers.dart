/// Barkod tarama modülünün durumu ve veri kaynakları (şartname 10. bölüm).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';

/// Kamera önizlemesinin kullanılabileceği platformlar.
///
/// Şartname 10. bölüm *"gerçek kamera çalışmıyorsa demo seçenekleri
/// bulunabilir"* diyor. Bu sağlayıcı o kararın tek noktası: masaüstünde ve
/// web'de kamera hiç denenmez, ekran doğrudan demo listesine düşer.
///
/// Testlerde `false` ile geçersiz kılınır — widget testinde gerçek kamera
/// kanalı yoktur ve denemek testi platform hatasıyla düşürür.
final Provider<bool> cameraSupportedProvider = Provider<bool>((Ref ref) {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
});

/// Şartname 10. bölümdeki demo barkodları, eşleştikleri ürünlerle birlikte.
///
/// Etiketler elle yazılmaz, mock veritabanından okunur: barkod listesi ile
/// ürün adları birbirinden bağımsız yazılsaydı biri değiştiğinde diğeri
/// sessizce yanlış kalırdı.
final FutureProvider<List<ScanResult>> demoBarcodesProvider =
    FutureProvider<List<ScanResult>>((Ref ref) async {
      ref.watch(dataRevisionProvider);
      final ProductRepository repository = ref.watch(
        productRepositoryProvider,
      );

      return <ScanResult>[
        for (final String barcode in DemoBarcodes.featured)
          await repository.scanBarcode(barcode),
      ];
    });

/// Tek bir barkodun tarama sonucu (şartname 10. bölüm).
///
/// Sonuç ekranı bunu izler; bir transfer yapıldıktan sonra geri dönüldüğünde
/// stok miktarı güncel görünür.
final scanResultProvider = FutureProvider.family<ScanResult, String>((
  Ref ref,
  String barcode,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(productRepositoryProvider).scanBarcode(barcode);
});
