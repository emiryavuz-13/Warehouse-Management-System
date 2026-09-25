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
import '../../../models/models.dart';
import '../providers/receiving_providers.dart';

/// Mal kabul detayı (şartname 11. bölüm).
///
/// Şartnamenin örneği tek ürünlü:
///
/// ```text
/// Mal Kabul #GR-1024
/// Tedarikçi ABC Elektronik
/// Ürün iPhone 15
/// Beklenen: 50   Kabul edilen: 0
/// ```
///
/// Mock veride çok kalemli kayıtlar da var (GR-1025, GR-1027), bu yüzden
/// ekran **satır listesi** olarak kuruldu. Kabul işlemi satır bazındadır:
/// depoda mal kalem kalem gelir, tedarikçi bir ürünü eksik göndermiş
/// olabilir ve o kalem kabul edilmeden diğerleri bekletilmemeli.
class ReceiptDetailPage extends ConsumerWidget {
  const ReceiptDetailPage({required this.receiptId, super.key});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReceiptDetail?> detail = ref.watch(
      receiptDetailProvider(receiptId),
    );

    return Scaffold(
      // Başlıkta tarama kısayolu yok: şartname 27. bölüm barkod
      // doğrulamayı yerleştirme adımına koyuyor ("50 adet iPhone → Barkod
      // doğrula → A-01-01"). Buradaki bir tarama düğmesi kullanıcıyı Tara
      // sekmesine atıp kaydı kaybettiriyordu.
      appBar: AppBar(title: Text(detail.value?.receipt.code ?? 'Mal Kabul')),
      body: AsyncValueView<ReceiptDetail?>(
        value: detail,
        onRetry: () => ref.invalidate(receiptDetailProvider(receiptId)),
        loading: const LoadingIndicator(message: 'Kayıt yükleniyor'),
        isEmpty: (ReceiptDetail? value) => value == null,
        empty: const EmptyState(
          icon: AppIcons.receiving,
          title: 'Kayıt bulunamadı',
          message: 'Bu mal kabul kaydı sistemde yok.',
        ),
        data: (ReceiptDetail? value) => _Body(detail: value!),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final ReceiptDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final GoodsReceipt receipt = detail.receipt;

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
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
                  receipt.supplierName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: receipt.status.label,
                tone: receipt.status.tone,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Hero yerine ilerleme: bu ekranın sorusu "kaç tane var" değil,
          // "ne kadarı bitti".
          TaskProgressBar(
            completed: receipt.totalReceived,
            total: receipt.totalExpected,
            label: 'Kabul edilen adet',
          ),

          if (receipt.hasOverReceipt) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _OverReceiptNotice(receipt: receipt),
          ],

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.sm),

          InfoRow(
            label: 'Kabul numarası',
            value: receipt.code,
            valueWidget: CodeChip(code: receipt.code),
          ),
          InfoRow(
            label: 'Beklenen tarih',
            value: Formatters.date.format(receipt.expectedDate),
          ),
          if (receipt.completedAt != null)
            InfoRow(
              label: 'Tamamlanma',
              value: Formatters.dateTime.format(receipt.completedAt!),
            ),
          if (receipt.note != null)
            InfoRow(label: 'Not', value: receipt.note!),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: 'Ürünler',
            subtitle: '${detail.lines.length} kalem',
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          for (int i = 0; i < detail.lines.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: status.border),
            _LineRow(receiptId: receipt.id, line: detail.lines[i]),
          ],
        ],
      ),
    );
  }
}

/// Fazla kabul uyarısı (şartname 26. bölüm).
///
/// İşlem engellenmez — gerçek depoda tedarikçi fazla gönderebilir ve mal
/// kapıda bekletilemez. Ama sessizce geçilmez de: fark kayda geçmeli ki
/// tedarikçiyle konuşulabilsin.
class _OverReceiptNotice extends StatelessWidget {
  const _OverReceiptNotice({required this.receipt});

  final GoodsReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final int excess = receipt.totalReceived - receipt.totalExpected;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: status.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            StatusTone.warning.icon,
            size: AppSizes.iconSm,
            color: status.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Beklenenden $excess adet fazla kabul edildi.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: status.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mal kabul satırı — dokununca yerleştirme ekranı açılır.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.receiptId, required this.line});

  final String receiptId;
  final ReceiptLineDetail line;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final GoodsReceiptLine data = line.line;
    final bool isDone = data.isCompleted;

    return InkWell(
      onTap: () =>
          context.push(AppRoutes.putaway(receiptId, line.product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            AppIconBox(
              icon: isDone ? AppIcons.confirm : AppIcons.receiving,
              size: 40,
              iconSize: 19,
              background: isDone
                  ? status.successContainer
                  : status.neutralContainer,
              foreground: isDone ? status.success : status.neutral,
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
                      // Yerleştirildiyse hangi rafa gittiği burada durur;
                      // kullanıcı kaydı kapatmadan önce doğrulayabilmeli.
                      if (line.targetLocation != null)
                        line.targetLocation!.code,
                    ].join(' · '),
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
                      Formatters.integer.format(data.receivedQuantity),
                      style: AppTypography.metricMedium.copyWith(
                        color: data.isOverReceived
                            ? status.warning
                            : (isDone ? status.success : null),
                      ),
                    ),
                    Text(
                      ' / ${Formatters.integer.format(data.expectedQuantity)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: status.neutral),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isDone ? 'kabul edildi' : '${data.remainingQuantity} kaldı',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDone ? status.success : status.neutral,
                  ),
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
