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
import '../providers/count_providers.dart';
import 'widgets/count_entry_sheet.dart';
import 'widgets/difference_label.dart';

/// Sayım ekranı (şartname 16. bölüm).
///
/// Şartnamenin istediği üç sayı her satırda: sistem stoku, fiziksel sayım ve
/// fark. *"Fark varsa kullanıcıya açıkça gösterilmelidir."*
///
/// **Sayım kaydedilir, stok hemen değişmez.** Kullanıcı önce tüm satırları
/// girer, farkların tamamını görür, sonra onaylar. Her satırda stoğu anında
/// değiştirmek, yarısı sayılmış bir rafta stoğu tutarsız bırakırdı — ve
/// kullanıcı yanlış girdiği bir sayıyı geri alamazdı.
///
/// Onaylandığında (şartname 16. bölüm) stok sayılan değere çekilir, sayım
/// tamamlanır ve **yalnızca farkı olan satırlar için** düzeltme hareketi
/// oluşur.
class CountDetailPage extends ConsumerStatefulWidget {
  const CountDetailPage({required this.countId, super.key});

  final String countId;

  @override
  ConsumerState<CountDetailPage> createState() => _CountDetailPageState();
}

class _CountDetailPageState extends ConsumerState<CountDetailPage> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CountDetail?> detail = ref.watch(
      countDetailProvider(widget.countId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.count.code ?? 'Sayım')),
      body: AsyncValueView<CountDetail?>(
        value: detail,
        onRetry: () => ref.invalidate(countDetailProvider(widget.countId)),
        loading: const LoadingIndicator(message: 'Sayım yükleniyor'),
        isEmpty: (CountDetail? value) => value == null,
        empty: const EmptyState(
          icon: AppIcons.count,
          title: 'Sayım bulunamadı',
          message: 'Bu sayım kaydı sistemde yok.',
        ),
        data: (CountDetail? value) => _Body(
          detail: value!,
          onCount: (CountLineDetail line) => _enterCount(value, line),
        ),
      ),
      bottomNavigationBar: detail.value == null
          ? null
          : _buildActions(detail.value!),
    );
  }

  Widget? _buildActions(CountDetail detail) {
    if (detail.count.status.isCompleted) return null;

    final int remaining =
        detail.count.lines.length - detail.count.countedLineCount;
    final bool canComplete = remaining == 0 && !_isSubmitting;

    return BottomActionBar(
      children: <Widget>[
        PrimaryButton(
          label: canComplete
              ? 'Sayımı Tamamla'
              : '$remaining ürün daha sayılmalı',
          icon: AppIcons.confirm,
          isLoading: _isSubmitting,
          onPressed: canComplete ? () => _complete(detail) : null,
        ),
      ],
    );
  }

  /// Tek bir satırın fiziksel miktarını girer (şartnamenin "Sayım ekranı"
  /// örneği).
  Future<void> _enterCount(CountDetail detail, CountLineDetail line) async {
    if (detail.count.status.isCompleted) return;

    final int? counted = await CountEntrySheet.show(
      context: context,
      line: line,
      locationCode: detail.location.code,
    );
    if (counted == null || !mounted) return;

    try {
      await ref
          .read(warehouseActionsProvider)
          .recordCount(
            countId: widget.countId,
            productId: line.product.id,
            countedQuantity: counted,
          );
    } on WarehouseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).status.danger,
        ),
      );
    }
  }

  Future<void> _complete(CountDetail detail) async {
    final List<CountLineDetail> differences = detail.lines
        .where((CountLineDetail l) => l.line.hasDifference)
        .toList();

    final bool confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sayımı onayla',
      message: differences.isEmpty
          ? 'Sayımda fark çıkmadı. Kayıt kapatılacak.'
          : 'Farkı olan ürünlerin stoğu sayılan değere çekilecek ve '
                'düzeltme hareketi oluşacak.',
      confirmLabel: 'Onayla',
      // Onay metni ne olacağını somut olarak yazar: kullanıcı hangi ürünün
      // stoğunun ne olacağını görmeden onaylamamalı (şartname 30. bölüm).
      details: <ConfirmationDetail>[
        ConfirmationDetail(
          label: 'Lokasyon',
          value: detail.location.code,
        ),
        for (final CountLineDetail line in differences)
          ConfirmationDetail(
            label: line.product.name,
            value:
                '${line.line.systemQuantity} → ${line.line.countedQuantity}',
            valueColor: (line.line.difference ?? 0) < 0
                ? Theme.of(context).status.danger
                : Theme.of(context).status.success,
          ),
        if (differences.isEmpty)
          const ConfirmationDetail(label: 'Fark', value: 'Yok'),
      ],
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(warehouseActionsProvider).completeCount(widget.countId);
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      await SuccessDialog.show(
        context: context,
        title: 'Sayım tamamlandı',
        message: differences.isEmpty
            ? '${detail.location.code} sayımında fark çıkmadı.'
            : '${detail.location.code} sayımı kapatıldı, '
                  '${differences.length} üründe stok düzeltildi.',
        details: <ConfirmationDetail>[
          for (final CountLineDetail line in differences)
            ConfirmationDetail(
              label: line.product.name,
              value: Formatters.quantity(
                line.line.countedQuantity ?? 0,
                line.product.unit,
              ),
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

class _Body extends StatelessWidget {
  const _Body({required this.detail, required this.onCount});

  final CountDetail detail;
  final ValueChanged<CountLineDetail> onCount;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final InventoryCount count = detail.count;
    final bool isDone = count.status.isCompleted;

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
            AppIconBox(
              icon: detail.location.type.icon,
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
                    detail.location.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sayım lokasyonu',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
            StatusBadge(label: count.status.label, tone: count.status.tone),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        TaskProgressBar(
          completed: count.countedLineCount,
          total: count.lines.length,
          label: 'Sayılan ürün',
        ),

        if (count.differenceCount > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _NetDifferenceNotice(count: count),
        ],

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(
          title: 'Ürünler',
          subtitle: isDone
              ? '${count.lines.length} ürün sayıldı'
              : 'Her ürüne dokunup raftaki miktarı girin',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (int i = 0; i < detail.lines.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: status.border),
          _CountLineRow(
            line: detail.lines[i],
            isEditable: !isDone,
            onTap: () => onCount(detail.lines[i]),
          ),
        ],
      ],
    );
  }
}

/// Sayımın net sonucu: depoda beklenenden ne kadar az/çok mal var.
///
/// Satır satır farkları toplamak kullanıcının işi olmamalı; sayımın
/// kapanışta sorulacak tek sorusu budur.
class _NetDifferenceNotice extends StatelessWidget {
  const _NetDifferenceNotice({required this.count});

  final InventoryCount count;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final int net = count.netDifference;
    final bool isShort = net < 0;
    final Color color = net == 0 ? status.neutral : status.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: status.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(StatusTone.warning.icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              net == 0
                  ? '${count.differenceCount} üründe fark var, '
                        'net değişim sıfır.'
                  : '${count.differenceCount} üründe fark var. '
                        'Net ${isShort ? 'eksik' : 'fazla'}: '
                        '${net.abs()} adet.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayım satırı: şartnamenin istediği üç sayı yan yana.
class _CountLineRow extends StatelessWidget {
  const _CountLineRow({
    required this.line,
    required this.isEditable,
    required this.onTap,
  });

  final CountLineDetail line;
  final bool isEditable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final InventoryCountLine data = line.line;

    return InkWell(
      onTap: isEditable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
                if (isEditable) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    data.isCounted ? AppIcons.edit : AppIcons.add,
                    size: AppSizes.iconSm,
                    color: status.neutral,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            StatRow(
              blocks: <Widget>[
                StatBlock(
                  label: 'Sistem',
                  value: Formatters.integer.format(data.systemQuantity),
                  sublabel: line.product.unit,
                ),
                StatBlock(
                  label: 'Fiziksel',
                  value: data.isCounted
                      ? Formatters.integer.format(data.countedQuantity!)
                      : '—',
                  sublabel: data.isCounted ? line.product.unit : 'sayılmadı',
                ),
                _DifferenceBlock(line: data),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fark bloğu — şartname: "Fark varsa kullanıcıya açıkça gösterilmelidir."
class _DifferenceBlock extends StatelessWidget {
  const _DifferenceBlock({required this.line});

  final InventoryCountLine line;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    if (!line.isCounted) {
      return StatBlock(
        label: 'Fark',
        value: '—',
        sublabel: 'bekliyor',
      );
    }

    final int difference = line.difference ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'FARK',
          style: AppTypography.overline.copyWith(color: status.neutral),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        DifferenceLabel(value: difference),
        const SizedBox(height: 2),
        Text(
          difference == 0 ? 'eşleşti' : 'düzeltilecek',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: status.neutral),
        ),
      ],
    );
  }
}
