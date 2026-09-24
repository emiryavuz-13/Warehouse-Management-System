import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/status_tone_colors.dart';

/// Miktar girişi (şartname 29. bölüm).
///
/// Depo operasyonlarının en çok kullanılan girdisi: mal kabulde kaç adet
/// alındığı, transferde kaç adet taşındığı, sayımda kaç adet bulunduğu.
///
/// Üç giriş yolu birden sunar çünkü miktar çok değişken: 1-2 adet için
/// artı/eksi düğmeleri hızlı, 120 adet için klavye şart, "tümü" ise en sık
/// yapılan seçim (gelen malın tamamını kabul et, kalanın tamamını topla).
///
/// [max] aşıldığında değer otomatik kısılmaz — kullanıcının yazdığı sayı
/// ekranda kalır ve uyarı gösterilir. Sessizce düzeltmek, kullanıcının
/// yanlış yazdığını fark etmesini engeller.
class QuantitySelector extends StatefulWidget {
  const QuantitySelector({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.unit = 'adet',
    this.label,
    this.enabled = true,
    this.showMaxAction = true,
    this.maxActionLabel = 'Tümü',
    this.errorText,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  final int min;

  /// Üst sınır — genellikle mevcut stok veya kalan miktar.
  final int? max;

  final String unit;
  final String? label;
  final bool enabled;

  /// Değeri tek dokunuşla [max] yapan kısayolu gösterir.
  final bool showMaxAction;
  final String maxActionLabel;

  /// Dışarıdan verilen doğrulama mesajı.
  final String? errorText;

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.toString(),
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(QuantitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dışarıdan gelen değişikliği alana yansıt — ama kullanıcı yazarken
    // imleci bozmamak için yalnızca alan odakta değilken.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setValue(int next) {
    if (!widget.enabled) return;
    final int clamped = next < widget.min ? widget.min : next;
    _controller.text = clamped.toString();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final int? max = widget.max;
    final bool exceedsMax = max != null && widget.value > max;
    final String? error =
        widget.errorText ??
        (exceedsMax ? 'En fazla $max ${widget.unit} girebilirsiniz.' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: <Widget>[
            _StepButton(
              icon: AppIcons.remove,
              onPressed: widget.enabled && widget.value > widget.min
                  ? () => _setValue(widget.value - 1)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: AppTypography.metricMedium.copyWith(
                  color: error != null ? status.danger : null,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: widget.unit,
                  errorText: error,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.sm,
                  ),
                ),
                onChanged: (String text) {
                  final int parsed = int.tryParse(text) ?? widget.min;
                  widget.onChanged(parsed);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _StepButton(
              icon: AppIcons.add,
              onPressed: widget.enabled && (max == null || widget.value < max)
                  ? () => _setValue(widget.value + 1)
                  : null,
            ),
          ],
        ),
        if (widget.showMaxAction && max != null && max > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.enabled ? () => _setValue(max) : null,
              child: Text('${widget.maxActionLabel} ($max ${widget.unit})'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Miktar seçicinin artı/eksi düğmesi.
///
/// 48dp kare: eldivenli parmakla bile ıskalanmayacak boyut
/// (şartname 5. bölüm, "büyük dokunma alanları").
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool enabled = onPressed != null;

    return Material(
      color: enabled ? status.neutralContainer : status.neutralContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          child: Icon(
            icon,
            size: AppSizes.iconMd,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : status.neutral.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
