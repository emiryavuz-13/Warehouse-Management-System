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
import '../../scan/presentation/widgets/barcode_verify_sheet.dart';
import '../../shipments/presentation/widgets/ship_action.dart';
import '../providers/order_providers.dart';
import 'widgets/picking_sheets.dart';

/// Toplama görevi (şartname 14. bölüm).
///
/// *"Bu ekran depo çalışanının operasyonel ekranı gibi tasarlanmalıdır."*
///
/// Bu cümle ekranın tamamını belirledi:
///
/// - **Tek seferde tek ürün.** Depo çalışanı elinde telefonla koridorda
///   yürüyor; liste değil talimat istiyor. `1 / 3` sayacı nerede olduğunu,
///   büyük lokasyon kodu nereye gideceğini söylüyor.
/// - **Lokasyon en büyük öğe.** Ürün adı değil, gidilecek raf. `A-01-01` ile
///   `A-01-11` normal yazıyla birbirine benzer; kod monospace ve iri.
/// - **Miktar ayarlanabilir ama varsayılan tam miktar.** Rafta eksik mal
///   olabilir, ama olağan durum istenen kadarını almaktır.
///
/// Her onayda (şartname 14. bölüm) stok azalır, hareket oluşur, sipariş
/// durumu güncellenir ve kullanıcı sonraki ürüne ilerler.
class PickingPage extends ConsumerStatefulWidget {
  const PickingPage({required this.orderId, this.initialLineIndex, super.key});

  final String orderId;

  /// Ekranın açılacağı kalem. Sipariş detayındaki "Topla" düğmesi bunu
  /// doldurur; boşsa sıradaki tamamlanmamış kalem gösterilir.
  final int? initialLineIndex;

  @override
  ConsumerState<PickingPage> createState() => _PickingPageState();
}

