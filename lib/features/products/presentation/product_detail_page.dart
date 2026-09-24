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
import '../providers/product_providers.dart';

/// Ürün detayı (şartname 8. bölüm).
///
/// Şartnamenin istediği bilgiler: ad, SKU, barkod, marka, kategori, birim,
/// minimum stok, toplam stok, lokasyon bazlı stok ve son hareketler.
/// Aksiyonlar: stok transferi, barkod tarama, hareketleri görme.
///
/// **Toplam stok hero figürü olarak açılıyor.** Bu ekrana gelen kişinin
/// aradığı ilk şey "kaç tane var"; diğer bilgiler onun bağlamı.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProductStockSummary?> summary = ref.watch(
      productSummaryProvider(productId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Detayı'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(AppIcons.movements),
            tooltip: 'Hareketleri gör',
            onPressed: () =>
                context.push(AppRoutes.movementsForProduct(productId)),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AsyncValueView<ProductStockSummary?>(
        value: summary,
        onRetry: () => ref.invalidate(productSummaryProvider(productId)),
        loading: const LoadingIndicator(message: 'Ürün yükleniyor'),
        isEmpty: (ProductStockSummary? value) => value == null,
        empty: const EmptyState(
          title: 'Ürün bulunamadı',
          message: 'Bu ürün kayıtlarda yok.',
        ),
        data: (ProductStockSummary? value) =>
            _ProductDetailBody(summary: value!),
      ),
      bottomNavigationBar: summary.value == null
          ? null
          : BottomActionBar(
              children: <Widget>[
                PrimaryButton(
                  label: 'Stok Transfer Et',
                  icon: AppIcons.transfer,
                  // Stoku olmayan ürün transfer edilemez; butonu göstermek
                  // ama çalıştırmamak, kullanıcıyı hata mesajına
                  // göndermekten iyidir.
                  onPressed: summary.value!.totalQuantity > 0
                      ? () => context.push(
                          AppRoutes.transferForProduct(productId),
                        )
                      : null,
                ),
              ],
            ),
    );
  }
}

class _ProductDetailBody extends ConsumerWidget {
  const _ProductDetailBody({required this.summary});

