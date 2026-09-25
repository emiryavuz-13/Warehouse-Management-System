import 'package:flutter/material.dart';

/// Liste satırlarının hafif giriş animasyonu (şartname 33. bölüm).
///
/// Şartname "kartların hafif giriş animasyonu" istiyor ama hemen ardından
/// *"operasyonel ekranlarda kullanıcıyı yavaşlatan animasyonlardan
/// kaçınılmalı"* diyor. Bu ikisi ancak üç sınırla birlikte sağlanabilir:
///
/// 1. **Yalnızca ilk satırlar.** [maxAnimatedIndex]'ten sonrası anında
///    çizilir. Uzun bir listede yüzüncü satırın animasyonu kimseye bir şey
///    anlatmaz; üstelik `ListView` ekrandan çıkan satırları yok edip geri
///    geldiğinde yeniden oluşturduğu için aşağı-yukarı kaydıran kullanıcı
///    aynı animasyonu defalarca görürdü.
/// 2. **Kısa ve küçük.** 160 ms, 6 piksel. Göz fark eder, el beklemez.
/// 3. **Bir kez.** Animasyon `initState`'te başlar; veri yenilendiğinde
///    (revizyon sayacı arttığında) satır yeniden çizilir ama widget aynı
///    kaldığı için animasyon tekrarlamaz.
class ListEntrance extends StatefulWidget {
  const ListEntrance({
    required this.index,
    required this.child,
    this.maxAnimatedIndex = 7,
    super.key,
  });

  /// Satırın listedeki sırası — gecikmeyi belirler.
  final int index;

  final Widget child;

  /// Bu sıradan sonraki satırlar animasyonsuz çizilir.
  final int maxAnimatedIndex;

  @override
  State<ListEntrance> createState() => _ListEntranceState();
}

class _ListEntranceState extends State<ListEntrance>
    with SingleTickerProviderStateMixin {
  static const int _durationMs = 160;
  static const int _stepMs = 25;

  AnimationController? _controller;
  Animation<double>? _curve;

  @override
  void initState() {
    super.initState();
    if (widget.index > widget.maxAnimatedIndex) return;

    // Gecikme `Future.delayed` ile değil `Interval` ile veriliyor: zamanlayıcı
    // kullanılırsa, satır animasyon başlamadan ekrandan çıktığında askıda
    // bir timer kalıyor (testler bunu "A Timer is still pending" ile
    // yakaladı). Tek denetleyici hem bekler hem oynatır.
    final int delayMs = _stepMs * widget.index;
    final int totalMs = delayMs + _durationMs;

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _controller = controller;
    _curve = CurvedAnimation(
      parent: controller,
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOut),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double>? curve = _curve;
    if (curve == null) return widget.child;

    return AnimatedBuilder(
      animation: curve,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
