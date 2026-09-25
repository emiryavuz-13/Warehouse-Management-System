import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../data/warehouse_exception.dart';
import '../../../models/models.dart';
import '../providers/transfer_providers.dart';
import 'widgets/product_picker_sheet.dart';

/// Stok transferi (şartname 15. bölüm).
///
/// Şartnamenin akışı: ürün → kaynak lokasyon → hedef lokasyon → miktar →
/// onay. Dördü de tek ekranda, yerleştirme ekranındaki gerekçeyle: adımlar
/// birbirini kısıtlıyor ve kullanıcı bir seçimi değiştirmek için geri
/// dönmek zorunda kalmamalı.
///
/// **Mal kabulden farkı toplamın değişmemesi.** Kabul depoya dışarıdan mal
/// sokar; transfer yalnızca yerini değiştirir. Bu yüzden ekranın vaadi bir
/// hero sayı değil, iki lokasyonun **öncesi ve sonrası**: şartnamenin
/// istediği `A-01-01: 18 → 13` / `B-03-02: 6 → 11` çıktısı. Onaydan önce de
/// gösteriliyor — kullanıcı sonucu işlemden sonra öğrenmemeli.
class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({this.initialProductId, super.key});

  /// Ürün detayından, stok listesinden ya da tarama sonucundan gelindiğinde
  /// ürün önceden seçili açılır.
  final String? initialProductId;

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  String? _productId;
  String? _sourceId;
  String? _targetId;
  int _quantity = 1;
  bool _isSubmitting = false;

  /// Hedef listesi on dört satır uzunluğunda; seçim yapıldıktan sonra açık
  /// bırakmak miktar adımını ekranın çok altına itiyordu. Seçimden sonra
  /// yalnızca seçili raf kalır, "Değiştir" listeyi geri açar.
  bool _targetListOpen = true;

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialProductId;
    _productId = (initial == null || initial.isEmpty) ? null : initial;
  }

  @override
  Widget build(BuildContext context) {
    final String? productId = _productId;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Transferi')),
      body: productId == null
          ? _EmptyProductState(onPick: _pickProduct)
          : _TransferForm(
              productId: productId,
              sourceId: _sourceId,
              targetId: _targetId,
              quantity: _quantity,
              onPickProduct: _pickProduct,
              onSourceSelected: _selectSource,
              targetListOpen: _targetListOpen,
              onTargetSelected: (String id) => setState(() {
                _targetId = id;
                _targetListOpen = false;
              }),
              onToggleTargetList: () =>
                  setState(() => _targetListOpen = !_targetListOpen),
              onQuantityChanged: _setQuantity,
            ),
      bottomNavigationBar: productId == null
          ? null
          : _buildActions(productId),
    );
  }

  Future<void> _pickProduct() async {
    final ProductStockSummary? picked = await ProductPickerSheet.show(context);
    if (picked == null || !mounted) return;

    setState(() {
      _productId = picked.product.id;
      // Ürün değişince eski lokasyon seçimleri anlamsızlaşır.
      _sourceId = null;
      _targetId = null;
      _targetListOpen = true;
      _quantity = 1;
    });
  }

  void _selectSource(String id, int available) {
    setState(() {
      _sourceId = id;
      // Kaynak, hedef listesinden çıkarılır; aynı raf seçiliyse temizlenir.
      if (_targetId == id) {
        _targetId = null;
        _targetListOpen = true;
      }
      // Miktar yeni kaynağın stoğunu aşamaz.
      if (_quantity > available) _quantity = available;
      if (_quantity < 1) _quantity = 1;
    });
  }

  /// Miktar artınca seçili hedefin kapasitesi yetmeyebilir; seçimi orada
  /// bırakmak kullanıcıyı onaydan sonra bir hata mesajına gönderirdi.
  void _setQuantity(int value) {
    final List<TransferTarget> targets =
        ref
            .read(
              targetLocationsProvider(
                TransferTargetQuery(
                  productId: _productId!,
                  sourceLocationId: _sourceId,
                ),
              ),
            )
            .value ??
        const <TransferTarget>[];
    final TransferTarget? selected = targets
        .where((TransferTarget t) => t.summary.location.id == _targetId)
        .firstOrNull;

    setState(() {
      _quantity = value;
      if (selected != null && !selected.fits(value)) {
        _targetId = null;
        _targetListOpen = true;
      }
    });
  }

  Widget _buildActions(String productId) {
    final bool canSubmit =
        _sourceId != null &&
        _targetId != null &&
        _quantity > 0 &&
        !_isSubmitting;

    return BottomActionBar(
      children: <Widget>[
        PrimaryButton(
          // Şartnamedeki etiket birebir.
          label: 'Transferi Başlat',
          icon: AppIcons.transfer,
          isLoading: _isSubmitting,
          onPressed: canSubmit ? () => _submit(productId) : null,
        ),
      ],
    );
  }

  Future<void> _submit(String productId) async {
    final ProductStockSummary? summary = ref
        .read(productSummaryProvider(productId))
        .value;
    if (summary == null) return;

    final LocationStock? source = summary.locations
        .where((LocationStock l) => l.location.id == _sourceId)
        .firstOrNull;
    final List<TransferTarget> targets =
        ref
            .read(
              targetLocationsProvider(
                TransferTargetQuery(
                  productId: productId,
                  sourceLocationId: _sourceId,
                ),
              ),
            )
            .value ??
        const <TransferTarget>[];
    final TransferTarget? target = targets
        .where((TransferTarget t) => t.summary.location.id == _targetId)
        .firstOrNull;
    if (source == null || target == null) return;

    final String unit = summary.product.unit;
    final int sourceBefore = source.quantity;
    final int targetBefore = summary.locations
        .where((LocationStock l) => l.location.id == _targetId)
        .fold(0, (int sum, LocationStock l) => sum + l.quantity);

    final bool confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Transferi onayla',
      message: '${summary.product.name} rafa taşınacak.',
      confirmLabel: 'Transfer Et',
      details: <ConfirmationDetail>[
        ConfirmationDetail(
          label: 'Miktar',
          value: Formatters.quantity(_quantity, unit),
        ),
        ConfirmationDetail(
          label: 'Kaynak',
          value: '${source.location.code}  '
              '$sourceBefore → ${sourceBefore - _quantity}',
        ),
        ConfirmationDetail(
          label: 'Hedef',
          value: '${target.summary.location.code}  '
              '$targetBefore → ${targetBefore + _quantity}',
        ),
      ],
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(warehouseActionsProvider)
          .transferStock(
            productId: productId,
            sourceLocationId: source.location.id,
            targetLocationId: target.summary.location.id,
            quantity: _quantity,
          );
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      await SuccessDialog.show(
        context: context,
        title: 'Transfer tamamlandı',
        message:
            '${Formatters.quantity(_quantity, unit)} '
            '${source.location.code} rafından '
            '${target.summary.location.code} rafına taşındı.',
        // Şartnamenin istediği çıktı: iki lokasyonun öncesi ve sonrası.
        details: <ConfirmationDetail>[
          ConfirmationDetail(
            label: source.location.code,
            value: '$sourceBefore → ${sourceBefore - _quantity}',
          ),
          ConfirmationDetail(
            label: target.summary.location.code,
            value: '$targetBefore → ${targetBefore + _quantity}',
          ),
        ],
      );
      if (!mounted) return;
      context.pop();
    } on WarehouseException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).status.danger,
        ),
      );
    }
  }
}

