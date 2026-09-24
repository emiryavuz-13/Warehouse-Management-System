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
import '../../../models/models.dart';
import '../providers/receiving_providers.dart';

/// Mal kabul listesi (şartname 11. bölüm).
///
/// Şartnamenin istediği alanlar her satırda: kabul numarası, tedarikçi,
/// beklenen miktar, kabul edilen miktar, durum ve tarih.
///
/// **Filtre yerine gruplama.** Stok listesinde durum şeridi kurmuştuk; burada
/// kayıt sayısı azdır ve durumlar bir yaşam döngüsüdür (bekliyor → kabul
/// ediliyor → tamamlandı). Bu durumda filtre bir dokunuş daha ister ve
/// karşılığında sakladığı bilgiyi gizler; iki bölüm başlığı hem sayıyı verir
/// hem işi bitmiş kayıtları yolun dışına alır.
class ReceivingListPage extends ConsumerWidget {
  const ReceivingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GoodsReceipt>> receipts = ref.watch(receiptsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mal Kabul')),
      body: AsyncValueView<List<GoodsReceipt>>(
        value: receipts,
        onRetry: () => ref.invalidate(receiptsProvider),
        loading: const LoadingIndicator(message: 'Mal kabul kayıtları'),
        isEmpty: (List<GoodsReceipt> items) => items.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.receiving,
          title: 'Mal kabul kaydı yok',
          message: 'Depoya beklenen bir sevkiyat bulunmuyor.',
        ),
        data: (List<GoodsReceipt> items) => _ReceiptList(receipts: items),
      ),
    );
  }
}

class _ReceiptList extends ConsumerWidget {
  const _ReceiptList({required this.receipts});

  final List<GoodsReceipt> receipts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;

    final List<GoodsReceipt> open = receipts
        .where((GoodsReceipt r) => !r.status.isCompleted)
        .toList();
    final List<GoodsReceipt> done = receipts
        .where((GoodsReceipt r) => r.status.isCompleted)
        .toList();

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          if (open.isNotEmpty) ...<Widget>[
            _GroupHeader(label: 'Açık kayıtlar', count: open.length),
            for (int i = 0; i < open.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _ReceiptRow(receipt: open[i]),
            ],
          ],
          if (done.isNotEmpty) ...<Widget>[
            _GroupHeader(label: 'Tamamlananlar', count: done.length),
            for (int i = 0; i < done.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  color: status.border,
                ),
              _ReceiptRow(receipt: done[i]),
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

/// Tek mal kabul satırı.
///
/// Miktar **kabul / beklenen** biçiminde gösterilir. Tek başına "50 adet"
/// bir mal kabul kaydında hangi sayı olduğunu söylemez; kesirli gösterim
/// hem ne kadar geldiğini hem ne kadar kaldığını aynı anda verir.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final GoodsReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final bool isDone = receipt.status.isCompleted;

    return InkWell(
      onTap: () => context.push(AppRoutes.receiptDetail(receipt.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    receipt.code,
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
                  label: receipt.status.label,
                  tone: receipt.status.tone,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    receipt.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${Formatters.integer.format(receipt.totalReceived)}'
                  ' / ${Formatters.integer.format(receipt.totalExpected)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDone ? status.success : null,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'adet',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  AppIcons.calendar,
                  size: 13,
                  color: status.neutral,
                ),
                const SizedBox(width: 4),
                Text(
                  Formatters.date.format(receipt.expectedDate),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${receipt.lines.length} kalem',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const Spacer(),
                Icon(
                  AppIcons.forward,
                  size: AppSizes.iconSm,
                  color: status.neutral,
                ),
              ],
            ),
            // İlerleme çubuğu yalnızca işin ortasında anlamlı: hiç
            // başlanmamış ya da bitmiş kayıtta bilgi taşımaz.
            if (!isDone && receipt.totalReceived > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              // Sayı satırda zaten var; çubuk yalnızca oranı gösterir.
              TaskProgressBar(
                completed: receipt.totalReceived,
                total: receipt.totalExpected,
                showCount: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
