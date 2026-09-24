import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../data/warehouse_exception.dart';
import '../../../models/models.dart';
import '../providers/order_providers.dart';

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
  const PickingPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<PickingPage> createState() => _PickingPageState();
}

class _PickingPageState extends ConsumerState<PickingPage> {
  int? _quantity;
  bool _isSubmitting = false;

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
        data: (OrderDetail? value) => _buildStep(value!.pickingTask!.id),
      ),
    );
  }

  Widget _buildStep(String taskId) {
    final AsyncValue<PickingStep?> step = ref.watch(
      pickingStepProvider(taskId),
    );

    return AsyncValueView<PickingStep?>(
      value: step,
      onRetry: () => ref.invalidate(pickingStepProvider(taskId)),
      loading: const LoadingIndicator(message: 'Sıradaki ürün'),
      isEmpty: (PickingStep? value) => value == null,
      // Adım kalmadıysa görev bitmiştir (şartname 14: "Sipariş toplama
      // tamamlandı ✓").
      empty: _PickingComplete(orderId: widget.orderId),
      data: (PickingStep? value) => _StepView(
        step: value!,
        quantity: _quantity ?? value.line.remainingQuantity,
        isSubmitting: _isSubmitting,
        onQuantityChanged: (int q) => setState(() => _quantity = q),
        onConfirm: () => _confirm(taskId, value),
      ),
    );
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
          );
      if (!mounted) return;

      // Sonraki adımın kendi varsayılan miktarı olmalı.
      setState(() {
        _quantity = null;
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
class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.quantity,
    required this.isSubmitting,
    required this.onQuantityChanged,
    required this.onConfirm,
  });

  final PickingStep step;
  final int quantity;
  final bool isSubmitting;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

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
                  Text(
                    '${step.stepNumber} / ${step.totalSteps}',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TaskProgressBar(
                completed: step.stepNumber - 1,
                total: step.totalSteps,
                showCount: false,
              ),

              const SizedBox(height: AppSpacing.xl),

              // --- Gidilecek raf: ekranın en büyük öğesi ---
              Text(
                'GİT VE AL',
                style: AppTypography.overline.copyWith(color: status.neutral),
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
                      step.location.code,
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
                    value: Formatters.integer.format(step.availableStock),
                    sublabel: step.product.unit,
                    tone: step.hasEnoughStock ? null : StatusTone.danger,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              QuantitySelector(
                label: 'Alınan miktar',
                value: quantity,
                min: 1,
                // Rafta olandan ya da siparişte kalandan fazlası alınamaz.
                max: step.availableStock < step.line.remainingQuantity
                    ? step.availableStock
                    : step.line.remainingQuantity,
                unit: step.product.unit,
                maxActionLabel: 'Tümü',
                onChanged: onQuantityChanged,
              ),

              if (!step.hasEnoughStock) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _ShortStockNotice(step: step),
              ],
            ],
          ),
        ),
        BottomActionBar(
          children: <Widget>[
            // Barkod doğrulama: depo çalışanı doğru ürünü aldığını
            // etiketi okutarak teyit eder (şartname 14. bölüm).
            SecondaryButton(
              label: 'Barkod Tara',
              icon: AppIcons.scan,
              onPressed: () => context.go(AppRoutes.scan),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Toplamayı Onayla',
              icon: AppIcons.confirm,
              isLoading: isSubmitting,
              onPressed: isSubmitting || quantity <= 0 ? null : onConfirm,
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
  const _ShortStockNotice({required this.step});

  final PickingStep step;

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
              '${step.location.code} rafında ${step.availableStock} adet var, '
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
              onPressed: () => context.push(AppRoutes.shipments),
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
