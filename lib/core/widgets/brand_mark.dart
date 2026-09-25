import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../constants/app_constants.dart';
import '../extensions/string_extensions.dart';

/// Uygulamanın marka işareti.
///
/// Bir rafa **hizalanmış** üç koli, ortadaki vurgulu. İsim "Depom Düzende";
/// düzen fikri işarette hizadan geliyor — kutular aynı tabana oturmuş, eşit
/// aralıklı, hiçbiri yamuk değil. Dağınık bir depoyu çizmek kolaydı ama
/// uygulamanın vaat ettiği şey dağınıklık değil.
///
/// PNG yerine [CustomPaint]: işaret her boyda keskin çizilsin ve renklerini
/// temadan alsın diye. Koyu temada koliler beyaza döner, açık temada
/// mürekkep rengine — tek bir varlık dosyası iki temayı da karşılayamazdı.
///
/// İşaret kareden geniştir (yaklaşık 5:3). [size] **genişliktir**, yükseklik
/// ondan türetilir; kare bir kutuya sıkıştırılsaydı üstte kocaman bir boşluk
/// kalırdı.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 48, this.color, this.accent, super.key});

  /// İşaretin genişliği.
  final double size;

  /// Raf ve kenardaki kolilerin rengi. Verilmezse metin rengi.
  final Color? color;

  /// Ortadaki kolinin rengi. Verilmezse temanın birincil rengi.
  final Color? accent;

  /// Genişliğin yüksekliğe oranı — çizimin kendi ölçüsünden gelir.
  static const double aspectRatio =
      _BrandMarkPainter._contentWidth / _BrandMarkPainter._contentHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size / aspectRatio,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          ink: color ?? theme.colorScheme.onSurface,
          accent: accent ?? theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.ink, required this.accent});

  final Color ink;
  final Color accent;

  // Çizim 48'lik bir ızgarada tasarlandı; aşağıdaki değerler o ızgaradan.
  // Dolu alan yalnızca bir bölümünü kaplıyor, bu yüzden ölçek dolu alana
  // göre hesaplanır — işaretin etrafında kendiliğinden boşluk kalmaz.
  static const double _left = 6;
  static const double _top = 19;
  static const double _contentWidth = 36;
  static const double _contentHeight = 21.5;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _contentWidth;
    final Paint inkPaint = Paint()..color = ink;

    void box(double x, double y, double w, double h, double r, Paint paint) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (x - _left) * scale,
            (y - _top) * scale,
            w * scale,
            h * scale,
          ),
          Radius.circular(r * scale),
        ),
        paint,
      );
    }

    // Raf: hepsinin üstünde durduğu ortak taban.
    box(6, 36, 36, 4.5, 2.25, inkPaint);
    // Üç koli — aynı tabana oturmuş, eşit aralıklı.
    box(8.5, 24, 8.5, 11, 2, inkPaint);
    box(19.75, 19, 8.5, 16, 2, Paint()..color = accent);
    box(31, 27, 8.5, 8, 2, inkPaint);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) =>
      old.ink != ink || old.accent != accent;
}

/// Uygulama adının yazılışı.
///
/// İki kelime iki işi bölüşür: "Depom" sahibini söyler, **"Düzende"** iddiayı.
/// Ağırlık farkı gözün nereye bakacağını söyler ve ad tek satırda kalır —
/// dar yerlerde ikiye bölünmez.
///
/// Tek bir [Text.rich] olarak kurulur, iki ayrı [Text] olarak değil: aradaki
/// boşluk satır sonuna denk gelirse ad bölünmesin ve metin arama araçları
/// adı bütün görsün diye.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({this.fontSize = 24, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: 'Depom ',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const TextSpan(
            text: 'Düzende',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontSize: fontSize,
        height: 1,
        letterSpacing: -fontSize * 0.028,
      ),
    );
  }
}

/// İşaret ve adın birlikte kullanıldığı yatay hâli.
///
/// Yalnızca markanın kendisini gösteren yerlerde kullanılır — açılış ekranı
/// ve profil. Operasyonel ekranlarda logo yoktur: depo çalışanının ekranında
/// marka değil talimat durmalı.
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.markSize = 44, this.showTagline = true, super.key});

  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.26),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BrandWordmark(fontSize: markSize * 0.52),
            if (showTagline) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                // Dart'ın toUpperCase'i 'Sistemi'yi 'SISTEMI' yapar; noktalı İ
                // için Türkçe kuralı gerekiyor.
                AppConstants.appTagline.toUpperCaseTr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: markSize * 0.11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: markSize * 0.038,
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
