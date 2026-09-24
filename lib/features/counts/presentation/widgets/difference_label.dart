import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Sayım farkı göstergesi (şartname 16. bölüm).
///
/// Üç kural:
///
/// 1. **İşaretli.** `-1` ve `+3` farklı şeylerdir; işaretsiz bir "1" hangisi
///    olduğunu söylemez.
/// 2. **Sıfır yeşil değil, nötr.** Fark olmaması iyi haber ama bir "başarı"
///    değil, beklenen durumdur. Yeşile boyamak, farkı olan satırların
///    yanında gereksiz bir kutlama yaratır.
/// 3. **Eksik kırmızı, fazla turuncu.** İkisi de düzeltme gerektirir ama
///    eksik stok doğrudan kayıptır; fazla stok genellikle bir kayıt hatasıdır.
///    Aynı renge boyamak bu farkı siler.
class DifferenceLabel extends StatelessWidget {
  const DifferenceLabel({required this.value, this.fontSize, super.key});

  final int value;

  /// Varsayılan metrik boyutunu ezmek için — onay kutusu gibi dar yerlerde.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    final Color color = switch (value) {
      < 0 => status.danger,
      > 0 => status.warning,
      _ => status.neutral,
    };

    final TextStyle base = AppTypography.metricMedium.copyWith(color: color);

    return Text(
      value == 0 ? '0' : (value > 0 ? '+$value' : '$value'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: fontSize == null ? base : base.copyWith(fontSize: fontSize),
    );
  }
}
