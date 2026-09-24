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
import '../providers/shipment_providers.dart';

/// Sevkiyat detayı (şartname 17. bölüm).
///
/// Şartnamenin istediği yedi alan burada: sipariş numarası, müşteri, paket
/// sayısı, ürünler, toplam adet, sevk durumu ve sevk tarihi.
///
/// **Sevk stok hareketi üretmez.** Mal zaten toplama sırasında raftan
/// düşmüştür; ikinci bir hareket aynı malın iki kez çıkmış görünmesine yol
/// açardı. Bu yüzden ekran bir "işlem" değil bir **onay** ekranı gibi
/// tasarlandı: sayılar değişmez, durum değişir.
class ShipmentDetailPage extends ConsumerStatefulWidget {
  const ShipmentDetailPage({required this.shipmentId, super.key});

  final String shipmentId;

  @override
  ConsumerState<ShipmentDetailPage> createState() =>
      _ShipmentDetailPageState();
}

class _ShipmentDetailPageState extends ConsumerState<ShipmentDetailPage> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ShipmentDetail?> detail = ref.watch(
      shipmentDetailProvider(widget.shipmentId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.shipment.code ?? 'Sevkiyat'),
      ),
      body: AsyncValueView<ShipmentDetail?>(
        value: detail,
        onRetry: () =>
            ref.invalidate(shipmentDetailProvider(widget.shipmentId)),
        loading: const LoadingIndicator(message: 'Sevkiyat yükleniyor'),
        isEmpty: (ShipmentDetail? value) => value == null,
        empty: const EmptyState(
          icon: AppIcons.shipment,
          title: 'Sevkiyat bulunamadı',
          message: 'Bu sevkiyat kaydı sistemde yok.',
        ),
        data: (ShipmentDetail? value) => _Body(detail: value!),
      ),
      bottomNavigationBar: detail.value == null
          ? null
          : _buildActions(detail.value!),
    );
  }

  Widget? _buildActions(ShipmentDetail detail) {
    final Shipment shipment = detail.shipment;

    // Sevk edilmiş kayıtta yapılacak bir şey yok (şartname 26: sevk edilen
    // sipariş yeniden sevk edilemez). Buton gizlenir, durum yukarıda yazar.
    if (shipment.status.isShipped) return null;

    final bool isPicked = detail.order.isFullyPicked;

    return BottomActionBar(
      children: <Widget>[
        PrimaryButton(
          label: 'Sevk Et',
          icon: AppIcons.shipment,
          isLoading: _isSubmitting,
          // Şartname 26: picking tamamlanmadan sevk edilemez.
          onPressed: isPicked && !_isSubmitting ? () => _ship(detail) : null,
        ),
        if (!isPicked) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sipariş tamamen toplanmadan sevk edilemez '
            '(${detail.order.pickedQuantity} / ${detail.order.totalQuantity}).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).status.danger),
          ),
        ],
      ],
    );
  }

  Future<void> _ship(ShipmentDetail detail) async {
    final Shipment shipment = detail.shipment;
    final SalesOrder order = detail.order;

    final bool confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sevkiyatı onayla',
      message: 'Sipariş ${shipment.carrier} ile sevk edilecek ve '
          'durumu "Sevk Edildi" olacak.',
      confirmLabel: 'Sevk Et',
      details: <ConfirmationDetail>[
        ConfirmationDetail(label: 'Sipariş', value: '#${order.orderNumber}'),
        ConfirmationDetail(label: 'Müşteri', value: order.customerName),
        ConfirmationDetail(
          label: 'Paket',
          value: '${shipment.packageCount} paket · '
              '${Formatters.quantity(detail.totalQuantity, 'adet')}',
        ),
      ],
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(warehouseActionsProvider).shipOrder(widget.shipmentId);
      if (!mounted) return;

      final ShipmentDetail? updated = await ref.read(
        shipmentDetailProvider(widget.shipmentId).future,
      );
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      await SuccessDialog.show(
        context: context,
        title: 'Sevk edildi',
        message: 'Sipariş #${order.orderNumber} '
            '${shipment.carrier} ile yola çıktı.',
        details: <ConfirmationDetail>[
          if (updated?.shipment.trackingNumber != null)
            ConfirmationDetail(
              label: 'Takip numarası',
              value: updated!.shipment.trackingNumber!,
            ),
          ConfirmationDetail(
            label: 'Sevk tarihi',
            value: Formatters.dateTime.format(
              updated?.shipment.shippedAt ?? DateTime.now(),
            ),
          ),
        ],
      );
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

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final ShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final Shipment shipment = detail.shipment;
    final SalesOrder order = detail.order;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                order.customerName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(
              label: shipment.status.label,
              tone: shipment.status.tone,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Flexible(child: CodeChip(code: shipment.code)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: InkWell(
                onTap: () => context.push(AppRoutes.orderDetail(order.id)),
                child: CodeChip(code: '#${order.orderNumber}'),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Şartnamenin "paket sayısı" ve "toplam adet" alanları.
        StatRow(
          blocks: <Widget>[
            StatBlock(
              label: 'Paket',
              value: '${shipment.packageCount}',
              sublabel: 'koli',
            ),
            StatBlock(
              label: 'Çeşit',
              value: '${order.lineCount}',
              sublabel: 'ürün',
            ),
            StatBlock(
              label: 'Toplam',
              value: Formatters.integer.format(detail.totalQuantity),
              sublabel: 'adet',
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.sm),

        InfoRow(label: 'Kargo firması', value: shipment.carrier),
        InfoRow(
          label: 'Oluşturulma',
          value: Formatters.dateTime.format(shipment.createdAt),
        ),
        InfoRow(
          label: 'Sevk tarihi',
          value: shipment.shippedAt == null
              ? 'Henüz sevk edilmedi'
              : Formatters.dateTime.format(shipment.shippedAt!),
          valueColor: shipment.shippedAt == null ? status.neutral : null,
        ),
        if (shipment.trackingNumber != null)
          InfoRow(
            label: 'Takip numarası',
            value: shipment.trackingNumber!,
            valueWidget: CodeChip(code: shipment.trackingNumber!),
          ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(
          title: 'Ürünler',
          subtitle: '${detail.lines.length} çeşit · '
              '${Formatters.quantity(detail.totalQuantity, 'adet')}',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (int i = 0; i < detail.lines.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          _ShipmentLineRow(line: detail.lines[i]),
        ],
      ],
    );
  }
}

class _ShipmentLineRow extends StatelessWidget {
  const _ShipmentLineRow({required this.line});

  final OrderLineDetail line;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return InkWell(
      onTap: () => context.push(AppRoutes.productDetail(line.product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    line.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line.product.sku,
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
            const SizedBox(width: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '×',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const SizedBox(width: 3),
                Text(
                  Formatters.integer.format(line.item.requestedQuantity),
                  style: AppTypography.metricMedium,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              AppIcons.forward,
              size: AppSizes.iconSm,
              color: status.neutral,
            ),
          ],
        ),
      ),
    );
  }
}
