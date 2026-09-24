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
import '../../shipments/presentation/widgets/ship_action.dart';
import '../providers/order_providers.dart';

/// Sipariş detayı (şartname 13. bölüm).
///
/// Şartnamenin örneği: sipariş numarası, müşteri, ürün listesi, durum ve
/// "Siparişi Topla" aksiyonu.
///
/// Şartnamede olmayan tek ekleme her satırdaki **stok yeterliliği**. Toplama
/// başlatıldıktan sonra rafta mal olmadığını görmek, yolun yarısında
/// tıkanmak demek; sipariş açılır açılmaz görünmeli.
class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OrderDetail?> detail = ref.watch(
      orderDetailProvider(widget.orderId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.value == null
              ? 'Sipariş'
              : '#${detail.value!.order.orderNumber}',
        ),
      ),
      body: AsyncValueView<OrderDetail?>(
        value: detail,
        onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        loading: const LoadingIndicator(message: 'Sipariş yükleniyor'),
        isEmpty: (OrderDetail? value) => value == null,
        empty: const EmptyState(
          icon: AppIcons.orders,
          title: 'Sipariş bulunamadı',
          message: 'Bu sipariş kayıtlarda yok.',
        ),
        data: (OrderDetail? value) => _Body(detail: value!),
      ),
      bottomNavigationBar: detail.value == null
          ? null
          : _buildActions(detail.value!),
    );
  }

  Widget? _buildActions(OrderDetail detail) {
    final SalesOrder order = detail.order;

    // Sevk edilmiş ya da iptal edilmiş siparişte yapılacak bir şey yok.
    if (order.status.isClosed) return null;

    if (order.status.canShip) {
      return BottomActionBar(
        children: <Widget>[
          PrimaryButton(
            label: 'Sevkiyata Geç',
            icon: AppIcons.shipment,
            onPressed: () => openShipmentForOrder(
              context: context,
              ref: ref,
              orderId: widget.orderId,
            ),
          ),
        ],
      );
    }

    final bool hasStock = detail.lines.every(
      (OrderLineDetail l) => l.hasEnoughStock,
    );
    final bool started = detail.pickingTask != null;

    return BottomActionBar(
      children: <Widget>[
        PrimaryButton(
          // Görev açıldıysa etiket "devam et" olur: kullanıcı yeni bir görev
          // başlatmadığını bilmeli.
          label: started ? 'Toplamaya Devam Et' : 'Siparişi Topla',
          icon: AppIcons.picking,
          isLoading: _isStarting,
          // Stok yetmiyorsa toplama başlatılmaz; kullanıcı yolun yarısında
          // tıkanmamalı.
          onPressed: hasStock && !_isStarting ? () => _startPicking() : null,
        ),
        if (!hasStock) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bazı ürünlerde yeterli stok yok, toplama başlatılamaz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).status.danger),
          ),
        ],
      ],
    );
  }

  Future<void> _startPicking() async {
    setState(() => _isStarting = true);

    try {
      await ref.read(warehouseActionsProvider).startPicking(widget.orderId);
      if (!mounted) return;

      setState(() => _isStarting = false);
      context.push(AppRoutes.picking(widget.orderId));
    } on WarehouseException catch (error) {
      if (!mounted) return;
      setState(() => _isStarting = false);
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

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final SalesOrder order = detail.order;
    final bool inProgress = order.status == OrderStatus.picking;

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
            OrderStatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            CodeChip(code: '#${order.orderNumber}'),
            if (order.priority == OrderPriority.urgent ||
                order.priority == OrderPriority.high) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              OrderPriorityBadge(priority: order.priority, compact: false),
            ],
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        StatRow(
          blocks: <Widget>[
            StatBlock(
              label: 'Çeşit',
              value: '${order.lineCount}',
              sublabel: 'ürün',
            ),
            StatBlock(
              label: 'Toplam',
              value: Formatters.integer.format(order.totalQuantity),
              sublabel: 'adet',
            ),
            StatBlock(
              label: 'Toplanan',
              value: Formatters.integer.format(order.pickedQuantity),
              sublabel: 'adet',
              tone: order.isFullyPicked ? StatusTone.success : null,
            ),
          ],
        ),

        if (inProgress) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          TaskProgressBar(
            completed: order.pickedQuantity,
            total: order.totalQuantity,
            label: 'Toplama ilerlemesi',
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.sm),

        InfoRow(
          label: 'Sipariş tarihi',
          value: Formatters.dateTime.format(order.createdAt),
        ),
        if (order.dueDate != null)
          InfoRow(
            label: 'Termin',
            value: Formatters.date.format(order.dueDate!),
          ),
        InfoRow(label: 'Öncelik', value: order.priority.label),
        if (order.shippedAt != null)
          InfoRow(
            label: 'Sevk tarihi',
            value: Formatters.dateTime.format(order.shippedAt!),
          ),
        if (order.note != null) InfoRow(label: 'Not', value: order.note!),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(
          title: 'Ürünler',
          subtitle: '${detail.lines.length} çeşit · '
              '${Formatters.quantity(order.totalQuantity, 'adet')}',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (int i = 0; i < detail.lines.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          _OrderLineRow(line: detail.lines[i]),
        ],
      ],
    );
  }
}

/// Sipariş satırı: şartnamenin "iPhone 15 × 2" gösterimi, üstüne toplama
/// durumu ve stok yeterliliği.
class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({required this.line});

  final OrderLineDetail line;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final OrderItem item = line.item;
    final bool isPicked = item.isPicked;

    return InkWell(
      onTap: () => context.push(AppRoutes.productDetail(line.product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            AppIconBox(
              icon: isPicked ? AppIcons.confirm : AppIcons.picking,
              size: 40,
              iconSize: 19,
              background: isPicked
                  ? status.successContainer
                  : status.neutralContainer,
              foreground: isPicked ? status.success : status.neutral,
            ),
            const SizedBox(width: AppSpacing.md),
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
                    <String>[
                      line.product.sku,
                      if (line.pickLocation != null) line.pickLocation!.code,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.code.copyWith(
                      fontSize: 11.5,
                      color: status.neutral,
                    ),
                  ),
                  if (!line.hasEnoughStock) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Icon(
                          StatusTone.danger.icon,
                          size: 12,
                          color: status.danger,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Depoda ${line.availableStock} adet var, '
                            '${item.remainingQuantity} gerekiyor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: status.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
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
                      Formatters.integer.format(item.requestedQuantity),
                      style: AppTypography.metricMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isPicked
                      ? 'toplandı'
                      : '${item.pickedQuantity} / ${item.requestedQuantity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isPicked ? status.success : status.neutral,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
