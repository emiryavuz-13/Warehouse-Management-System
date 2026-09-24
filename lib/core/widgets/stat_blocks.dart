import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../models/enums.dart';
import '../extensions/string_extensions.dart';

/// Bir metriğin değişimi (dataviz stat tile sözleşmesinin `delta` parçası).
///
/// İki kuralı vardır:
///
/// 1. **İşaretli ve dönem adlı.** "+122" değil, "↑122 bu hafta". Bağlamsız
///    bir değişim sayısı, değişim olmadığı gibi bilgi taşımaz.
/// 2. **Renk = yön × yükselmenin iyi olup olmadığı.** Stok için yukarı iyidir;
///    bekleyen sipariş için yukarı kötüdür. [upIsGood] bunu belirler, widget
///    rengi kendisi seçmez.
class DeltaLabel extends StatelessWidget {
  const DeltaLabel({
    required this.value,
    required this.period,
    this.upIsGood = true,
    this.unit,
    super.key,
  });

  /// İşaretli değişim. Sıfır ise nötr gösterilir.
  final int value;

  /// Karşılaştırma dönemi, ör. `bu hafta`, `bugün`.
  final String period;

  final bool upIsGood;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    if (value == 0) {
      return Text(
        'değişim yok',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: status.neutral),
      );
    }

    final bool isUp = value > 0;
    final bool isGood = isUp == upIsGood;
    final Color color = isGood ? status.success : status.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isUp ? AppIcons.trendUp : AppIcons.trendDown,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${value.abs()}${unit == null ? '' : ' $unit'} $period',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Dashboard'un liderlik ettiği tek sayı (dataviz: "hero figure").
///
/// Görünüm başına **tam olarak bir tane** olur. Altı metriği eşit boyutta
/// dizmek hiyerarşi kurmaz; okuyucu nereden başlayacağını bilemez. Bir sayıyı
/// öne çıkarmak kalan beşine de sıra kazandırır.
///
/// Kutu içinde değil: çerçeve, sayıdan daha görünür olmamalı.
class HeroFigure extends StatelessWidget {
  const HeroFigure({
    required this.value,
    required this.label,
    this.unit,
    this.delta,
    this.trend,
    this.trendLabel,
    this.breakdown,
    super.key,
  });

  /// Biçimlendirilmiş ana değer, ör. `496`.
  final String value;

  /// Sayının ne olduğu, ör. `toplam stok`.
  final String label;

  final String? unit;

  /// Değişim göstergesi.
  final Widget? delta;

  /// Sağ tarafta duran trend görseli.
  final Widget? trend;

  /// Trendin neyi kapsadığı, ör. `son 7 gün`.
  final String? trendLabel;

  /// Altta duran kırılım satırı, ör. `122 giriş · 60 çıkış`.
  final Widget? breakdown;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heroFigure,
                        ),
                      ),
                      if (unit != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm - 2),
                        Text(
                          unit!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: status.neutral),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
            if (trend != null) ...<Widget>[
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 108,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    trend!,
                    if (trendLabel != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        trendLabel!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: status.neutral, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        if (delta != null || breakdown != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              ?delta,
              if (delta != null && breakdown != null) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Container(width: 1, height: 12, color: status.border),
                const SizedBox(width: AppSpacing.md),
              ],
              if (breakdown != null) Flexible(child: breakdown!),
            ],
          ),
        ],
      ],
    );
  }
}

/// Kutusuz KPI bloğu (dataviz stat tile: `label · value · delta`).
///
/// Kart yerine düz blok: altı kartın çerçevesi ekranda sayılardan daha
/// görünür hale geliyordu. Gruplar arası ayrım kenarlıkla değil, ince
/// ayraçlar ve boşlukla kuruluyor.
///
/// İkon yok. İkon, sayıyla dikkat için yarışır ve altı farklı renkli ikon
/// kutusu rengi anlamsızlaştırır — renk yalnızca gerçek duruma ayrılmalı.
class StatBlock extends StatelessWidget {
  const StatBlock({
    required this.label,
    required this.value,
    this.sublabel,
    this.delta,
    this.tone,
    this.onTap,
    this.isSelected = false,
    super.key,
  });

  /// Küçük, seyrek harfli üst etiket, ör. `BEKLEYEN`.
  final String label;

  /// Biçimlendirilmiş değer.
  final String value;

  /// Değerin altındaki açıklama, ör. `sipariş`.
  final String? sublabel;

  /// [DeltaLabel] veya benzeri değişim göstergesi.
  final Widget? delta;

  /// Yalnızca **gerçek durum** taşıyan metriklerde verilir (kritik stok gibi).
  /// Dekoratif renklendirme için kullanılmaz.
  final StatusTone? tone;

  final VoidCallback? onTap;

  /// Blok aynı zamanda bir filtre düğmesi olarak kullanıldığında seçili
  /// olanı işaretler: etiket vurgulanır ve altına ince bir çizgi çekilir.
  ///
  /// Seçimi renk soldurmayla değil çizgiyle göstermek gerekir; soluk bir
  /// blok "devre dışı" gibi okunur.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Color accent = tone == null
        ? Theme.of(context).colorScheme.primary
        : tone!.foreground(context);
    final Color valueColor = tone == null
        ? Theme.of(context).colorScheme.onSurface
        : tone!.foreground(context);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCaseTr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.overline.copyWith(
            color: isSelected ? accent : status.neutral,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.metricMedium.copyWith(color: valueColor),
        ),
        const SizedBox(height: 2),
        if (delta != null)
          delta!
        else if (sublabel != null)
          Text(
            sublabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        if (isSelected) ...<Widget>[
          const SizedBox(height: AppSpacing.sm - 2),
          Container(
            height: 2,
            width: 20,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: content,
      ),
    );
  }
}

/// KPI bloklarını sütunlara dizer ve aralarına ince dikey ayraç koyar.
///
/// Satırlar arasına yatay ayraç girer. Kutular yerine ayraçlar kullanmak,
/// ekrandaki çizgi sayısını altı kartın yirmi dört kenarından beşe indirir.
class StatRow extends StatelessWidget {
  const StatRow({required this.blocks, super.key});

  final List<Widget> blocks;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < blocks.length; i++) ...<Widget>[
            if (i > 0) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              VerticalDivider(width: 1, thickness: 1, color: status.border),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: blocks[i]),
          ],
        ],
      ),
    );
  }
}