class _PickingPageState extends ConsumerState<PickingPage> {
  int? _quantity;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _stepIndex = widget.initialLineIndex;
  }

  /// Bu adımda barkodu okutulup doğrulanan ürün.
  ///
  /// Adım numarası değil ürün kimliği tutuluyor: sonraki adıma geçildiğinde
  /// doğrulama kendiliğinden düşsün, çalışan her ürünü ayrı okutsun.
  String? _verifiedProductId;

  /// Kullanıcının elle seçtiği adım. `null` ise sıradaki adım gösterilir.
  ///
  /// Toplama bir öneri sırasıdır, zorunluluk değil: çalışan deponun içinde
  /// yürürken yanından geçtiği rafa uğramak isteyebilir.
  int? _stepIndex;

  /// Kullanıcının elle seçtiği kaynak raf. `null` ise satırın önerdiği raf.
  String? _sourceLocationId;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OrderDetail?> detail = ref.watch(
      orderDetailProvider(widget.orderId),
    );
    final PickingTask? task = detail.value?.pickingTask;

    return Scaffold(
      appBar: AppBar(
        title: Text(task == null ? 'Toplama' : 'Görev ${task.code}'),
      ),
      body: AsyncValueView<OrderDetail?>(
        value: detail,
        onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        loading: const LoadingIndicator(message: 'Görev yükleniyor'),
        isEmpty: (OrderDetail? value) =>
            value == null || value.pickingTask == null,
        empty: const EmptyState(
          icon: AppIcons.picking,
          title: 'Toplama görevi yok',
          message: 'Bu sipariş için henüz bir görev açılmamış.',
        ),
        data: (OrderDetail? value) =>
            _buildStep(value!.pickingTask!, value.pickingTask!.id),
      ),
    );
  }

  Widget _buildStep(PickingTask task, String taskId) {
    // Geçersiz bir sıra numarası (elle yazılmış adres) görevi tamamlanmış
    // gibi göstermemeli; böyle bir durumda sıradaki kaleme düşülür.
    final int? requested = _stepIndex;
    final PickingStepQuery query = PickingStepQuery(
      taskId: taskId,
      lineIndex:
          requested != null && requested >= 0 && requested < task.lines.length
          ? requested
          : null,
    );
    final AsyncValue<PickingStep?> step = ref.watch(pickingStepProvider(query));

    return AsyncValueView<PickingStep?>(
      value: step,
      onRetry: () => ref.invalidate(pickingStepProvider(query)),
      loading: const LoadingIndicator(message: 'Sıradaki ürün'),
      isEmpty: (PickingStep? value) => value == null,
      // Adım kalmadıysa görev bitmiştir (şartname 14: "Sipariş toplama
      // tamamlandı ✓").
      empty: _PickingComplete(orderId: widget.orderId),
      data: (PickingStep? value) => _StepView(
        step: value!,
        // Tamamlanmış bir kaleme dönüldüğünde kalan sıfırdır; onay
        // düğmesi de kapalı gelir, çalışan yalnızca ne aldığına bakar.
        quantity: _quantity ?? value.line.remainingQuantity,
        sourceLocationId: _sourceLocationId ?? value.line.locationId,
        isSubmitting: _isSubmitting,
        isVerified: _verifiedProductId == value.product.id,
        onQuantityChanged: (int q) => setState(() => _quantity = q),
        onVerify: () => _verify(value),
        onPickStep: () => _chooseStep(task, value),
        onPickLocation: () => _chooseLocation(value),
        onConfirm: () => _confirm(taskId, value),
      ),
    );
  }

  /// Görevdeki kalemler arasında gezinme.
  Future<void> _chooseStep(PickingTask task, PickingStep step) async {
    final int? index = await PickingStepsSheet.show(
      context: context,
      task: task,
      currentIndex: step.stepNumber - 1,
    );
    if (index == null || !mounted) return;

    setState(() {
      _stepIndex = index;
      // Yeni kalemin kendi miktarı, kendi rafı, kendi doğrulaması olmalı.
      _quantity = null;
      _sourceLocationId = null;
      _verifiedProductId = null;
    });
  }

  /// Kaynak raf seçimi — ürün birden fazla rafta duruyorsa.
  Future<void> _chooseLocation(PickingStep step) async {
    final ProductStockSummary? summary = await ref.read(
      productSummaryProvider(step.product.id).future,
    );
    if (summary == null || !mounted) return;

    final String? locationId = await PickingLocationSheet.show(
      context: context,
      summary: summary,
      selectedLocationId: _sourceLocationId ?? step.line.locationId,
      quantity: _quantity ?? step.line.remainingQuantity,
    );
    if (locationId == null || !mounted) return;

    setState(() => _sourceLocationId = locationId);
  }

  /// Barkod doğrulama paneli (şartname 14. bölüm).
  ///
  /// Doğrulama zorunlu değil: çalışan okutmadan da onaylayabilir, depoda
  /// kamera bozuk olabilir ve iş durmamalı. Okuttuysa yanlış ürünü almasına
  /// izin verilmez — panel eşleşmeden kapanmaz.
  Future<void> _verify(PickingStep step) async {
    final bool? verified = await BarcodeVerifySheet.show(
      context: context,
      expected: step.product,
    );
    if (verified != true || !mounted) return;

    setState(() => _verifiedProductId = step.product.id);
  }

  Future<void> _confirm(String taskId, PickingStep step) async {
    final int quantity = _quantity ?? step.line.remainingQuantity;
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(warehouseActionsProvider)
          .pickLine(
            taskId: taskId,
            productId: step.product.id,
            quantity: quantity,
            locationId: _sourceLocationId,
          );
      if (!mounted) return;

      // Elle seçilmiş adım bırakılır: onaydan sonra sıradaki tamamlanmamış
      // kaleme dönülür. Sonraki adımın kendi miktarı, rafı ve doğrulaması
      // olmalı.
      setState(() {
        _stepIndex = null;
        _quantity = null;
        _sourceLocationId = null;
        _verifiedProductId = null;
        _isSubmitting = false;
      });
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

/// Şartnamenin toplama adımı ekranı.
class _StepView extends ConsumerWidget {
  const _StepView({
    required this.step,
    required this.quantity,
    required this.sourceLocationId,
    required this.isSubmitting,
    required this.isVerified,
    required this.onQuantityChanged,
    required this.onVerify,
    required this.onPickStep,
    required this.onPickLocation,
    required this.onConfirm,
  });

  final PickingStep step;
  final int quantity;

  /// Seçili kaynak raf — satırın önerdiğinden farklı olabilir.
  final String sourceLocationId;

  final bool isSubmitting;
  final bool isVerified;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onVerify;
  final VoidCallback onPickStep;
  final VoidCallback onPickLocation;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final ProductStockSummary? summary = ref
        .watch(productSummaryProvider(step.product.id))
        .value;
    final List<LocationStock> locations =
        summary?.locations ?? const <LocationStock>[];

    // Seçili rafın kodu ve oradaki stok; kullanıcı raf değiştirdiğinde
    // "Rafta" sayısı da onunla değişmeli.
    final LocationStock? source = locations
        .where((LocationStock l) => l.location.id == sourceLocationId)
        .firstOrNull;
    final String locationCode = source?.location.code ?? step.location.code;
    final int availableHere = source?.quantity ?? step.availableStock;
    final bool isMultiLocation = locations.length > 1;
    final bool isDone = step.line.isCompleted;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: <Widget>[
              // --- İlerleme: "1 / 3" ---
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Sipariş #${step.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                  ),
                  // Adım göstergesi bir düğme: çalışan istediği kaleme
                  // atlayabilmeli, sıra bir öneridir.
                  InkWell(
                    onTap: onPickStep,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${step.stepNumber} / ${step.totalSteps}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: colors.primary),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            AppIcons.expand,
                            size: AppSizes.iconSm,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // İlerleme adım numarasını değil **toplanan kalem sayısını**
              // gösterir: çalışan kalemler arasında gezinebildiği için bu
              // ikisi artık aynı şey değil.
              TaskProgressBar(
                completed: step.task.completedLineCount,
                total: step.totalSteps,
                showCount: false,
              ),

              const SizedBox(height: AppSpacing.xl),

              // --- Gidilecek raf: ekranın en büyük öğesi ---
              Row(
                children: <Widget>[
                  Text(
                    'GİT VE AL',
                    style: AppTypography.overline.copyWith(
                      color: status.neutral,
                    ),
                  ),
                  const Spacer(),
                  // Ürün birden fazla raftaysa çalışan hangisinden aldığını
                  // seçebilmeli: önerilen raf kapalı, dolu ya da uzakta
                  // olabilir.
                  if (isMultiLocation)
                    TextButton(
                      onPressed: onPickLocation,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('Başka raf (${locations.length})'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    step.location.type.icon,
                    size: 28,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      locationCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.code.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              Divider(height: 1, color: status.border),
              const SizedBox(height: AppSpacing.lg),

              // --- Ürün ---
              Text(
                step.product.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Flexible(child: CodeChip(code: step.product.sku)),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: CodeChip(
                      code: step.product.barcode,
                      icon: AppIcons.barcode,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              StatRow(
                blocks: <Widget>[
                  StatBlock(
                    label: 'İstenen',
                    value: Formatters.integer.format(
                      step.line.requestedQuantity,
                    ),
                    sublabel: step.product.unit,
                  ),
                  StatBlock(
                    label: 'Toplanan',
                    value: Formatters.integer.format(step.line.pickedQuantity),
                    sublabel: step.product.unit,
                  ),
                  StatBlock(
                    label: 'Rafta',
                    value: Formatters.integer.format(availableHere),
                    sublabel: step.product.unit,
                    tone: availableHere >= step.line.remainingQuantity
                        ? null
                        : StatusTone.danger,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              QuantitySelector(
                label: 'Alınan miktar',
                value: quantity,
                min: 1,
                // Rafta olandan ya da siparişte kalandan fazlası alınamaz.
                max: availableHere < step.line.remainingQuantity
                    ? availableHere
                    : step.line.remainingQuantity,
                enabled: !isDone,
                unit: step.product.unit,
                maxActionLabel: 'Tümü',
                onChanged: onQuantityChanged,
              ),

              if (isDone) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _AlreadyPickedNotice(step: step),
              ] else if (availableHere < step.line.remainingQuantity) ...[
                const SizedBox(height: AppSpacing.md),
                _ShortStockNotice(
                  step: step,
                  locationCode: locationCode,
                  available: availableHere,
                ),
              ],
            ],
          ),
        ),
        BottomActionBar(
          children: <Widget>[
            // Barkod doğrulama: depo çalışanı doğru ürünü aldığını
            // etiketi okutarak teyit eder (şartname 14. bölüm). Panel
            // açılır, sayfa değişmez — çalışan adımda kalır.
            if (isDone)
              const SizedBox.shrink()
            else if (isVerified)
              BarcodeVerifiedBanner(product: step.product)
            else
              SecondaryButton(
                label: 'Barkod Doğrula',
                icon: AppIcons.scan,
                onPressed: onVerify,
              ),
            if (!isDone) const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: isDone ? 'Bu kalem toplandı' : 'Toplamayı Onayla',
              icon: AppIcons.confirm,
              isLoading: isSubmitting,
              onPressed: isSubmitting || isDone || quantity <= 0
                  ? null
                  : onConfirm,
            ),
          ],
        ),
      ],
    );
  }
}

/// Rafta yeterli mal yoksa uyarı.
///
/// Toplama engellenmez: çalışan bulduğu kadarını alır, kalan eksik olarak
/// kayda geçer. Depoda beklemek bir seçenek değildir.
class _ShortStockNotice extends StatelessWidget {
  const _ShortStockNotice({
    required this.step,
    required this.locationCode,
    required this.available,
  });

  final PickingStep step;
  final String locationCode;
  final int available;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: status.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            StatusTone.danger.icon,
            size: AppSizes.iconSm,
            color: status.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$locationCode rafında $available adet var, '
              '${step.line.remainingQuantity} gerekiyor. '
              'Bulduğunuz kadarını alın.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tamamlanmış bir kaleme gidildiğinde gösterilen bilgi.
///
/// Çalışan ne aldığını gözden geçirmek için geri dönebilmeli; o adımda
/// onay düğmesi kapalı olur.
class _AlreadyPickedNotice extends StatelessWidget {
  const _AlreadyPickedNotice({required this.step});

  final PickingStep step;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: status.successContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(AppIcons.confirm, size: AppSizes.iconSm, color: status.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Bu kalem toplandı: ${step.line.pickedQuantity} '
              '${step.product.unit}. Başka bir kaleme geçmek için '
              'üstteki adım sayısına dokunun.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: status.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Şartname 14. bölüm: "Sipariş toplama tamamlandı ✓ ... [ Sevkiyata Geç ]".
class _PickingComplete extends ConsumerWidget {
  const _PickingComplete({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final OrderDetail? detail = ref.watch(orderDetailProvider(orderId)).value;

    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: status.successContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.confirm,
                      size: 36,
                      color: status.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Sipariş toplama tamamlandı',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sipariş #${detail.order.orderNumber} · '
                      '${detail.order.customerName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: status.neutral),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    StatRow(
                      blocks: <Widget>[
                        StatBlock(
                          label: 'Çeşit',
                          value: '${detail.order.lineCount}',
                          sublabel: 'ürün',
                        ),
                        StatBlock(
                          label: 'Toplanan',
                          value: Formatters.integer.format(
                            detail.order.pickedQuantity,
                          ),
                          sublabel: 'adet',
                          tone: StatusTone.success,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        BottomActionBar(
          children: <Widget>[
            PrimaryButton(
              label: 'Sevkiyata Geç',
              icon: AppIcons.shipment,
              onPressed: () => openShipmentForOrder(
                context: context,
                ref: ref,
                orderId: orderId,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Siparişe Dön',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ],
    );
  }
}
