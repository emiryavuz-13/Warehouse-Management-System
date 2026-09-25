import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/status_tone_colors.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/models.dart';

/// Bildirim merkezi (şartname 20. bölüm).
///
/// **Bildirime dokunmak ilgili kayda gider.** Mock bildirimlerin
/// `targetRoute` değerleri uygulamanın gerçek yollarıyla eşleşiyor; bir
/// bildirim "Sipariş #10452 için görev oluşturuldu" diyorsa dokunuşta o
/// sipariş açılır. Okundu işareti de o anda düşer — kullanıcının ayrıca
/// "okundu" düğmesi araması gerekmez.
///
/// Okunmamışlar üstte değil, **zaman sırasında** duruyor. Bildirimler bir
/// olay akışı; okunmuşları aşağı itmek akışı bozar ve kullanıcı dün ne
/// olduğunu takip edemez. Okunmamışlar bunun yerine nokta ve dolgu ile
/// işaretleniyor.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> notifications = ref.watch(
      notificationsProvider,
    );
    final int unread = notifications.value
            ?.where((AppNotification n) => !n.isRead)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: <Widget>[
          if (unread > 0)
            TextButton(
              onPressed: () => ref
                  .read(warehouseActionsProvider)
                  .markAllNotificationsRead(),
              child: const Text('Tümünü okundu yap'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AsyncValueView<List<AppNotification>>(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        loading: const LoadingIndicator(message: 'Bildirimler'),
        isEmpty: (List<AppNotification> items) => items.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.notifications,
          title: 'Bildirim yok',
          message: 'Depoda dikkat gerektiren bir durum bulunmuyor.',
        ),
        data: (List<AppNotification> items) =>
            _NotificationList(notifications: items, unread: unread),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.notifications, required this.unread});

  final List<AppNotification> notifications;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.read(warehouseActionsProvider).refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              unread == 0
                  ? '${notifications.length} bildirim · tümü okundu'
                  : '${notifications.length} bildirim · $unread okunmamış',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: status.neutral),
            ),
          ),
          Divider(height: 1, color: status.border),
          for (int i = 0; i < notifications.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: AppSpacing.lg, color: status.border),
            _NotificationRow(notification: notifications[i]),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final StatusTone tone = notification.type.tone;
    final bool isUnread = !notification.isRead;

    return InkWell(
      onTap: () => _open(context, ref),
      child: Container(
        // Okunmamış bildirim çok hafif bir dolguyla ayrılır; kalın bir
        // vurgu, okunmuşları "silik" göstererek akışı ikiye bölerdi.
        color: isUnread
            ? tone.foreground(context).withValues(alpha: 0.04)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppIconBox(
              icon: notification.type.tone.icon,
              size: 40,
              iconSize: 19,
              background: tone.background(context),
              foreground: tone.foreground(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      if (isUnread) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: tone.foreground(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.message,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: status.neutral),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Tür etiketi ve zaman uzun olabilir ("KRİTİK STOK" +
                  // "35 dakika önce"); ikisi de gerekirse kısalır.
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          notification.type.label.toUpperCaseTr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.overline.copyWith(
                            color: tone.foreground(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          Formatters.relative(notification.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: status.neutral, fontSize: 11.5),
                        ),
                      ),
                      if (notification.targetRoute != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          AppIcons.forward,
                          size: AppSizes.iconSm,
                          color: status.neutral,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref
          .read(warehouseActionsProvider)
          .markNotificationRead(notification.id);
    }
    if (!context.mounted) return;

    final String? target = notification.targetRoute;
    if (target != null) context.push(target);
  }
}
