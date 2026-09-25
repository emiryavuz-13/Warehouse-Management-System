import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';
import 'difference_label.dart';

/// Tek ürünün fiziksel sayımını girme ekranı (şartname 16. bölüm).
///
/// Şartnamenin "Sayım ekranı" örneği birebir:
///
/// ```text
/// iPhone 15
/// Sistem Stoku: 24
/// Fiziksel Sayım: [ 23 ]
/// Fark: -1
/// [ Sayımı Kaydet ]
/// ```
///
/// **Panel, ayrı sayfa değil.** Sayan kişi rafın önünde durur ve ürünleri
/// arka arkaya girer; her ürün için sayfa açıp kapatmak listedeki yeri
/// kaybettirir. Panel kapandığında liste olduğu yerde kalır.
///
/// **Fark canlı hesaplanır.** Kullanıcı sayıyı değiştirdikçe fark anında
/// güncellenir; kaydet'e basmadan önce ne olacağını görmeli.
///
/// Varsayılan değer sistem stoğudur, sıfır değil. Depo sayımlarının çoğu
/// tutar; kullanıcıyı her seferinde sıfırdan yukarı saydırmak gereksiz iş.
class CountEntrySheet extends StatefulWidget {
  const CountEntrySheet({
    required this.line,
    required this.locationCode,
    super.key,
  });

  final CountLineDetail line;
  final String locationCode;

  /// Paneli açar; kullanıcı kaydederse girilen miktarı döner.
  static Future<int?> show({
    required BuildContext context,
    required CountLineDetail line,
    required String locationCode,
  }) {
    return showAppSheet<int>(
      context: context,
      builder: (BuildContext context) =>
          CountEntrySheet(line: line, locationCode: locationCode),
    );
  }

  @override
  State<CountEntrySheet> createState() => _CountEntrySheetState();
}

class _CountEntrySheetState extends State<CountEntrySheet> {
  late int _counted =
      widget.line.line.countedQuantity ?? widget.line.line.systemQuantity;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Product product = widget.line.product;
    final InventoryCountLine data = widget.line.line;
    final int difference = _counted - data.systemQuantity;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                CodeChip(code: widget.locationCode),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            CodeChip(code: product.sku),

            const SizedBox(height: AppSpacing.xl),

            // Şartnamenin üç satırı: sistem · fiziksel · fark.
            StatRow(
              blocks: <Widget>[
                StatBlock(
                  label: 'Sistem stoku',
                  value: Formatters.integer.format(data.systemQuantity),
                  sublabel: product.unit,
                ),
                StatBlock(
                  label: 'Fiziksel',
                  value: Formatters.integer.format(_counted),
                  sublabel: product.unit,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'FARK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: status.neutral,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    DifferenceLabel(value: difference),
                    const SizedBox(height: 2),
                    Text(
                      difference == 0
                          ? 'eşleşti'
                          : (difference < 0 ? 'eksik' : 'fazla'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            QuantitySelector(
              label: 'Raftaki fiziksel miktar',
              value: _counted,
              // Sıfır geçerli bir sayım sonucudur: raf boş çıkmış olabilir.
              min: 0,
              unit: product.unit,
              showMaxAction: false,
              onChanged: (int value) => setState(() => _counted = value),
            ),

            if (difference != 0) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _DifferenceNotice(
                difference: difference,
                systemQuantity: data.systemQuantity,
                counted: _counted,
                unit: product.unit,
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: 'Vazgeç',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: 'Sayımı Kaydet',
                    onPressed: () => Navigator.of(context).pop(_counted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fark çıktığında ne olacağını söyleyen şerit.
///
/// "Fark: -1" tek başına ne yapılacağını söylemez. Stoğun hangi değere
/// çekileceğini yazmak, kullanıcının yanlış sayı girdiğini fark etmesini
/// sağlar.
class _DifferenceNotice extends StatelessWidget {
  const _DifferenceNotice({
    required this.difference,
    required this.systemQuantity,
    required this.counted,
    required this.unit,
  });

  final int difference;
  final int systemQuantity;
  final int counted;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool isShort = difference < 0;
    final Color color = isShort ? status.danger : status.warning;
    final Color background = isShort
        ? status.dangerContainer
        : status.warningContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(StatusTone.warning.icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sayım onaylandığında stok $systemQuantity yerine '
              '$counted $unit olarak güncellenecek '
              '(${isShort ? 'eksik' : 'fazla'} ${difference.abs()}).',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
