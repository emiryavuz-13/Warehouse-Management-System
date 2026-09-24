import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/views.dart';
import '../../../../models/models.dart';

/// Stok listesinin tek satırı (şartname 9. bölüm).
///
/// Şartnamenin istediği altı bilgiyi taşır: ürün, SKU, miktar, lokasyon,
/// minimum stok ve durum.
///
/// **Satır açılır, yeni ekran açmaz.** Şartname 9. bölüm stok detayında
/// lokasyon kırılımını istiyor; bunu ayrı bir sayfaya taşımak, ürün detayının
/// neredeyse birebir kopyası olan ikinci bir ekran demekti. Depo çalışanı
/// stok listesini tararken karşılaştırma yapar — üç ürünün nerede durduğunu
/// görmek için üç kez girip çıkmak yerine üç satırı yan yana açabilmeli ve
/// listedeki yerini kaybetmemeli.
///
/// Açılan panel aynı zamanda **eylem çekmecesidir**: ürün detayı ve transfer
/// oradan başlar. Böylece tek lokasyonlu ürünlerde de açmanın karşılığı olur.
class StockRow extends StatefulWidget {
  const StockRow({
    required this.summary,
    required this.onOpenProduct,
    required this.onTransfer,
    this.onOpenLocation,
    super.key,
  });

  final ProductStockSummary summary;

  final VoidCallback onOpenProduct;

  /// Stoğu sıfır olan üründe transfer başlatılamaz; bu geri çağrı yine de
  /// verilir, satır düğmeyi kendisi devre dışı bırakır.
  final VoidCallback onTransfer;

  final void Function(String locationId)? onOpenLocation;

  @override
  State<StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<StockRow>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ProductStockSummary summary = widget.summary;
    final Product product = summary.product;
    final StockStatus stockStatus = summary.status;
    final bool needsAttention = stockStatus != StockStatus.normal;

    // Şartname 9. bölümün kolonları: SKU, lokasyon, minimum stok.
    //
    // Lokasyonu olmayan üründe "lokasyon yok" yazılmaz: satırda zaten
    // "Stok Yok" rozeti var, tekrar etmek minimum stok bilgisini ekranın
    // dışına itiyordu.
    final List<String> meta = <String>[
      product.sku,
      if (summary.primaryLocation != null)
        summary.locations.length > 1
            ? '${summary.primaryLocation!.code} +${summary.locations.length - 1}'
            : summary.primaryLocation!.code,
      'min ${product.minStock}',
    ];

    return Column(
      children: <Widget>[
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: <Widget>[
                AppIconBox(
                  icon: categoryIcon(summary.category?.iconKey ?? ''),
                  size: 40,
                  iconSize: 19,
                  background: needsAttention
                      ? stockStatus.tone.background(context)
                      : status.neutralContainer,
                  foreground: needsAttention
                      ? stockStatus.tone.foreground(context)
                      : status.neutral,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.code.copyWith(
                          fontSize: 11.5,
                          color: status.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          Formatters.integer.format(summary.totalQuantity),
                          style: AppTypography.metricMedium.copyWith(
                            color: needsAttention
                                ? stockStatus.tone.foreground(context)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          product.unit,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: status.neutral),
                        ),
                      ],
                    ),
                    if (needsAttention) ...<Widget>[
                      const SizedBox(height: 3),
                      StockStatusBadge(status: stockStatus, compact: true),
                    ],
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                // Açılır/kapanır göstergesi: satırın tıklanabilir olduğunu
                // ve neyin olacağını önceden söyler.
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    AppIcons.expand,
                    size: AppSizes.iconSm,
                    color: status.neutral,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? _ExpandedPanel(
                  summary: summary,
                  onOpenProduct: widget.onOpenProduct,
                  onTransfer: widget.onTransfer,
                  onOpenLocation: widget.onOpenLocation,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Panel eylemlerinin ortak biçimi — dar ekranda taşmayacak dolgu.
final ButtonStyle _actionStyle = TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
  visualDensity: VisualDensity.compact,
);

/// Satır açıldığında görünen panel: lokasyon kırılımı + eylemler.
class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.summary,
    required this.onOpenProduct,
    required this.onTransfer,
    this.onOpenLocation,
  });

  final ProductStockSummary summary;
  final VoidCallback onOpenProduct;
  final VoidCallback onTransfer;
  final void Function(String locationId)? onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool hasStock = summary.totalQuantity > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: status.neutralContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Lokasyonlar',
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (summary.locations.isEmpty)
            Text(
              'Bu ürün hiçbir lokasyonda kayıtlı değil.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            )
          else
            LocationBreakdown(
              summary: summary,
              dense: true,
              onLocationTap: onOpenLocation,
            ),
          const SizedBox(height: AppSpacing.xs),
          // İki eylem alanı eşit paylaşır: dar ekranlarda varsayılan buton
          // dolgusu satırı taşırıyordu.
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: onOpenProduct,
                  style: _actionStyle,
                  icon: const Icon(AppIcons.products, size: AppSizes.iconSm),
                  label: const Text('Ürün detayı', maxLines: 1),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  // Stoku olmayan ürün transfer edilemez
                  // (şartname 26. bölüm).
                  onPressed: hasStock ? onTransfer : null,
                  style: _actionStyle,
                  icon: const Icon(AppIcons.transfer, size: AppSizes.iconSm),
                  label: const Text('Transfer', maxLines: 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
