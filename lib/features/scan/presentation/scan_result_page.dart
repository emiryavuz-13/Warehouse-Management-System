import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';
import '../../products/providers/product_providers.dart';
import '../providers/scan_providers.dart';

/// Tarama sonucu (şartname 10. bölüm).
///
/// Şartnamenin istediği çıktı:
///
/// ```text
/// Barkod bulundu ✓
/// iPhone 15
/// SKU: IP15-128-BLK
/// Stok: 24
/// Lokasyon: A-01-01
/// ```
///
/// ve buradan ürün detayı, stok transferi, mal kabul aksiyonları.
///
/// **Bulunamama hali gerçek bir sonuçtur, hata değil.** Depoda okunan kod
/// sık sık kayıtlı olmayan bir koliye aittir; ekran bunu bir hata ekranıyla
/// değil, ne yapılabileceğini söyleyen bir sonuçla karşılar.
class ScanResultPage extends ConsumerWidget {
  const ScanResultPage({required this.barcode, super.key});

  final String barcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ScanResult> result = ref.watch(
      scanResultProvider(barcode),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Tarama Sonucu')),
      body: AsyncValueView<ScanResult>(
        value: result,
        onRetry: () => ref.invalidate(scanResultProvider(barcode)),
        loading: const LoadingIndicator(message: 'Barkod aranıyor'),
        data: (ScanResult value) => value.isFound
            ? _FoundBody(result: value)
            : _NotFoundBody(barcode: value.barcode),
      ),
      bottomNavigationBar: result.value?.summary == null
          ? null
          : _FoundActions(summary: result.value!.summary!),
    );
  }
}

/// Barkod eşleşti: ürün künyesi, stok ve lokasyon dökümü.
class _FoundBody extends StatelessWidget {
  const _FoundBody({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    final ProductStockSummary summary = result.summary!;
    final Product product = summary.product;
    final StockStatus stockStatus = summary.status;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _ResultBanner(
          tone: StatusTone.success,
          title: 'Barkod bulundu',
          code: result.barcode,
        ),

        const SizedBox(height: AppSpacing.xl),

        // --- Ürün künyesi ---
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
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      Flexible(child: CodeChip(code: product.sku)),
                      if (stockStatus != StockStatus.normal) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        StockStatusBadge(status: stockStatus, compact: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Bu ekrana gelen kişinin ilk sorusu "kaç tane var"; şartnamenin
        // "Stok: 24" satırının karşılığı.
        HeroFigure(
          value: Formatters.integer.format(summary.totalQuantity),
          unit: product.unit,
          label: 'toplam stok',
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        // Şartnamenin "Lokasyon: A-01-01" satırı; ürün birden fazla rafta
        // duruyorsa tek lokasyon yazmak yanıltıcı olurdu.
        const SectionHeader(
          title: 'Lokasyonlar',
          padding: EdgeInsets.only(bottom: AppSpacing.md),
        ),
        if (summary.locations.isEmpty)
          Text(
            'Bu ürün hiçbir lokasyonda kayıtlı değil.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: status.neutral),
          )
        else
          LocationBreakdown(summary: summary),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.sm),

        InfoRow(
          label: 'Barkod',
          value: product.barcode,
          valueWidget: CodeChip(code: product.barcode, icon: AppIcons.barcode),
        ),
        InfoRow(label: 'Marka', value: product.brand),
        InfoRow(
          label: 'Kategori',
          value: summary.category?.name ?? 'Tanımsız',
        ),
        InfoRow(
          label: 'Minimum stok',
          value: Formatters.quantity(product.minStock, product.unit),
        ),
      ],
    );
  }
}

/// Şartname 10. bölümdeki üç aksiyon.
///
/// "Ürün Detayı" birincil: taramanın en sık devamı ürünün kaydına bakmaktır.
/// Transfer, stoku olmayan üründe devre dışı — butonu gizlemek yerine
/// kapalı göstermek nedenini aramadan anlatır.
class _FoundActions extends StatelessWidget {
  const _FoundActions({required this.summary});

  final ProductStockSummary summary;

  @override
  Widget build(BuildContext context) {
    final String productId = summary.product.id;

    return BottomActionBar(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                label: 'Transfer',
                icon: AppIcons.transfer,
                onPressed: summary.totalQuantity > 0
                    ? () =>
                          context.push(AppRoutes.transferForProduct(productId))
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SecondaryButton(
                label: 'Mal Kabul',
                icon: AppIcons.receiving,
                onPressed: () => context.push(AppRoutes.receiving),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Ürün Detayı',
          icon: AppIcons.products,
          onPressed: () => context.push(AppRoutes.productDetail(productId)),
        ),
      ],
    );
  }
}

/// Barkod hiçbir ürüne ait değil.
class _NotFoundBody extends ConsumerWidget {
  const _NotFoundBody({required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _ResultBanner(
          tone: StatusTone.danger,
          title: 'Barkod bulunamadı',
          code: barcode,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Bu kod kayıtlı hiçbir ürüne ait değil. Etiket yıpranmış '
          'olabilir ya da ürün henüz sisteme girilmemiş olabilir.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: status.neutral),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Tekrar Tara',
          icon: AppIcons.scan,
          onPressed: () => context.pop(),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Ürünlerde Ara',
          icon: AppIcons.search,
          // Kodu ürün aramasına taşır: kullanıcı elle yazmak zorunda
          // kalmadan benzer bir kayıt olup olmadığına bakabilir.
          onPressed: () {
            ref.read(productFilterProvider.notifier).setQuery(barcode);
            context.go(AppRoutes.products);
          },
        ),
      ],
    );
  }
}

/// Sonucun tek satırlık özeti: ikon, başlık ve okunan kod.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.tone,
    required this.title,
    required this.code,
  });

  final StatusTone tone;
  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    final Color foreground = tone.foreground(context);

    return Row(
      children: <Widget>[
        Icon(tone.icon, size: AppSizes.iconMd, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: foreground),
              ),
              const SizedBox(height: 2),
              CodeChip(code: code, icon: AppIcons.barcode),
            ],
          ),
        ),
      ],
    );
  }
}
