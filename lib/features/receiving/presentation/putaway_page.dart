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
import '../providers/receiving_providers.dart';

/// Ürün yerleştirme (şartname 11-12. bölümler).
///
/// Şartname 12. bölümün akışı birebir: kabul edilen ürün → lokasyon seç →
/// miktar onayla → yerleştirmeyi tamamla.
///
/// **Tek ekran, üç adım değil.** Şartname akışı dört kutuda anlatıyor ama
/// sihirbaza çevirmedim: miktar ve lokasyon birbirini etkiliyor — 50 adet
/// seçildiğinde yeri yetmeyen raflar elenir. Ayrı sayfalara bölünseydi
/// kullanıcı lokasyon seçtikten sonra miktarı değiştirmek için geri
/// dönmek zorunda kalırdı.
///
/// İşlem tamamlandığında (şartname 11. bölüm) mal kabul durumu güncellenir,
/// **stok artar**, bir `goodsReceipt` hareketi oluşur ve başarı mesajı
/// gösterilir. Bunların hepsi `WarehouseDatabase.receiveGoods` içinde tek
/// bir işlemde olur; ekran sonucu göstermekten başka bir şey yapmaz.
class PutawayPage extends ConsumerStatefulWidget {
  const PutawayPage({
    required this.receiptId,
    required this.productId,
    super.key,
  });

  final String receiptId;
  final String productId;

  @override
  ConsumerState<PutawayPage> createState() => _PutawayPageState();
}

class _PutawayPageState extends ConsumerState<PutawayPage> {
  int? _quantity;
  String? _locationId;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ReceiptDetail?> detail = ref.watch(
      receiptDetailProvider(widget.receiptId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ürün Yerleştirme')),
      body: AsyncValueView<ReceiptDetail?>(
        value: detail,
        onRetry: () =>
            ref.invalidate(receiptDetailProvider(widget.receiptId)),
        loading: const LoadingIndicator(message: 'Kayıt yükleniyor'),
        isEmpty: (ReceiptDetail? value) =>
            value == null || _lineOf(value) == null,
        empty: const EmptyState(
          icon: AppIcons.receiving,
          title: 'Satır bulunamadı',
          message: 'Bu ürün mal kabul kaydında yer almıyor.',
        ),
        data: (ReceiptDetail? value) {
          final ReceiptLineDetail line = _lineOf(value!)!;
          return _Body(
            detail: value,
            line: line,
            quantity: _quantity ?? _defaultQuantity(line),
            locationId: _locationId,
            onQuantityChanged: _setQuantity,
            onLocationSelected: (String id) =>
                setState(() => _locationId = id),
          );
        },
      ),
      bottomNavigationBar: detail.value == null
          ? null
          : _buildActions(detail.value!),
    );
  }

  /// Miktar değişince seçili raf yetmeyebilir; seçimi orada bırakmak
  /// kullanıcıyı onay ekranından sonra bir hata mesajına gönderirdi.
  void _setQuantity(int value) {
    final List<PutawayLocation> locations =
        ref.read(putawayLocationsProvider(widget.productId)).value ??
        const <PutawayLocation>[];
    final PutawayLocation? selected = locations
        .where((PutawayLocation l) => l.summary.location.id == _locationId)
        .firstOrNull;

    setState(() {
      _quantity = value;
      if (selected != null && !selected.fits(value)) _locationId = null;
    });
  }

  ReceiptLineDetail? _lineOf(ReceiptDetail detail) {
    for (final ReceiptLineDetail line in detail.lines) {
      if (line.product.id == widget.productId) return line;
    }
    return null;
  }

  Widget? _buildActions(ReceiptDetail detail) {
    final ReceiptLineDetail? line = _lineOf(detail);
    if (line == null) return null;

    final int quantity = _quantity ?? _defaultQuantity(line);
    final bool canSubmit =
        quantity > 0 && _locationId != null && !_isSubmitting;

    return BottomActionBar(
      children: <Widget>[
        PrimaryButton(
          label: 'Yerleştir',
          icon: AppIcons.putaway,
          isLoading: _isSubmitting,
          onPressed: canSubmit
              ? () => _submit(detail: detail, line: line, quantity: quantity)
              : null,
        ),
      ],
    );
  }