  final ProductStockSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final Product product = summary.product;
    final StockStatus stockStatus = summary.status;
    final AsyncValue<List<MovementDetail>> movements = ref.watch(
      productMovementsProvider(product.id),
    );

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
          // --- Başlık ---
          Row(
            children: <Widget>[
              AppIconBox(
                icon: categoryIcon(summary.category?.iconKey ?? ''),
                size: 52,
                iconSize: 24,
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
                    const SizedBox(height: 2),
                    Text(
                      '${product.brand} · ${summary.category?.name ?? ''}',
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

          const SizedBox(height: AppSpacing.xl),

          // --- Toplam stok (hero) ---
          HeroFigure(
            value: Formatters.integer.format(summary.totalQuantity),
            unit: product.unit,
            label: 'toplam stok',
            delta: stockStatus == StockStatus.normal
                ? null
                : StockStatusBadge(status: stockStatus),
            breakdown: Text(
              'Minimum ${product.minStock} ${product.unit}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          // --- Lokasyon bazlı stok (şartname 8. bölüm) ---
          SectionHeader(
            title: 'Lokasyonlar',
            subtitle: summary.locations.isEmpty
                ? null
                : '${summary.locations.length} rafta bulunuyor',
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          if (summary.locations.isEmpty)
            _InlineEmpty(message: 'Bu ürün hiçbir lokasyonda bulunmuyor.')
          else
            _LocationBreakdown(summary: summary),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          // --- Ürün bilgileri ---
          const SectionHeader(
            title: 'Ürün Bilgileri',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          InfoRow(
            label: 'SKU',
            value: product.sku,
            valueWidget: CodeChip(code: product.sku),
          ),
          InfoRow(
            label: 'Barkod',
            value: product.barcode,
            valueWidget: CodeChip(
              code: product.barcode,
              icon: AppIcons.barcode,
            ),
          ),
          InfoRow(label: 'Marka', value: product.brand),
          InfoRow(
            label: 'Kategori',
            value: summary.category?.name ?? 'Tanımsız',
          ),
          InfoRow(label: 'Birim', value: product.unit),
          InfoRow(
            label: 'Minimum stok',
            value: Formatters.quantity(product.minStock, product.unit),
          ),
          if (product.description != null)
            InfoRow(label: 'Açıklama', value: product.description!),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: status.border),
          const SizedBox(height: AppSpacing.lg),

          // --- Son hareketler ---
          SectionHeader(
            title: 'Son Hareketler',
            actionLabel: 'Tümü',
            onAction: () =>
                context.push(AppRoutes.movementsForProduct(product.id)),
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          ),
          AsyncValueView<List<MovementDetail>>(
            value: movements,
            onRetry: () => ref.invalidate(productMovementsProvider(product.id)),
            loading: const LoadingState(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('Hareket kaydı yükleniyor'),
              ),
            ),
            isEmpty: (List<MovementDetail> items) => items.isEmpty,
            empty: _InlineEmpty(
              message: 'Bu ürün için henüz hareket kaydı yok.',
            ),
            data: (List<MovementDetail> items) => Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: status.border),
                  _MovementRow(detail: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lokasyon bazlı stok dökümü (şartname 8. bölüm).
///
/// Her satırda miktarın yanında **payı** da gösterilir: kullanıcı "24 adedin
/// 18'i A-01-01'de" bilgisini oran çubuğundan bir bakışta alır. Rakamları
/// zihinde oranlamak zorunda kalmamalı.
class _LocationBreakdown extends StatelessWidget {
  const _LocationBreakdown({required this.summary});

  final ProductStockSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final int total = summary.totalQuantity;

    return Column(
      children: <Widget>[
        for (int i = 0; i < summary.locations.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _LocationRow(
            stock: summary.locations[i],
            share: total == 0 ? 0 : summary.locations[i].quantity / total,
            unit: summary.product.unit,
            borderColor: status.border,
          ),
        ],
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.stock,
    required this.share,
    required this.unit,
    required this.borderColor,
  });

  final LocationStock stock;
  final double share;
  final String unit;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              stock.location.type.icon,
              size: AppSizes.iconSm,
              color: status.neutral,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                stock.location.code,
                style: AppTypography.code.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              Formatters.percent(share),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              Formatters.quantity(stock.quantity, unit),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm - 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 4,
            color: colors.primary,
            backgroundColor: borderColor,
          ),
        ),
      ],
    );
  }
}

/// Ürün detayındaki hareket satırı.
///
/// Dashboard'daki satırdan farkı ürün adını tekrarlamaması: zaten o ürünün
/// sayfasındayız. Yer kazanan alan tarih ve referansa ayrıldı.
class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.detail});

  final MovementDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final StockMovement movement = detail.movement;
    final StatusTone tone = movement.type.tone;
    final String? route = detail.routeLabel;

    final bool signed = movement.type.direction != MovementDirection.internal;
    final String quantityText = signed
        ? Formatters.signedInteger(movement.quantity)
        : Formatters.integer.format(movement.quantity.abs());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(
            movement.type.icon,
            size: AppSizes.iconMd,
            color: tone.foreground(context),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  movement.type.label,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  <String>[movement.reference, ?route].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                quantityText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.foreground(context),
                ),
              ),
              Text(
                Formatters.relative(movement.timestamp),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bölüm içi boş durum.
///
/// Tam ekran [EmptyState] burada fazla yer kaplar; bölümün kendi alanında
/// tek satırlık bir bilgi yeterli.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.empty, size: AppSizes.iconMd, color: status.neutral),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
        ],
      ),
    );
  }
}
