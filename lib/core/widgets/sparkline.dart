import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Küçük trend çizgisi — stat tile'ın "trend" bileşeni.
///
/// Eksen, ızgara ve etiket yoktur: sparkline bir grafik değil, sayının
/// yanındaki **bağlamdır**. Tek soruyu cevaplar: "artıyor mu, azalıyor mu?"
///
/// Çizim kuralları (dataviz):
/// - Tek seri, tek hue. İki renk olsaydı okuyucu bir kıyas arardı.
/// - Çizgi ince (2px) ve sönük tonda; son nokta vurgu renginde.
///   Göz önce "şu an neredeyiz"e gitmeli, geçmişe değil.
/// - Dolgu çok hafif: hacmi ima eder ama çizgiyi bastırmaz.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    this.lineColor,
    this.accentColor,
    this.height = 40,
    super.key,
  });

  /// Zaman sırasına göre değerler (eskiden yeniye).
  final List<double> values;

  final Color? lineColor;

  /// Son noktanın rengi — "şu an" vurgusu.
  final Color? accentColor;

  final double height;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (values.length < 2) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          lineColor: lineColor ?? status.neutral.withValues(alpha: 0.55),
          accentColor: accentColor ?? colors.primary,
          fillColor: (lineColor ?? colors.primary).withValues(alpha: 0.10),
          surfaceColor: colors.surface,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.accentColor,
    required this.fillColor,
    required this.surfaceColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color accentColor;
  final Color fillColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double dotRadius = 3.5;
    // Son noktanın yuvarlağı kenarlardan taşmasın.
    final double left = dotRadius;
    final double right = size.width - dotRadius;
    final double top = dotRadius;
    final double bottom = size.height - dotRadius;

    final double maxValue = values.reduce(
      (double a, double b) => a > b ? a : b,
    );
    final double minValue = values.reduce(
      (double a, double b) => a < b ? a : b,
    );
    // Tüm değerler eşitse çizgi ortadan geçsin, sıfıra bölme olmasın.
    final double span = maxValue - minValue;

    final List<Offset> points = <Offset>[
      for (int i = 0; i < values.length; i++)
        Offset(
          left + (right - left) * (i / (values.length - 1)),
          span == 0
              ? (top + bottom) / 2
              : bottom - (bottom - top) * ((values[i] - minValue) / span),
        ),
    ];

    final Path line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    // Dolgu: çizgiyi taban çizgisine kapatır.
    final Path fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = fillColor);

    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Son nokta: önce yüzey renginde bir halka, sonra vurgu noktası.
    // Halka, nokta çizginin üzerine denk geldiğinde ikisinin birbirine
    // yapışmasını engeller (dataviz: örtüşen marklarda 2px yüzey halkası).
    canvas.drawCircle(
      points.last,
      dotRadius + 2,
      Paint()..color = surfaceColor,
    );
    canvas.drawCircle(points.last, dotRadius, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return !_listEquals(oldDelegate.values, values) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Çubuklu sparkline — günlük hacim gösterimi için.
///
/// Çizgi sürekliliği ima eder ("değer bu aralıkta böyle ilerledi"); oysa
/// günlük hareket sayısı **ayrık** bir ölçüdür. Çubuk her günü ayrı bir
/// olay olarak gösterir ve hareketsiz günü boşluk olarak değil, sıfır
/// yükseklikli bir yuva olarak bırakır.
class SparkBars extends StatelessWidget {
  const SparkBars({
    required this.values,
    this.barColor,
    this.accentColor,
    this.height = 40,
    super.key,
  });

  final List<double> values;
  final Color? barColor;
  final Color? accentColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (values.isEmpty) return SizedBox(height: height);

    final double maxValue = values.reduce(
      (double a, double b) => a > b ? a : b,
    );

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < values.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _SparkBar(
                // Sıfır değerli gün de görünür kalmalı: en az 2px.
                ratio: maxValue == 0 ? 0 : values[i] / maxValue,
                color: i == values.length - 1
                    ? (accentColor ?? colors.primary)
                    : (barColor ?? status.neutral.withValues(alpha: 0.35)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparkBar extends StatelessWidget {
  const _SparkBar({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double full = constraints.maxHeight;
        final double barHeight = (full * ratio).clamp(2.0, full);

        return Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: barHeight),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return Container(
                height: value,
                decoration: BoxDecoration(
                  color: color,
                  // Veri ucu yuvarlak, taban çizgisine oturur.
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