/// Ürün seçilmeden önceki hal.
///
/// Boş bir form göstermek yerine tek bir işi öne çıkarır: dashboard'dan
/// "Transfer"e basan kullanıcının önce bir ürün seçmesi gerekir.
class _EmptyProductState extends StatelessWidget {
  const _EmptyProductState({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.transfer,
      title: 'Hangi ürünü taşıyacaksınız?',
      message: 'Transfer için önce bir ürün seçin. '
          'Yalnızca stoğu olan ürünler listelenir.',
      actionLabel: 'Ürün Seç',
      onAction: onPick,
    );
  }
}

class _TransferForm extends ConsumerWidget {
  const _TransferForm({
    required this.productId,
    required this.sourceId,
    required this.targetId,
    required this.quantity,
    required this.targetListOpen,
    required this.onPickProduct,
    required this.onSourceSelected,
    required this.onTargetSelected,
    required this.onToggleTargetList,
    required this.onQuantityChanged,
  });

  final String productId;
  final String? sourceId;
  final String? targetId;
  final int quantity;
  final bool targetListOpen;
  final VoidCallback onPickProduct;
  final void Function(String locationId, int available) onSourceSelected;
  final ValueChanged<String> onTargetSelected;
  final VoidCallback onToggleTargetList;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProductStockSummary?> summary = ref.watch(
      productSummaryProvider(productId),
    );

