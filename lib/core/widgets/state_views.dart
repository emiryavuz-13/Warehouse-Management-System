import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../data/warehouse_exception.dart';
import 'app_buttons.dart';

/// Boş, hata ve yükleniyor durumlarının ortak iskeleti (şartname 25. bölüm).
///
/// Üçü de aynı düzeni kullanır: ikon kutusu, başlık, açıklama, isteğe bağlı
/// eylem. Tek fark renk ve içeriktir. Ayrı ayrı yazılsalardı hizalamaları ve
/// boşlukları zamanla birbirinden ayrışırdı.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.iconColor,
    required this.iconBackground,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color iconColor;
  final Color iconBackground;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: status.neutral),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Veri yokken gösterilir (şartname 25. bölüm: "Henüz sipariş bulunmuyor").
///
/// Boş liste ile "arama sonuç vermedi" farklı durumlardır ve farklı mesaj
/// gerektirir; ikincisi için [EmptyState.noResults] kullanılır.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.title = 'Kayıt bulunamadı',
    this.icon = AppIcons.empty,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Arama veya filtre sonucu boş kaldığında.
  ///
  /// Kullanıcıya "veri yok" demek yanıltıcı olur — veri var, filtresi
  /// eşleşmedi. Filtreyi temizleme eylemi de burada sunulur.
  factory EmptyState.noResults({
    String? query,
    VoidCallback? onClear,
    Key? key,
  }) {
    return EmptyState(
      key: key,
      icon: AppIcons.noResults,
      title: 'Sonuç bulunamadı',
      message: query == null || query.isEmpty
          ? 'Seçtiğiniz filtrelere uyan kayıt yok.'
          : '"$query" için eşleşen kayıt yok.',
      actionLabel: onClear == null ? null : 'Filtreleri temizle',
      onAction: onClear,
    );
  }

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return _CenteredMessage(
      icon: icon,
      title: title,
      message: message,
      iconColor: status.neutral,
      iconBackground: status.neutralContainer,
      action: actionLabel == null
          ? null
          : SecondaryButton(label: actionLabel!, onPressed: onAction),
    );
  }
}

/// Hata durumu (şartname 25. bölüm).
///
/// İş kuralı hataları (`WarehouseException`) kullanıcıya yazdıkları mesajla
/// gösterilir — bu mesajlar zaten Türkçe ve somuttur. Beklenmeyen hatalarda
/// teknik ayrıntı gösterilmez; kullanıcının yapabileceği tek şey yeniden
/// denemektir.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Ekranın tamamı değil, bir bölümü başarısız olduğunda kullanılır.
  ///
  /// Dashboard gibi birden çok bölümü olan ekranlarda her bölüm kendi
  /// hatasını tam boy gösterirse aynı mesaj ekranda iki üç kez, kocaman
  /// tekrarlanıyor ve sayfanın geri kalanı (çalışan kısımlar) görünmez
  /// hale geliyordu. Kompakt hal tek satır + küçük bir "tekrar dene".
  final bool compact;

  /// Hatanın kullanıcıya gösterilecek hali.
  static String describe(Object error) {
    if (error is WarehouseException) return error.message;
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool isSimulated =
        error is WarehouseException &&
        (error as WarehouseException).code ==
            WarehouseErrorCode.simulatedFailure;

    final String title = isSimulated
        ? 'Bağlantı kurulamadı'
        : 'Bir şeyler ters gitti';

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              isSimulated ? AppIcons.offline : AppIcons.error,
              size: AppSizes.iconMd,
              color: status.danger,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.danger),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Tekrar dene'),
              ),
          ],
        ),
      );
    }

    return _CenteredMessage(
      icon: isSimulated ? AppIcons.offline : AppIcons.error,
      title: title,
      message: describe(error),
      iconColor: status.danger,
      iconBackground: status.dangerContainer,
      action: onRetry == null
          ? null
          : PrimaryButton(
              label: 'Tekrar dene',
              icon: AppIcons.refresh,
              onPressed: onRetry,
            ),
    );
  }
}

/// Yükleniyor durumu (şartname 25. bölüm).
///
/// Dönen çember yerine **iskelet** gösterir: kullanıcı verinin nasıl
/// görüneceğini önceden görür, içerik geldiğinde sayfa zıplamaz.
///
/// [child] olarak gerçek widget ağacının sahte veriyle doldurulmuş hali
/// verilir; `skeletonizer` onu otomatik olarak gri kemiklere çevirir. Her
/// ekran için ayrı bir iskelet tasarlamak gerekmez.
class LoadingState extends StatelessWidget {
  const LoadingState({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Skeletonizer(
      enabled: enabled,
      effect: ShimmerEffect(
        baseColor: status.neutralContainer,
        highlightColor: Theme.of(context).colorScheme.surface,
        duration: const Duration(milliseconds: 1100),
      ),
      child: child,
    );
  }
}

/// İskelet gösterimi için sahte liste üretir.
///
/// `List.generate` ile aynı kartı tekrarlamak yerine buradan geçilir, böylece
/// iskelet eleman sayısı tüm ekranlarda tutarlı olur.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    required this.itemBuilder,
    this.itemCount = 6,
    this.padding = AppSpacing.listPadding,
    this.separator = AppSpacing.md,
    super.key,
  });

  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final double separator;

  @override
  Widget build(BuildContext context) {
    return LoadingState(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(height: separator),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Basit dönen gösterge — iskelet çizmenin anlamlı olmadığı yerlerde
/// (tam ekran işlem onayı, küçük gömülü alanlar).
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: status.neutral),
            ),
          ],
        ],
      ),
    );
  }
}
