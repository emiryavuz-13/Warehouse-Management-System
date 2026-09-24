import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/warehouse_exception.dart';
import '../../../models/models.dart';
import '../../orders/providers/order_providers.dart';
import '../providers/shipment_providers.dart';

/// Sevkiyat listesi (şartname 17. bölüm).
///
/// Liste iki soruyu ayrı ayrı yanıtlar:
///
/// 1. **Hangi sevkiyat çıkmayı bekliyor?** Açık kayıtlar üstte.
/// 2. **Hangi sipariş sevkiyat kaydı bile açılmamış olarak duruyor?**
///    Şartnamenin akışında "Toplama Tamamlandı → Sevkiyat Hazır" bir adım;
///    orada takılı kalan siparişler kaybolmamalı.
class ShipmentsPage extends ConsumerWidget {
  const ShipmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Shipment>> shipments = ref.watch(shipmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sevkiyat')),
      body: AsyncValueView<List<Shipment>>(
        value: shipments,
        onRetry: () => ref.invalidate(shipmentsProvider),
        loading: const LoadingIndicator(message: 'Sevkiyatlar'),
        data: (List<Shipment> items) => _ShipmentList(shipments: items),
      ),
    );
  }
}

class _ShipmentList extends ConsumerWidget {
  const _ShipmentList({required this.shipments});

  final List<Shipment> shipments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final List<SalesOrder> awaiting =
        ref.watch(awaitingShipmentProvider).value ?? const <SalesOrder>[];

    final List<Shipment> open = shipments
        .where((Shipment s) => !s.status.isShipped)
        .toList();
    final List<Shipment> done = shipments
        .where((Shipment s) => s.status.isShipped)
        .toList();

    if (shipments.isEmpty && awaiting.isEmpty) {
      return const EmptyState(
        icon: AppIcons.shipment,
        title: 'Sevkiyat yok',
        message: 'Sevk edilmeyi bekleyen bir sipariş bulunmuyor.',
      );
    }

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          if (awaiting.isNotEmpty) ...<Widget>[
            _GroupHeader(
              label: 'Sevkiyat bekliyor',
              count: awaiting.length,
            ),
            for (int i = 0; i < awaiting.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _AwaitingRow(order: awaiting[i]),
            ],
          ],
          if (open.isNotEmpty) ...<Widget>[
            _GroupHeader(label: 'Açık sevkiyatlar', count: open.length),
            for (int i = 0; i < open.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _ShipmentRow(shipment: open[i]),
            ],
          ],
          if (done.isNotEmpty) ...<Widget>[
            _GroupHeader(label: 'Sevk edilenler', count: done.length),
            for (int i = 0; i < done.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _ShipmentRow(shipment: done[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCaseTr(),
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$count',
            style: AppTypography.overline.copyWith(color: status.neutral),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(height: 1, color: status.border)),
        ],
      ),
    );
  }
}

/// Sevkiyat kaydı açılmamış, toplanmış sipariş.
///
/// Tek dokunuşla kayıt açılır ve doğrudan sevkiyat detayına gidilir;
/// kullanıcıyı önce listeye, sonra kayda götürmek fazladan bir adım olurdu.
class _AwaitingRow extends ConsumerStatefulWidget {
  const _AwaitingRow({required this.order});

  final SalesOrder order;

  @override
  ConsumerState<_AwaitingRow> createState() => _AwaitingRowState();
}

class _AwaitingRowState extends ConsumerState<_AwaitingRow> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final SalesOrder order = widget.order;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AppIconBox(
            icon: AppIcons.picking,
            size: 40,
            iconSize: 19,
            background: status.successContainer,
            foreground: status.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '#${order.orderNumber} · ${order.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.lineCount} çeşit · '
                  '${Formatters.quantity(order.totalQuantity, 'adet')} toplandı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SecondaryButton(
            label: 'Sevkiyat Aç',
            expanded: false,
            isLoading: _isCreating,
            onPressed: _isCreating ? null : _create,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _isCreating = true);

    try {
      final Shipment shipment = await ref
          .read(warehouseActionsProvider)
          .createShipment(widget.order.id);
      if (!mounted) return;

      setState(() => _isCreating = false);
      context.push(AppRoutes.shipmentDetail(shipment.id));
    } on WarehouseException catch (error) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).status.danger,
        ),
      );
    }
  }
}

/// Sevkiyat satırı.
///
/// Şartnamenin istediği alanların listede görünen kısmı: kayıt kodu, sipariş
/// numarası, müşteri, paket sayısı, durum ve tarih. Ürün dökümü ve toplam
/// adet detay ekranında.
class _ShipmentRow extends ConsumerWidget {
  const _ShipmentRow({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final SalesOrder? order = ref
        .watch(orderDetailProvider(shipment.orderId))
        .value
        ?.order;

    return InkWell(
      onTap: () => context.push(AppRoutes.shipmentDetail(shipment.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    shipment.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.code.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: shipment.status.label,
                  tone: shipment.status.tone,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              order == null
                  ? 'Sipariş bilgisi yükleniyor'
                  : '#${order.orderNumber} · ${order.customerName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(AppIcons.shipment, size: 13, color: status.neutral),
                const SizedBox(width: 5),
                Text(
                  '${shipment.packageCount} paket',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    shipment.carrier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    Formatters.relative(
                      shipment.shippedAt ?? shipment.createdAt,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.forward,
                  size: AppSizes.iconSm,
                  color: status.neutral,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
