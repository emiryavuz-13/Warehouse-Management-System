import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Uygulamanın marka işareti.
///
/// Bir raf, üstünde duran iki koli ve yerleşmeyi bekleyen bir koli daha —
/// uygulamanın anlattığı akışın tamamı: mal gelir, rafa yerleşir, oradan
/// alınır.
///
/// İşaretin ikinci bir okuması var: mavi kare ile altındaki gövde birlikte
/// **İ** harfini kuruyor. Türkçenin noktalı İ'si burada bilinçli bir seçim;
/// uygulamada büyük harf dönüşümü için ayrı bir çözüm yazmamıza sebep olan
/// harf o.
///
/// PNG yerine [CustomPaint]: işaret her boyda keskin çizilsin ve renkleri
/// temadan alsın diye. Koyu temada gövde beyaza döner, açık temada mürekkep
/// rengine — tek bir varlık dosyası iki temayı da karşılayamazdı.
class IstifMark extends StatelessWidget {
  const IstifMark({this.size = 32, this.color, this.accent, super.key});

  final double size;

  /// Raf ve gövdenin rengi. Verilmezse metin rengi kullanılır.
  final Color? color;

  /// Bekleyen kolinin rengi. Verilmezse temanın birincil rengi.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IstifMarkPainter(
          ink: color ?? theme.colorScheme.onSurface,
          accent: accent ?? theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _IstifMarkPainter extends CustomPainter {
  const _IstifMarkPainter({required this.ink, required this.accent});

  final Color ink;
  final Color accent;

  /// İşaret 38x38'lik bir ızgarada tasarlandı; tüm ölçüler ona göre.
  static const double _grid = 38;

  @override
  void paint(Canvas canvas, Size size) {
    final double u = size.width / _grid;
    final Paint inkPaint = Paint()..color = ink;

    void box(double x, double y, double w, double h, double r, Paint paint) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((x - 5) * u, (y - 5) * u, w * u, h * u),
          Radius.circular(r * u),
        ),
        paint,
      );
    }

    // Raf — her şeyin üstünde durduğu yer.
    box(5.5, 38, 37, 4, 2, inkPaint);
    // İ'nin gövdesi, rafta duran koli.
    box(8.5, 20.5, 11, 17, 2.5, inkPaint);
    // Yanındaki koli: gövdeden ayrılsın diye soluk.
    box(22.5, 26.5, 17, 11, 2.5, Paint()..color = ink.withValues(alpha: 0.45));
    // İ'nin noktası, yerleşmeyi bekleyen koli.
    box(8.5, 6, 11, 11, 2.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_IstifMarkPainter old) =>
      old.ink != ink || old.accent != accent;
}

/// İşaret ve yazının birlikte kullanıldığı hâli.
///
/// Açılış ekranı ve profil gibi markanın kendisini gösteren yerlerde
/// kullanılır; operasyonel ekranlarda logo yoktur — depo çalışanının
/// ekranında marka değil talimat durmalı.
class IstifLockup extends StatelessWidget {
  const IstifLockup({this.markSize = 44, this.showTagline = true, super.key});

  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        IstifMark(size: markSize),
        SizedBox(width: markSize * 0.22),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'İstif',
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: markSize * 0.82,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            if (showTagline) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'DEPO YÖNETİM SİSTEMİ',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: markSize * 0.16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: markSize * 0.055,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