  /// Varsayılan miktar kalan adettir: depoda en sık yapılan iş, gelen malın
  /// tamamını kabul etmektir. Kullanıcı eksik geldiyse azaltır.
  ///
  /// Satır tamamlanmışsa varsayılan 1'e düşer. Beklenen adedi tekrar
  /// önermek, tamamlanmış bir kaleme ikinci kez tam miktar kabul etmeyi
  /// teklif etmek olurdu ve ekran yanlışlıkla "fazla kabul" uyarısı
  /// gösteriyordu.
  static int _defaultQuantity(ReceiptLineDetail line) =>
      line.line.remainingQuantity > 0 ? line.line.remainingQuantity : 1;

  Future<void> _submit({
    required ReceiptDetail detail,
    required ReceiptLineDetail line,
    required int quantity,
  }) async {
    final List<PutawayLocation> locations =
        ref.read(putawayLocationsProvider(widget.productId)).value ??
        const <PutawayLocation>[];
    final PutawayLocation? location = locations
        .where((PutawayLocation l) => l.summary.location.id == _locationId)
        .firstOrNull;
    if (location == null) return;

    final int excess =
        line.line.receivedQuantity + quantity - line.line.expectedQuantity;

    final bool confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Yerleştirmeyi onayla',
      // Somut özet: kullanıcı onaylamadan önce yanlış rafı seçtiğini
      // görebilmeli (şartname 30. bölüm).
      message: '${line.product.name} rafa kaldırılacak ve stok artacak.',
      confirmLabel: 'Yerleştir',
      details: <ConfirmationDetail>[
        ConfirmationDetail(
          label: 'Miktar',
          value: Formatters.quantity(quantity, line.product.unit),
        ),
        ConfirmationDetail(
          label: 'Lokasyon',
          value: location.summary.location.code,
        ),
        ConfirmationDetail(label: 'Mal kabul', value: detail.receipt.code),
        if (excess > 0)
          ConfirmationDetail(
            label: 'Fazla kabul',
            value: '$excess adet',
            valueColor: Theme.of(context).status.warning,
          ),
      ],
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(warehouseActionsProvider)
          .receiveGoods(
            receiptId: widget.receiptId,
            productId: widget.productId,
            quantity: quantity,
            targetLocationId: location.summary.location.id,
          );
      if (!mounted) return;

      // `.value` yazma işleminden hemen sonra hâlâ eski önbelleği taşır;
      // sayaç artırıldığında provider yeniden hesaplanır ama bu asenkron
      // olduğu için beklenmeli. Aksi halde başarı mesajı stok artmamış gibi
      // görünüyordu.
      final ProductStockSummary? updated = await ref.read(
        productSummaryProvider(widget.productId).future,
      );
      if (!mounted) return;
      final int newTotal = updated?.totalQuantity ?? 0;

      // Yükleniyor göstergesi başarı kutusu açılmadan önce kapanmalı:
      // aksi halde kullanıcı onayı okurken arkadaki buton dönmeye devam
      // ediyor ve işlem bitmemiş izlenimi veriyor.
      setState(() => _isSubmitting = false);

      await SuccessDialog.show(
        context: context,
        title: 'Yerleştirme tamamlandı',
        message:
            '${Formatters.quantity(quantity, line.product.unit)} '
            '${location.summary.location.code} rafına kaldırıldı.',
        details: <ConfirmationDetail>[
          ConfirmationDetail(
            label: 'Ürün',
            value: line.product.name,
          ),
          // Stoğun gerçekten arttığını göstermek şartname 24. bölümün
          // "işlem sadece mesaj göstermemeli" şartının kanıtı.
          ConfirmationDetail(
            label: 'Yeni toplam stok',
            value: Formatters.quantity(newTotal, line.product.unit),
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

class _Body extends ConsumerWidget {
  const _Body({
    required this.detail,
    required this.line,
    required this.quantity,
    required this.locationId,
    required this.onQuantityChanged,
    required this.onLocationSelected,
  });

  final ReceiptDetail detail;
  final ReceiptLineDetail line;
  final int quantity;
  final String? locationId;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String> onLocationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final Product product = line.product;
    final GoodsReceiptLine data = line.line;
    final int excess =
        data.receivedQuantity + quantity - data.expectedQuantity;

    final AsyncValue<List<PutawayLocation>> locations = ref.watch(
      putawayLocationsProvider(product.id),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        // Hangi kayıt için çalıştığımız her an görünür olmalı.
        Row(
          children: <Widget>[
            CodeChip(code: detail.receipt.code),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                detail.receipt.supplierName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Row(
          children: <Widget>[
            AppIconBox(
              icon: AppIcons.receiving,
              size: 48,
              iconSize: 22,
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CodeChip(code: product.sku),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Şartnamenin "Beklenen: 50 / Kabul edilen: 0" satırları.
        StatRow(
          blocks: <Widget>[
            StatBlock(
              label: 'Beklenen',
              value: Formatters.integer.format(data.expectedQuantity),
              sublabel: product.unit,
            ),
            StatBlock(
              label: 'Kabul edilen',
              value: Formatters.integer.format(data.receivedQuantity),
              sublabel: product.unit,
            ),
            StatBlock(
              label: 'Kalan',
              value: Formatters.integer.format(data.remainingQuantity),
              sublabel: product.unit,
              tone: data.remainingQuantity == 0 ? StatusTone.success : null,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(
          title: 'Miktar',
          padding: EdgeInsets.only(bottom: AppSpacing.md),
        ),
        QuantitySelector(
          value: quantity,
          min: 1,
          // Üst sınır yok: fazla kabul engellenmez, uyarılır
          // (şartname 26. bölüm).
          unit: product.unit,
          maxActionLabel: 'Kalanı',
          onChanged: onQuantityChanged,
        ),

        // Tamamlanmış satırda uyarı yerine durum bildirilir: kullanıcı
        // henüz bir şey seçmeden "fazla kabul" uyarısı görmemeli, ama
        // kapanmış bir kaleme ek kabul yaptığını da bilmeli.
        if (data.isCompleted) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const _Notice(
            tone: StatusTone.success,
            message:
                'Bu kalem kabul edildi. Sonradan gelen mal için ek kabul '
                'yapabilirsiniz; fark kayda fazla olarak geçer.',
          ),
        ] else if (excess > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Notice(
            tone: StatusTone.warning,
            message:
                'Bu kabul beklenenden $excess adet fazla. '
                'İşlem engellenmez, kayda fazla olarak geçer.',
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(
          title: 'Lokasyon Seç',
          subtitle: '$quantity ${product.unit} sığacak raflar',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        AsyncValueView<List<PutawayLocation>>(
          compactError: true,
          value: locations,
          onRetry: () =>
              ref.invalidate(putawayLocationsProvider(product.id)),
          loading: const LoadingState(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('Lokasyonlar yükleniyor'),
            ),
          ),
          data: (List<PutawayLocation> items) => Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: status.border),
                _LocationOption(
                  option: items[i],
                  quantity: quantity,
                  unit: product.unit,
                  isSelected: locationId == items[i].summary.location.id,
                  onSelected: () =>
                      onLocationSelected(items[i].summary.location.id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lokasyon seçeneği (şartname 12. bölüm).
///
/// Şartnamenin istediği dört bilgi burada: bölge, lokasyon kodu, mevcut
/// doluluk ve ürün sayısı.
///
/// **Sığmayan raf gizlenmez, kilitlenir.** Listeden çıkarmak kullanıcıya
/// "böyle bir raf yok" der; kilitlemek "var ama yeri yetmiyor" der — ikincisi
/// doğru bilgidir ve miktarı azaltma fikrini verir.
class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.option,
    required this.quantity,
    required this.unit,
    required this.isSelected,
    required this.onSelected,
  });

  final PutawayLocation option;
  final int quantity;
  final String unit;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final LocationSummary summary = option.summary;
    final bool fits = option.fits(quantity);

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
                        if (option.alreadyHoldsProduct)
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

/// Miktar alanının altındaki durum şeridi — uyarı ya da bilgi.
class _Notice extends StatelessWidget {
  const _Notice({required this.tone, required this.message});

  final StatusTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color foreground = tone.foreground(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(tone.icon, size: AppSizes.iconSm, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
