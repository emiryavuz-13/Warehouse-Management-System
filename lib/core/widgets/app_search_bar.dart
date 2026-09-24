import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_tone_colors.dart';
import '../constants/app_constants.dart';

/// Arama kutusu (şartname 31. bölüm).
///
/// Sınıf adı `SearchBar` değil: Material'ın kendi `SearchBar` widget'ıyla
/// çakışırdı.
///
/// **Neden gecikmeli:** her tuş vuruşunda repository'yi çağırmak, "iPhone"
/// yazarken altı ayrı arama başlatır ve sonuçlar sırasız dönebilir.
/// [AppConstants.searchDebounce] kadar beklenip son hal aranır.
///
/// Yanındaki filtre düğmesi etkin filtre sayısını rozet olarak gösterir;
/// kullanıcı neden az sonuç gördüğünü anlayabilmeli.
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    required this.onChanged,
    this.hintText = 'Ara...',
    this.initialValue = '',
    this.onFilterTap,
    this.activeFilterCount = 0,
    this.onScanTap,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final String initialValue;

  /// Verilirse sağda filtre düğmesi gösterilir.
  final VoidCallback? onFilterTap;

  /// Filtre düğmesindeki rozet sayısı.
  final int activeFilterCount;

  /// Verilirse arama kutusunda barkod tarama kısayolu gösterilir.
  ///
  /// Depo çalışanı ürünü yazarak aramak yerine etiketini okutmayı tercih
  /// eder (şartname 34. bölüm).
  final VoidCallback? onScanTap;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.searchDebounce, () {
      if (mounted) widget.onChanged(value.trim());
    });
    // Temizleme düğmesinin anında görünmesi/gizlenmesi için.
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool hasText = _controller.text.isNotEmpty;

    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hintText,
              isDense: true,
              prefixIcon: Icon(
                AppIcons.search,
                size: AppSizes.iconMd,
                color: status.neutral,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: Icon(AppIcons.close, size: AppSizes.iconMd),
                      onPressed: _clear,
                      tooltip: 'Temizle',
                    )
                  : (widget.onScanTap == null
                        ? null
                        : IconButton(
                            icon: Icon(AppIcons.barcode, size: AppSizes.iconMd),
                            onPressed: widget.onScanTap,
                            tooltip: 'Barkod tara',
                          )),
            ),
          ),
        ),
        if (widget.onFilterTap != null) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          _FilterButton(
            count: widget.activeFilterCount,
            onTap: widget.onFilterTap!,
          ),
        ],
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool active = count > 0;

    return Material(
      color: active ? colors.primary : status.neutralContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          child: Badge(
            isLabelVisible: active,
            label: Text('$count'),
            child: Icon(
              AppIcons.filter,
              size: AppSizes.iconMd,
              color: active ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
