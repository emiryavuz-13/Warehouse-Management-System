import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';
import '../../providers/scan_providers.dart';
import 'camera_view.dart';

/// Barkod doğrulama paneli (şartname 11. ve 14. bölümler).
///
/// Toplama ve yerleştirme ekranlarında **doğru ürünü** elinde tuttuğunu
/// teyit etmek için kullanılır. Bir rafta iPhone 15 ile iPhone 15 Pro yan
/// yana durabilir; kutular benzer, çalışan acelededir. Yanlış ürün ancak
/// müşteri şikâyet edince anlaşılır.
///
/// **Panel, sayfa değil.** Önceki hâlinde "Barkod Tara" düğmesi kullanıcıyı
/// Tara sekmesine gönderiyordu; toplama ekranı yığından düşüyor ve çalışan
/// siparişe elle geri dönmek zorunda kalıyordu. Panel açılıp kapanınca
/// kullanıcı bulunduğu adımda kalır.
///
/// **Doğrulama zorunlu değildir.** Çalışan okutmadan da onaylayabilir; depoda
/// kamera bozuk olabilir ve iş durmamalı. Ama okuttuysa yanlış ürünü almasına
/// izin verilmez.
///
/// Eşleşmede `true` döner; eşleşmezse panel açık kalır ve **hangi ürünü**
/// okuttuğunu söyler — "yanlış" demek yetmez, kullanıcı elindekinin ne
/// olduğunu bilmeli.
class BarcodeVerifySheet extends ConsumerStatefulWidget {
  const BarcodeVerifySheet({required this.expected, super.key});

  /// Okutulması beklenen ürün.
  final Product expected;

  static Future<bool?> show({
    required BuildContext context,
    required Product expected,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) =>
          BarcodeVerifySheet(expected: expected),
    );
  }

  @override
  ConsumerState<BarcodeVerifySheet> createState() =>
      _BarcodeVerifySheetState();
}

class _BarcodeVerifySheetState extends ConsumerState<BarcodeVerifySheet> {
  /// Yanlış okunan son barkodun sonucu; doğru okumada temizlenir.
  ScanResult? _mismatch;
  bool _isChecking = false;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool cameraSupported = ref.watch(cameraSupportedProvider);
    final Product expected = widget.expected;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Barkod Doğrula',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Raftan aldığınız ürünün etiketini okutun.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const SizedBox(height: AppSpacing.md),

                // Beklenen ürün her an görünür: kullanıcı neyi aradığını
                // panelin içinde de görebilmeli.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: status.neutralContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'BEKLENEN ÜRÜN'.toUpperCaseTr(),
                              style: AppTypography.overline.copyWith(
                                color: status.neutral,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              expected.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CodeChip(code: expected.sku),
                    ],
                  ),
                ),

                if (_mismatch != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _MismatchNotice(
                    result: _mismatch!,
                    expected: expected,
                  ),
                ],
              ],
            ),
          ),

          if (cameraSupported)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CameraView(onDetect: _check),
              ),
            ),

          Divider(height: 1, color: status.border),
          Flexible(child: _DemoList(expected: expected, onSelected: _check)),

          BottomActionBar(
            children: <Widget>[
              SecondaryButton(
                label: 'Doğrulamadan Devam Et',
                isLoading: _isChecking,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _check(String barcode) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final ScanResult result = await ref
        .read(productRepositoryProvider)
        .scanBarcode(barcode);
    if (!mounted) return;

    final bool isMatch = result.summary?.product.id == widget.expected.id;
    if (isMatch) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _mismatch = result;
      _isChecking = false;
    });
  }
}

/// Yanlış ürün okunduğunda ne okunduğunu söyleyen şerit.
class _MismatchNotice extends StatelessWidget {
  const _MismatchNotice({required this.result, required this.expected});

  final ScanResult result;
  final Product expected;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Product? scanned = result.summary?.product;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: status.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            StatusTone.danger.icon,
            size: AppSizes.iconSm,
            color: status.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Yanlış ürün',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: status.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scanned == null
                      ? 'Okuttuğunuz ${result.barcode} kayıtlı bir ürüne '
                            'ait değil.'
                      : 'Okuttuğunuz: ${scanned.name}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Doğrulama panelinin demo barkod listesi.
///
/// Beklenen ürünün kendi barkodu **her zaman başta** durur; aksi halde
/// kamerasız bir cihazda doğrulama demosu hiç yapılamazdı. Ardından birkaç
/// başka ürün gelir — yanlış okuma durumunu göstermek için.
class _DemoList extends ConsumerWidget {
  const _DemoList({required this.expected, required this.onSelected});

  final Product expected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final List<ScanResult> demo =
        ref.watch(demoBarcodesProvider).value ?? const <ScanResult>[];

    final List<_DemoEntry> entries = <_DemoEntry>[
      _DemoEntry(
        barcode: expected.barcode,
        name: expected.name,
        isExpected: true,
      ),
      for (final ScanResult result in demo)
        if (result.summary != null &&
            result.summary!.product.id != expected.id)
          _DemoEntry(
            barcode: result.barcode,
            name: result.summary!.product.name,
            isExpected: false,
          ),
    ];

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            'Demo Barkodlar'.toUpperCaseTr(),
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
        ),
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          if (i > 0)
            Divider(height: 1, indent: AppSpacing.lg, color: status.border),
          _DemoRow(entry: entries[i], onTap: () => onSelected(entries[i].barcode)),
        ],
      ],
    );
  }
}

class _DemoEntry {
  const _DemoEntry({
    required this.barcode,
    required this.name,
    required this.isExpected,
  });

  final String barcode;
  final String name;
  final bool isExpected;
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.entry, required this.onTap});

  final _DemoEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              AppIcons.barcode,
              size: AppSizes.iconMd,
              color: status.neutral,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.barcode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.code.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
            // Doğru barkod işaretlenmez: işaretlenirse doğrulama bir
            // tiyatroya döner ve yanlış okuma durumu hiç denenmez.
            const SizedBox(width: AppSpacing.sm),
            Icon(
              AppIcons.forward,
              size: AppSizes.iconSm,
              color: status.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

/// Doğrulama sonrası gösterilen onay satırı.
///
/// Toplama ve yerleştirme ekranları aynı satırı kullanır.
class BarcodeVerifiedBanner extends StatelessWidget {
  const BarcodeVerifiedBanner({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: status.successContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.confirm, size: AppSizes.iconSm, color: status.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Barkod doğrulandı · ${product.sku}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: status.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
