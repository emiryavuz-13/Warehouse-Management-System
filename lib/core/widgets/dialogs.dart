import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../models/enums.dart';
import 'app_buttons.dart';

/// Onay dialogu (şartname 30. bölüm).
///
/// Şartname önemli operasyonların onay gerektirmesini istiyor. Kritik olan
/// nokta: onay metni **ne olacağını somut olarak yazmalı**. "Emin misiniz?"
/// yerine "5 adet iPhone 15, A-01-01 → B-03-02" gösterilir; kullanıcı
/// onaylamadan önce yanlış lokasyon seçtiğini görebilmeli.
///
/// [details] satırları bu özeti taşır.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    required this.title,
    required this.message,
    this.details = const <ConfirmationDetail>[],
    this.confirmLabel = 'Onayla',
    this.cancelLabel = 'Vazgeç',
    this.tone,
    this.icon,
    super.key,
  });

  final String title;
  final String message;
  final List<ConfirmationDetail> details;
  final String confirmLabel;
  final String cancelLabel;

  /// Yıkıcı eylemlerde [StatusTone.danger] geçilir.
  final StatusTone? tone;

  final IconData? icon;

  /// Dialogu gösterir; kullanıcı onayladıysa `true` döner.
  ///
  /// `false` ve `null` aynı anlama gelir (vazgeçildi), çağıran taraf
  /// yalnızca `true` kontrolü yapar.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    List<ConfirmationDetail> details = const <ConfirmationDetail>[],
    String confirmLabel = 'Onayla',
    String cancelLabel = 'Vazgeç',
    StatusTone? tone,
    IconData? icon,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ConfirmationDialog(
        title: title,
        message: message,
        details: details,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        tone: tone,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StatusTone resolvedTone = tone ?? StatusTone.info;

    return AlertDialog(
      icon: Icon(
        icon ?? resolvedTone.icon,
        size: 28,
        color: resolvedTone.foreground(context),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: status.neutral),
          ),
          if (details.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: status.neutralContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < details.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    details[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                label: confirmLabel,
                tone: tone,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Onay dialogundaki tek bilgi satırı: etiket solda, değer sağda.
class ConfirmationDetail extends StatelessWidget {
  const ConfirmationDetail({
    required this.label,
    required this.value,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    // Her iki taraf da uzun olabiliyor: etiket bir ürün adı ("iPhone 15
    // 128GB Siyah"), değer bir yol ("A-01-01 → B-03-02") olabilir. İkisini
    // de sabit bırakmak satırı taşırıyordu.
    //
    // Etiket esnektir ve kısaysa daha az yer kaplar; değer `Expanded` ile
    // payını tam doldurur, böylece sağa hizalama her satırda korunur. İkisi
    // de gerekirse iki satıra iner, hiçbir koşulda taşmaz.
    //
    // `LayoutBuilder` kullanılamaz: `AlertDialog` içeriğinin genişliğini
    // intrinsic ölçümle hesaplıyor ve `LayoutBuilder` bunu desteklemiyor.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(
          flex: 4,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ),
      ],
    );
  }
}

/// Başarı dialogu (şartname 25. bölüm).
///
/// Snackbar'dan farkı, işlemin **sonucunu** göstermesi: transferden sonra
/// "A-01-01: 18 → 13, B-03-02: 6 → 11" satırları burada çıkar. Şartname 15.
/// bölüm bu gösterimi açıkça istiyor.
///
/// İkincil eylem, akışın doğal devamına götürür: toplama bitince
/// "Sevkiyata Geç", mal kabul bitince "Ürünü Gör".
class SuccessDialog extends StatelessWidget {
  const SuccessDialog({
    required this.title,
    this.message,
    this.details = const <ConfirmationDetail>[],
    this.primaryLabel = 'Tamam',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final String title;
  final String? message;
  final List<ConfirmationDetail> details;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Dialogu gösterir. İkincil eyleme basıldıysa `true` döner.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? message,
    List<ConfirmationDetail> details = const <ConfirmationDetail>[],
    String primaryLabel = 'Tamam',
    String? secondaryLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => SuccessDialog(
        title: title,
        message: message,
        details: details,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: () => Navigator.of(context).pop(false),
        onSecondary: () => Navigator.of(context).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return AlertDialog(
      icon: _SuccessIcon(
        color: status.success,
        background: status.successContainer,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (message != null)
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: status.neutral),
            ),
          if (details.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: status.neutralContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < details.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    details[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        Column(
          children: <Widget>[
            PrimaryButton(label: primaryLabel, onPressed: onPrimary),
            if (secondaryLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(label: secondaryLabel!, onPressed: onSecondary),
            ],
          ],
        ),
      ],
    );
  }
}

/// Başarı ikonunun kısa giriş animasyonu (şartname 33. bölüm).
///
/// Animasyon bilerek kısa: operasyonel ekranlarda kullanıcıyı bekletmemeli.
class _SuccessIcon extends StatefulWidget {
  const _SuccessIcon({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  State<_SuccessIcon> createState() => _SuccessIconState();
}

class _SuccessIconState extends State<_SuccessIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: widget.background,
          shape: BoxShape.circle,
        ),
        child: Icon(StatusTone.success.icon, size: 28, color: widget.color),
      ),
    );
  }
}
