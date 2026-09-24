import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/status_tone_colors.dart';

/// Kamera önizlemesi ve tarama çerçevesi (şartname 10. bölüm).
///
/// **Kamera hiçbir zaman zorunlu değildir.** Emülatörde, izin reddinde ya da
/// kamerasız cihazda ekran çökmez; önizlemenin yerine nedeni açıklayan bir
/// kutu çizilir ve kullanıcı alttaki demo listesinden devam eder. Şartname
/// 10. bölümün *"demo her koşulda çalışmalı"* şartı buradan geliyor.
///
/// Tarama penceresi ortada bir dikdörtgendir: kamera tüm kareyi değil
/// yalnızca o alanı okur. Depo ortamında raf etiketleri yan yanadır, tüm
/// kareyi okumak yanlış barkodu yakalamaya yol açar.
class CameraView extends StatefulWidget {
  const CameraView({required this.onDetect, this.isActive = true, super.key});

  /// Geçerli bir kod okunduğunda bir kez çağrılır.
  final ValueChanged<String> onDetect;

  /// Sekme görünür değilken kamera durdurulur — arka planda çalışan bir
  /// önizleme hem pil harcar hem bazı cihazlarda donar.
  final bool isActive;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late final MobileScannerController _controller = MobileScannerController(
    // Aynı barkodu arka arkaya bildirmesin: kullanıcı kodu çerçevede
    // tutarken saniyede onlarca okuma gelir.
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );

  /// Sonuç ekranına geçilirken gelen ikinci okumayı yutar.
  bool _handled = false;

  @override
  void didUpdateWidget(CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;

    if (widget.isActive) {
      // Sekmeye dönüldüğünde yeni bir tarama beklenir; önceki okuma
      // kilidini açmazsak kamera sessizce çalışmaz görünür.
      _handled = false;
      _controller.start().ignore();
    } else {
      _controller.stop().ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !widget.isActive) return;

    final String? value = capture.barcodes
        .map((Barcode b) => b.rawValue)
        .firstWhere((String? v) => v != null && v.trim().isNotEmpty,
            orElse: () => null);
    if (value == null) return;

    _handled = true;
    widget.onDetect(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side =
            (constraints.maxWidth * 0.68).clamp(0.0, constraints.maxHeight * 0.7);
        final Rect window = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: side,
          height: side * 0.62,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: window,
                errorBuilder:
                    (BuildContext context, MobileScannerException error) =>
                        _CameraUnavailable(error: error),
                placeholderBuilder: (BuildContext context) =>
                    const ColoredBox(color: Colors.black),
              ),
              IgnorePointer(child: _ScanFrame(window: window)),
            ],
          ),
        );
      },
    );
  }
}

/// Tarama çerçevesi: dışı karartılır, okunan alan açık kalır.
///
/// Karartma `CustomPainter` ile tek bir yolda çizilir. Önce `ColorFiltered`
/// + `BlendMode.srcOut` denendi; cihazda katman kaydedilmediği için hiçbir
/// karartma görünmüyordu. Fark yolu (`PathOperation.difference`) her yerde
/// aynı sonucu verir.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.window});

  final Rect window;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ScanFramePainter(window: window),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({required this.window});

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect hole = RRect.fromRectAndRadius(
      window,
      const Radius.circular(AppRadius.md),
    );

    // Kullanıcı barkodu nereye tutacağını tarif okumadan anlamalı.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    canvas.drawRRect(
      hole,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.window != window;
}

/// Kamera açılamadığında önizlemenin yerini alan açıklama.
///
/// Boş siyah bir kutu bırakmak kullanıcıyı "uygulama bozuk" sanmaya iter;
/// nedeni söylemek ve aşağıyı işaret etmek demoyu kurtarır.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({this.error});

  final MobileScannerException? error;

  @override
  Widget build(BuildContext context) {
    final bool permissionDenied =
        error?.errorCode == MobileScannerErrorCode.permissionDenied;

    return CameraUnavailableView(
      title: permissionDenied ? 'Kamera izni verilmedi' : 'Kamera açılamadı',
      message: permissionDenied
          ? 'Ayarlardan kamera iznini açabilir ya da aşağıdaki demo '
                'barkodlardan birini seçebilirsiniz.'
          : 'Bu cihazda kamera kullanılamıyor. Aşağıdaki demo barkodlardan '
                'birini seçerek devam edebilirsiniz.',
    );
  }
}

/// Kamera yokken gösterilen bilgilendirme — ekran ve [CameraView] paylaşır.
class CameraUnavailableView extends StatelessWidget {
  const CameraUnavailableView({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: status.neutralContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: status.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(AppIcons.scan, size: 40, color: status.neutral),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ],
      ),
    );
  }
}