    return AsyncValueView<ProductStockSummary?>(
      value: summary,
      onRetry: () => ref.invalidate(productSummaryProvider(productId)),
      loading: const LoadingIndicator(message: 'Ürün yükleniyor'),
      isEmpty: (ProductStockSummary? value) => value == null,
      empty: const EmptyState(
        title: 'Ürün bulunamadı',
        message: 'Bu ürün kayıtlarda yok.',
      ),
      data: (ProductStockSummary? value) => _Body(
        summary: value!,
        sourceId: sourceId,
        targetId: targetId,
        quantity: quantity,
        targetListOpen: targetListOpen,
        onPickProduct: onPickProduct,
        onSourceSelected: onSourceSelected,
        onTargetSelected: onTargetSelected,
        onToggleTargetList: onToggleTargetList,
        onQuantityChanged: onQuantityChanged,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.summary,
    required this.sourceId,
    required this.targetId,
    required this.quantity,
    required this.targetListOpen,
    required this.onPickProduct,
    required this.onSourceSelected,
    required this.onTargetSelected,
    required this.onToggleTargetList,
    required this.onQuantityChanged,
  });

  final ProductStockSummary summary;
  final String? sourceId;
  final String? targetId;
  final int quantity;
  final bool targetListOpen;
  final VoidCallback onPickProduct;
  final void Function(String locationId, int available) onSourceSelected;
  final ValueChanged<String> onTargetSelected;
  final VoidCallback onToggleTargetList;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final Product product = summary.product;

    final LocationStock? source = summary.locations
        .where((LocationStock l) => l.location.id == sourceId)
        .firstOrNull;

    final AsyncValue<List<TransferTarget>> targets = ref.watch(
      targetLocationsProvider(
        TransferTargetQuery(
          productId: product.id,
          sourceLocationId: sourceId,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        // --- 1. Ürün ---
        _StepHeader(step: 1, title: 'Ürün'),
        InkWell(
          onTap: onPickProduct,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                AppIconBox(
                  icon: categoryIcon(summary.category?.iconKey ?? ''),
                  size: 44,
                  iconSize: 20,
                  background: status.neutralContainer,
                  foreground: status.neutral,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.sku} · '
                        '${Formatters.quantity(summary.totalQuantity, product.unit)} '
                        'toplam',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.code.copyWith(
                          fontSize: 11.5,
                          color: status.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Değiştir',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        // --- 2. Kaynak lokasyon ---
        _StepHeader(
          step: 2,
          title: 'Kaynak Lokasyon',
          subtitle: 'Ürünün bulunduğu raflar',
        ),
        if (summary.locations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Bu ürün hiçbir lokasyonda kayıtlı değil, transfer edilemez.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          )
        else
          for (int i = 0; i < summary.locations.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: status.border),
            _SourceOption(
              // Aynı raf kodu hem kaynak hem hedef listesinde görünebilir;
              // anahtar ikisini birbirinden ayırır.
              key: ValueKey<String>(
                'source-${summary.locations[i].location.id}',
              ),
              stock: summary.locations[i],
              unit: product.unit,
              isSelected: sourceId == summary.locations[i].location.id,
              onSelected: () => onSourceSelected(
                summary.locations[i].location.id,
                summary.locations[i].quantity,
              ),
            ),
          ],

        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        // --- 3. Hedef lokasyon ---
        _StepHeader(
          step: 3,
          title: 'Hedef Lokasyon',
          subtitle: source == null
              ? 'Önce kaynak seçin'
              : '$quantity ${product.unit} sığacak raflar',
        ),
        if (source == null)
          const SizedBox(height: AppSpacing.sm)
        else
          AsyncValueView<List<TransferTarget>>(
            compactError: true,
            value: targets,
            onRetry: () => ref.invalidate(
              targetLocationsProvider(
                TransferTargetQuery(
                  productId: product.id,
                  sourceLocationId: sourceId,
                ),
              ),
            ),
            loading: const LoadingState(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('Lokasyonlar yükleniyor'),
              ),
            ),
            data: (List<TransferTarget> items) {
              // Seçim yapıldıysa yalnızca seçili raf gösterilir.
              final List<TransferTarget> visible = targetListOpen
                  ? items
                  : items
                        .where(
                          (TransferTarget t) =>
                              t.summary.location.id == targetId,
                        )
                        .toList();

              return Column(
                children: <Widget>[
                  for (int i = 0; i < visible.length; i++) ...<Widget>[
                    if (i > 0) Divider(height: 1, color: status.border),
                    _TargetOption(
                      key: ValueKey<String>(
                        'target-${visible[i].summary.location.id}',
                      ),
                      target: visible[i],
                      quantity: quantity,
                      isSelected: targetId == visible[i].summary.location.id,
                      onSelected: () =>
                          onTargetSelected(visible[i].summary.location.id),
                    ),
                  ],
                  if (!targetListOpen)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onToggleTargetList,
                        child: Text('Başka raf seç (${items.length - 1})'),
                      ),
                    ),
                ],
              );
            },
          ),

        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        // --- 4. Miktar ---
        _StepHeader(
          step: 4,
          title: 'Miktar',
          subtitle: source == null
              ? 'Önce kaynak seçin'
              : '${source.location.code} rafında '
                    '${Formatters.quantity(source.quantity, product.unit)} var',
        ),
        QuantitySelector(
          value: quantity,
          min: 1,
          // Kaynaktaki stok üst sınır: negatif stok oluşamaz
          // (şartname 26. bölüm).
          max: source?.quantity,
          unit: product.unit,
          enabled: source != null,
          onChanged: onQuantityChanged,
        ),

        // Şartnamenin istediği "A-01-01: 18 → 13 / B-03-02: 6 → 11" çıktısı,
        // işlemden önce. Kullanıcı sonucu onaylamadan görebilmeli.
        if (source != null && targetId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          _TransferPreview(
            summary: summary,
            source: source,
            targetCode: targets.value
                ?.where(
                  (TransferTarget t) => t.summary.location.id == targetId,
                )
                .map((TransferTarget t) => t.summary.location.code)
                .firstOrNull,
            targetId: targetId!,
            quantity: quantity,
          ),
        ],
      ],
    );
  }
}

