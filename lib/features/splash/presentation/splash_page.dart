import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Açılış ekranı (şartname 28. bölüm, 1. ekran).
///
/// İki iş yapar: dashboard'un ihtiyaç duyduğu veriyi önceden yükler ve
/// kullanıcıya uygulamanın açıldığını gösterir. Ön yükleme sayesinde
/// dashboard'a geçildiğinde kartlar boş değil dolu gelir.
///
/// Ön yükleme beklenenden hızlı biterse de ekran kısa bir süre görünür
/// kalır; anlık geçiş "bir şey yanıp söndü" hissi verir.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  /// Logonun ekranda kalacağı en kısa süre.
  static const Duration _minimumDisplay = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final Stopwatch watch = Stopwatch()..start();

    try {
      // Dashboard'un ilk çizimde ihtiyaç duyacağı veriler.
      await Future.wait<void>(<Future<void>>[
        ref.read(currentUserProvider.future),
        ref.read(unreadNotificationCountProvider.future),
      ]);
    } on Object {
      // Ön yükleme başarısız olsa bile uygulamaya girilir; ilgili ekran
      // kendi hata durumunu gösterir ve kullanıcı yeniden deneyebilir.
    }

    final Duration elapsed = watch.elapsed;
    if (elapsed < _minimumDisplay) {
      await Future<void>.delayed(_minimumDisplay - elapsed);
    }

    if (!mounted) return;
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                AppIcons.locations,
                size: 44,
                color: colors.onPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Depo Yönetim Sistemi',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: status.neutral),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
