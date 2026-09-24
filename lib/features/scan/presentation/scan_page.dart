import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../providers/scan_providers.dart';
import 'widgets/camera_view.dart';
import 'widgets/demo_barcode_panel.dart';

/// Barkod tarama ekranı (şartname 10. bölüm).
///
/// Ekran ikiye bölünür: üstte kamera, altta demo barkodlar. Demo listesini
/// yalnızca kamera bozulduğunda göstermek cazip görünüyordu ama demo bir
/// emülatörde sunulacak; ikisinin aynı anda durması, kameranın çalışıp
/// çalışmadığına bakmadan ilerleyebilmek demektir.
///
/// **Kamera yalnızca sekme görünürken çalışır.** `StatefulShellRoute`
/// sekmeleri `IndexedStack` içinde canlı tutar; önlem almasak kullanıcı
/// Siparişler sekmesindeyken kamera arka planda açık kalırdı. Sekmenin
/// görünürlüğü `TickerMode` üzerinden okunur — go_router etkin olmayan dalı
/// zaten `TickerMode(enabled: false)` ile sarmalıyor.
class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool cameraSupported = ref.watch(cameraSupportedProvider);
    final bool isVisible = TickerMode.valuesOf(context).enabled;
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: AppBar(title: const Text('Barkod Tara')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: cameraSupported
                  ? CameraView(
                      isActive: isVisible,
                      onDetect: (String barcode) =>
                          _openResult(context, barcode),
                    )
                  : const CameraUnavailableView(
                      title: 'Kamera bu cihazda yok',
                      message:
                          'Aşağıdaki demo barkodlardan birini seçerek '
                          'taramayı deneyebilirsiniz.',
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              cameraSupported
                  ? 'Barkodu çerçeveye alın'
                  : 'Bir demo barkod seçin',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
          Divider(height: 1, color: status.border),
          Expanded(
            child: DemoBarcodePanel(
              onSelected: (String barcode) => _openResult(context, barcode),
            ),
          ),
        ],
      ),
    );
  }

  /// Kameradan da listeden de aynı yol kullanılır: sonuç ekranı kodun
  /// nereden geldiğini bilmez (şartname 10. bölüm).
  void _openResult(BuildContext context, String barcode) {
    context.push(AppRoutes.scanResult(barcode));
  }
}
