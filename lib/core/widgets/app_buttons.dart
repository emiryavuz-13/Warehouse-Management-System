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
