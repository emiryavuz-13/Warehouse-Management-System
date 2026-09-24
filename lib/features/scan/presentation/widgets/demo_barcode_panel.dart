import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../providers/scan_providers.dart';

/// Demo barkod listesi (şartname 10. bölüm).
///
/// Şartname bu listeyi kamera çalışmadığında istiyor. Biz **her zaman**
/// gösteriyoruz: demo bir emülatörde ya da toplantı odasında sunulacak,
/// kameranın çalışıp çalışmadığına bakmadan tek dokunuşla ilerleyebilmek
/// gerekiyor. Seçilen barkod gerçekten taranmış gibi işlenir — sonuç ekranı
/// kodun kameradan mı listeden mi geldiğini bilmez.
///
/// Her satır barkodun yanında **eşleştiği ürünü** de gösterir; barkod
/// numaraları birbirine çok benzediği için tek başına rakam dizisi sunum
/// sırasında hangisini seçeceğini söylemez.
class DemoBarcodePanel extends ConsumerWidget {
  const DemoBarcodePanel({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ScanResult>> demo = ref.watch(demoBarcodesProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Demo Barkodlar'.toUpperCaseTr(),
                  style: AppTypography.overline.copyWith(
                    color: status.neutral,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _askForBarcode(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(AppIcons.barcode, size: AppSizes.iconSm),
                label: const Text('Elle gir'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: status.border),
        Flexible(
          child: AsyncValueView<List<ScanResult>>(
            value: demo,
            onRetry: () => ref.invalidate(demoBarcodesProvider),
            data: (List<ScanResult> items) => ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: AppSpacing.lg, color: status.border),
              itemBuilder: (BuildContext context, int index) => _DemoRow(
                result: items[index],
                onTap: () => onSelected(items[index].barcode),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Barkodu elle girme kutusu.
  ///
  /// Şartnamede yok ama depoda etiketler yıpranır; okunamayan bir kodu elle
  /// girebilmek taramanın tek gerçekçi yedeğidir.
  Future<void> _askForBarcode(BuildContext context) async {
    final String? code = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _ManualBarcodeDialog(),
    );

    if (code != null && code.isNotEmpty) onSelected(code);
  }
}

/// Elle barkod girme diyaloğu.
///
/// Metin denetleyicisini **diyalog kendisi sahiplenir.** Çağıran taraf
/// `showDialog` döner dönmez `dispose` ettiğinde, diyaloğun kapanma
/// animasyonu hâlâ alandaki denetleyiciyi okuyor ve uygulama
/// "A TextEditingController was used after being disposed" ile düşüyordu.
class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Barkodu elle gir'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: const InputDecoration(
          labelText: 'Barkod',
          hintText: '8691234567890',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ara')),
      ],
    );
  }
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.result, required this.onTap});

  final ScanResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ProductStockSummary? summary = result.summary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          children: <Widget>[
            Icon(AppIcons.barcode, size: AppSizes.iconMd, color: status.neutral),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.barcode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.code.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    summary?.product.name ?? 'Eşleşen ürün yok',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
            if (summary != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.quantity(summary.totalQuantity, summary.product.unit),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            Icon(AppIcons.forward, size: AppSizes.iconSm, color: status.neutral),
          ],
        ),
      ),
    );
  }
}
