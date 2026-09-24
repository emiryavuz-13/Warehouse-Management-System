import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers/providers.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/status_tone_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/models.dart';

/// Dashboard üst bölümü (şartname 7. bölüm).
///
/// Gösterdikleri: kullanıcı adı, rolü ve deposu, günün tarihi, bildirim
/// ikonu ve okunmamış rozeti.
///
/// Depoyu da göstermek şartnamede yok ama çok depolu bir kurulumda kritik:
/// çalışan hangi deponun verisine baktığını bilmeli.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final AsyncValue<AppUser> user = ref.watch(currentUserProvider);
    final AsyncValue<Warehouse?> warehouse = ref.watch(
      currentWarehouseProvider,
    );
    final int unread = ref
        .watch(unreadNotificationCountProvider)
        .maybeWhen(data: (int value) => value, orElse: () => 0);

    final String name = user.maybeWhen(
      data: (AppUser value) => value.firstName,
      orElse: () => '',
    );
    final String subtitle = <String?>[
      user.value?.role.label,
      warehouse.value?.name,
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  Formatters.longDate.format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: status.neutral),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Merhaba' : 'Merhaba, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _NotificationButton(
            unreadCount: unread,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          const SizedBox(width: AppSpacing.sm),
          _AvatarButton(
            initials: user.value?.initials ?? '',
            background: colors.primary,
            foreground: colors.onPrimary,
            onTap: () => context.go(AppRoutes.profile),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: status.border),
          ),
          child: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            child: Icon(AppIcons.notifications, size: AppSizes.iconMd),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.initials,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String initials;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          child: Center(
            child: Text(
              initials,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
