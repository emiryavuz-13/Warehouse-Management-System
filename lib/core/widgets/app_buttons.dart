import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../models/enums.dart';

/// Birincil eylem butonu (şartname 29. bölüm).
///
/// Tema zaten 52dp yüksekliği ve yarıçapı veriyor; bu sınıfın kattığı şey
/// **yükleniyor durumu**. Operasyonel ekranlarda onay butonuna iki kez
/// basmak iki transfer demektir; [isLoading] sırasında buton kendini
/// devre dışı bırakır ve göstergeye döner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.tone,
    this.expanded = true,
    super.key,
  });

  final String label;

  /// `null` verilmesi butonu devre dışı bırakır.
  final VoidCallback? onPressed;

  final IconData? icon;
  final bool isLoading;

  /// Yıkıcı eylemler için [StatusTone.danger] geçilir; buton kırmızıya döner.
  final StatusTone? tone;

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color? background = tone?.foreground(context);

    final Widget button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: background == null
          ? null
          : FilledButton.styleFrom(backgroundColor: background),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colors.onPrimary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    return expanded ? button : IntrinsicWidth(child: button);
  }
}

/// İkincil eylem butonu — vazgeç, geri, alternatif akış.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    return expanded ? button : IntrinsicWidth(child: button);
  }
}

/// Liste satırının sonundaki eylem etiketi (şartname 29. bölüm).
///
/// Sağa bakan bir ok satırın tıklanabildiğini söyler ama **ne olacağını**
/// söylemez. Operasyonel ekranlarda bu fark önemli: mal kabul satırına
/// dokunmak yerleştirme ekranını açar, sipariş satırındaki düğme o kalemi
/// toplamaya götürür. Telefonu eline yeni almış bir depo çalışanı bunu
/// deneyerek değil okuyarak bilmeli.
///
/// Etiket satırın sağ sütununa, miktarın altına yerleşir. Yan yana
/// dizilseydi dar ekranda ve büyük yazı tipinde ürün adını ezerdi; alt alta
/// dizilince genişlik en uzun tek satır kadar olur.
///
/// [onPressed] boş bırakılırsa bileşen kendi dokunma alanını açmaz: satırın
/// tamamı zaten tıklanabilir demektir, etiket yalnızca ne olacağını duyurur.
class RowAction extends StatelessWidget {
  const RowAction({required this.label, this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 2),
        Icon(AppIcons.forward, size: AppSizes.iconSm, color: color),
      ],
    );

    if (onPressed == null) return content;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        // Yatay dolgu yok: etiket sütunun sağ kenarında miktarla hizalı
        // dursun. Dokunma alanını dikeyde açıyoruz.
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: content,
      ),
    );
  }
}

/// Ekranın altına sabitlenen eylem çubuğu.
///
/// Operasyonel ekranlarda ("Transferi Başlat", "Toplamayı Onayla") onay
/// butonu listenin sonunda kaybolmamalı; liste ne kadar uzun olursa olsun
/// aynı yerde durmalı. Üst kenarlık ve yüzey rengi, altındaki içerikten
/// ayrıldığını gösterir.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({required this.children, this.padding, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: Theme.of(context).status.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
