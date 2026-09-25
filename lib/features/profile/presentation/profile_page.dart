import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';

/// Profil ekranı (şartname 21. bölüm).
///
/// Şartnamenin istediği beş alan: ad soyad, rol, depo, son giriş, yetkiler.
///
/// Profil aynı zamanda uygulamanın **ayar ve kısayol sayfası**: bottom
/// bar'da yeri olmayan modüller (hareketler, bildirimler, lokasyonlar,
/// raporlar) buradan açılıyor. Beş sekmeye altı modül sığdırmaya çalışmak
/// yerine, az kullanılanları tek bir kapının arkasına almak daha okunur bir
/// navigasyon veriyor (şartname 6. bölüm).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser> user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: AsyncValueView<AppUser>(
        value: user,
        onRetry: () => ref.invalidate(currentUserProvider),
        loading: const LoadingIndicator(message: 'Profil yükleniyor'),
        data: (AppUser value) => _Body(user: value),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Warehouse? warehouse = ref.watch(currentWarehouseProvider).value;
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        // --- Kimlik ---
        Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                user.initials,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.onPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.role.label} · '
                    '${warehouse?.name ?? 'Depo tanımsız'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.sm),

        InfoRow(label: 'Ad Soyad', value: user.fullName),
        InfoRow(label: 'Rol', value: user.role.label),
        InfoRow(
          label: 'Depo',
          value: warehouse == null
              ? 'Tanımsız'
              : '${warehouse.name} · ${warehouse.city}',
        ),
        InfoRow(
          label: 'Son giriş',
          value: Formatters.dateTime.format(user.lastLoginAt),
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        // --- Yetkiler ---
        SectionHeader(
          title: 'Yetkiler',
          subtitle: '${user.permissions.length} yetki',
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String permission in user.permissions)
              _PermissionChip(label: permission),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        // --- Modüller ---
        const SectionHeader(
          title: 'Modüller',
          padding: EdgeInsets.only(bottom: AppSpacing.xs),
        ),
        _MenuRow(
          icon: AppIcons.movements,
          label: 'Stok Hareketleri',
          subtitle: 'Tüm giriş, çıkış ve transferler',
          onTap: () => context.push(AppRoutes.movements),
        ),
        Divider(height: 1, color: status.border),
        _MenuRow(
          icon: AppIcons.notifications,
          label: 'Bildirimler',
          subtitle: unread == 0 ? 'Tümü okundu' : '$unread okunmamış',
          badgeCount: unread,
          onTap: () => context.push(AppRoutes.notifications),
        ),
        Divider(height: 1, color: status.border),
        _MenuRow(
          icon: AppIcons.locations,
          label: 'Lokasyonlar',
          subtitle: 'Depo, bölge ve raf yapısı',
          onTap: () => context.push(AppRoutes.locations),
        ),
        Divider(height: 1, color: status.border),
        _MenuRow(
          icon: AppIcons.reports,
          label: 'Raporlar',
          subtitle: 'Son 7 günün hareket özeti',
          onTap: () => context.push(AppRoutes.reports),
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(
          title: 'Ayarlar',
          padding: EdgeInsets.only(bottom: AppSpacing.md),
        ),
        const _ThemeSelector(),
        const SizedBox(height: AppSpacing.lg),
        const _ErrorSimulationSwitch(),

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: status.border),
        const SizedBox(height: AppSpacing.lg),

        Center(
          child: Column(
            children: <Widget>[
              const IstifLockup(markSize: 34),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sürüm ${AppConstants.appVersion} · demo sürümü\n'
                'Veriler cihazda tutulur, sunucuya gitmez.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: status.neutralContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(AppIcons.confirm, size: 12, color: status.success),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd, color: status.neutral),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              StatusBadge(
                label: '$badgeCount',
                tone: StatusTone.danger,
                compact: true,
                showIcon: false,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
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

/// Tema seçici (şartname 21. bölüm: açık/koyu tema profil ekranından).
///
/// Üç seçenek var, ikili bir anahtar değil: "Sistem" seçeneği olmayan bir
/// uygulama, cihaz karanlık moda geçtiğinde kullanıcıyı ayara geri gönderir.
class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'TEMA',
          style: AppTypography.overline.copyWith(color: status.neutral),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (final ThemeMode option in ThemeMode.values) ...<Widget>[
              if (option != ThemeMode.values.first)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Material(
                  color: option == mode
                      ? colors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).setMode(option),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: option == mode
                              ? colors.primary
                              : status.border,
                          width: option == mode ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            option.icon,
                            size: AppSizes.iconMd,
                            color: option == mode
                                ? colors.primary
                                : status.neutral,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            option.label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: option == mode
                                      ? colors.primary
                                      : colors.onSurface,
                                  fontWeight: option == mode
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Hata simülasyonu anahtarı (şartname 25. bölüm).
///
/// Demo sırasında error durumlarını göstermek için. Yazma işlemleri
/// etkilenmez — kullanıcı yaptığı transferi kaybetmemeli.
class _ErrorSimulationSwitch extends ConsumerWidget {
  const _ErrorSimulationSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool enabled = ref.watch(errorSimulationProvider);
    final AppStatusColors status = Theme.of(context).status;

    return Row(
      children: <Widget>[
        Icon(
          AppIcons.error,
          size: AppSizes.iconMd,
          color: enabled ? status.danger : status.neutral,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Hata simülasyonu',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Text(
                'Okuma işlemleri başarısız olur, hata ekranları görünür. '
                'Kaydetme işlemleri etkilenmez.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: status.neutral),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Switch(
          value: enabled,
          onChanged: (bool value) =>
              ref.read(errorSimulationProvider.notifier).set(value),
        ),
      ],
    );
  }
}