/// Adım başlığı — akışın neresinde olunduğunu gösterir.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, this.subtitle});

  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.neutralContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: AppTypography.overline.copyWith(color: status.neutral),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.stock,
    required this.unit,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  final LocationStock stock;
  final String unit;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onSelected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              isSelected ? AppIcons.radioSelected : AppIcons.radioUnselected,
              size: AppSizes.iconMd,
              color: isSelected ? colors.primary : status.neutral,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                stock.location.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.code.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              Formatters.quantity(stock.quantity, unit),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetOption extends StatelessWidget {
  const _TargetOption({
    required this.target,
    required this.quantity,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  final TransferTarget target;
  final int quantity;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final LocationSummary summary = target.summary;
    final bool fits = target.fits(quantity);

    return InkWell(
      onTap: fits ? onSelected : null,
      child: Opacity(
        opacity: fits ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isSelected
                      ? AppIcons.radioSelected
                      : AppIcons.radioUnselected,
                  size: AppSizes.iconMd,
                  color: isSelected ? colors.primary : status.neutral,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            summary.location.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.code.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (target.alreadyHoldsProduct)
                          const StatusBadge(
                            label: 'Ürün burada',
                            tone: StatusTone.info,
                            compact: true,
                            showIcon: false,
                          )
                        else if (!fits)
                          const StatusBadge(
                            label: 'Yer yok',
                            tone: StatusTone.danger,
                            compact: true,
                            showIcon: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        summary.zone?.name ?? 'Bölge tanımsız',
                        '${summary.skuCount} ürün',
                        '${summary.availableCapacity} boş',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OccupancyBar(
                      used: summary.usedQuantity,
                      capacity: summary.location.capacity,
                      showLabels: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İşlem öncesi sonuç önizlemesi (şartname 15. bölüm).
///
/// Şartname bu çıktıyı işlem **sonrası** için istiyor. Öncesinde de
/// göstermek daha doğru: transfer geri alınamaz bir işlem ve kullanıcı
/// "5 adet yeterli mi" sorusunu onaylamadan önce cevaplayabilmeli.
class _TransferPreview extends StatelessWidget {
  const _TransferPreview({
    required this.summary,
    required this.source,
    required this.targetId,
    required this.targetCode,
    required this.quantity,
  });

  final ProductStockSummary summary;
  final LocationStock source;
  final String targetId;
  final String? targetCode;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    final int targetBefore = summary.locations
        .where((LocationStock l) => l.location.id == targetId)
        .fold(0, (int sum, LocationStock l) => sum + l.quantity);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: status.neutralContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TRANSFER SONRASI',
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(height: AppSpacing.md),
          _PreviewRow(
            code: source.location.code,
            before: source.quantity,
            after: source.quantity - quantity,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewRow(
            code: targetCode ?? '—',
            before: targetBefore,
            after: targetBefore + quantity,
          ),
          const SizedBox(height: AppSpacing.md),
          // Toplamın değişmediğini söylemek transferin ne olduğunu anlatır:
          // mal depodan çıkmıyor, yeri değişiyor.
          Text(
            'Toplam stok değişmez: '
            '${Formatters.quantity(summary.totalQuantity, summary.product.unit)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.code,
    required this.before,
    required this.after,
  });

  final String code;
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool isDecrease = after < before;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.code.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$before',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: status.neutral),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(AppIcons.forward, size: 13, color: status.neutral),
        ),
        Text(
          '$after',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDecrease ? status.warning : status.success,
          ),
        ),
      ],
    );
  }
}
