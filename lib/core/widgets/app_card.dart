import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Uygulamadaki tüm kartların temeli (şartname 5. bölüm: kart tabanlı içerik).
///
/// Gölge yerine ince kenarlık kullanır — ERP/WMS arayüzlerinde bilgi yoğunluğu
/// yüksektir ve her kartın gölgesi olduğunda ekran gürültülü görünür.
/// Kenarlık hiyerarşiyi gölge kadar net verir, çok daha sakin durur.
///
/// [onTap] verildiğinde dokunma efekti ve doğru dokunma alanı otomatik gelir;
/// ekranların kartı ayrıca `InkWell` ile sarması gerekmez.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.accentColor,
    this.borderColor,
    this.backgroundColor,
    this.margin,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Sol kenarda ince bir renk şeridi çizer.
  ///
  /// Durum vurgusu için kullanılır: kritik stok kartının solunda turuncu,
  /// tükenen ürünün solunda kırmızı şerit belirir. Kartın tamamını
  /// renklendirmekten daha sakin bir vurgu yöntemi (şartname 5. bölüm:
  /// "aşırı renk kullanımından kaçınılmalı").
  final Color? accentColor;

  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = accentColor ?? Colors.transparent;

    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: borderColor ?? status.border),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        // Şerit `Positioned` ile çizilir, `Row` + `CrossAxisAlignment.stretch`
        // ile değil: stretch, kartın sınırsız yükseklikte bir ebeveyn içinde
        // (SingleChildScrollView, Column) sonsuz yükseklik talep etmesine yol
        // açıyordu. IntrinsicHeight de çözerdi ama uzun listelerde her kart
        // için ek bir ölçüm geçişi maliyeti getirirdi.
        child: Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: accentColor == null ? 0 : 4),
              child: Padding(padding: padding, child: child),
            ),
            if (accentColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: accent),
              ),
          ],
        ),
      ),
    );

    final Widget card = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            borderRadius: AppRadius.cardRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.cardRadius,
              child: content,
            ),
          );

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// Kart içindeki ikon kutusu.
///
/// Ürün görseli olmayan kartlarda (mock veride görsel yok) ve modül
/// ikonlarında kullanılır. Tek yerde tanımlı olması, uygulamadaki tüm
/// ikon kutularının aynı boyut ve yarıçapta olmasını sağlar.
class AppIconBox extends StatelessWidget {
  const AppIconBox({
    required this.icon,
    this.foreground,
    this.background,
    this.size = AppSizes.productThumb,
    this.iconSize,
    super.key,
  });

  final IconData icon;
  final Color? foreground;
  final Color? background;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? status.neutralContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.45,
        color: foreground ?? status.neutral,
      ),
    );
  }
}
