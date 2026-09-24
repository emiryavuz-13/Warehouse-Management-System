import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state_views.dart';

/// Bir [AsyncValue]'yu dört duruma göre çizer: yükleniyor, hata, boş, veri.
///
/// **Çözdüğü sorun:** şartname 25. bölüm her ekranın loading/empty/error/
/// success durumlarını ele almasını istiyor. Bu, her ekranda tekrar eden
/// yirmi satırlık bir `when(...)` bloğu demek. Ekran sayısı arttıkça
/// bazılarında boş durum unutulur, bazılarında hata metni farklı yazılır.
///
/// Burada toplandığı için tüm ekranlar aynı davranışı ücretsiz alır ve yeni
/// bir ekran yazmak tek satıra iner.
///
/// **Yenileme sırasında eski veri korunur.** Kullanıcı bir transfer
/// yaptığında `dataRevisionProvider` tüm listeleri tazeler; bu sırada ekranın
/// iskelete dönmesi göz yorucu olur ve kaydırma konumu kaybolur. Eski veri
/// ekranda kalır, yenisi gelince yerini alır.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.isEmpty,
    this.empty,
    super.key,
  });

  final AsyncValue<T> value;

  /// Veri geldiğinde çizilecek içerik.
  final Widget Function(T data) data;

  /// Hata ekranındaki "Tekrar dene" butonuna bağlanır.
  ///
  /// Genellikle `() => ref.invalidate(ilgiliProvider)` geçilir.
  final VoidCallback? onRetry;

  /// Yükleniyor durumunda çizilecek iskelet. Verilmezse dönen gösterge.
  final Widget? loading;

  /// Gelen verinin "boş" sayılıp sayılmayacağını belirler.
  ///
  /// Liste için `(items) => items.isEmpty` geçilir. Verilmezse boş durum
  /// hiç gösterilmez.
  final bool Function(T data)? isEmpty;

  /// Boş durumda çizilecek içerik.
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      // Veri sürümü sayacı arttığında provider "reload" olur. Varsayılan
      // davranışta ekran her transfer sonrası iskelete döner; bu hem göz
      // yorucu hem de kaydırma konumunu kaybettirir. Eski veri ekranda
      // kalır, yenisi hazır olunca yerini alır.
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: _buildData,
      error: (Object error, StackTrace _) =>
          ErrorState(error: error, onRetry: onRetry),
      loading: () => loading ?? const LoadingIndicator(),
    );
  }

  Widget _buildData(T resolved) {
    if (isEmpty != null && isEmpty!(resolved)) {
      return empty ?? const EmptyState(message: 'Gösterilecek kayıt yok.');
    }
    return data(resolved);
  }
}

/// Aşağı çekerek yenileme sarmalayıcısı (şartname 33. bölüm).
///
/// Yenileme her zaman [WarehouseActions.refreshAll] üzerinden yapılır;
/// böylece tek bir ekranın değil tüm verinin tazelenmesi sağlanır ve
/// kullanıcı hangi ekranda çektiğine bakmaksızın aynı sonucu alır.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: 0,
      displacement: 24,
      child: child,
    );
  }
}
