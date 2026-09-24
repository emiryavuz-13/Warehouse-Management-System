import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/status_tone_colors.dart';
import '../../models/models.dart';

/// Durum rozeti (şartname 5. bölüm: "duruma göre renk kullanılan chip'ler").
///
/// Renk ve ikon [StatusTone]'dan türetilir, ekran bunları hesaplamaz.
/// Böylece "Kritik" rozeti uygulamanın her yerinde tam olarak aynı görünür.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.tone,
    this.icon,
    this.showIcon = true,
    this.compact = false,
    super.key,
  });

  /// Rozet üzerindeki Türkçe etiket, ör. `Kritik`, `Sevk Edildi`.
  final String label;

  final StatusTone tone;

  /// Varsayılan ton ikonunun yerine kullanılacak ikon.
  final IconData? icon;

  final bool showIcon;

  /// Dar alanlarda kullanılan küçük varyant — liste satırlarında.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color foreground = tone.foreground(context);
    final Color background = tone.background(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(icon ?? tone.icon, size: compact ? 11 : 13, color: foreground),
            SizedBox(width: compact ? 4 : 5),
          ],
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color: foreground,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stok durumu rozeti (şartname 9. bölüm).
///
/// Miktar ve minimum stok değerinden durumu kendisi hesaplar; ekranın
/// `StockStatus.fromQuantity` çağırması gerekmez. Bu, durumun yanlış
/// hesaplanma ihtimalini tek noktaya indirir.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  /// Miktardan doğrudan rozet üretir.
  factory StockStatusBadge.fromQuantity({
    required int quantity,
    required int minStock,
    bool compact = false,
    Key? key,
  }) {
    return StockStatusBadge(
      status: StockStatus.fromQuantity(quantity, minStock),
      compact: compact,
      key: key,
    );
  }

  final StockStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: status.label,
      tone: status.tone,
      compact: compact,
    );
  }
}

/// Sipariş durumu rozeti (şartname 13. bölüm).
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: status.label,
      tone: status.tone,
      compact: compact,
    );
  }
}

/// Öncelik rozeti — yalnızca dikkat gerektiren öncelikler gösterilir.
///
/// "Normal" ve "Düşük" öncelik rozet üretmez: her siparişe rozet basmak
/// listeyi gürültüye boğar ve asıl acil olanları görünmez kılar
/// (şartname 5. bölüm: "aşırı renk kullanımından kaçınılmalı").
class OrderPriorityBadge extends StatelessWidget {
  const OrderPriorityBadge({
    required this.priority,
    this.compact = true,
    super.key,
  });

  final OrderPriority priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (priority == OrderPriority.normal || priority == OrderPriority.low) {
      return const SizedBox.shrink();
    }

    return StatusBadge(
      label: priority.label,
      tone: priority.tone,
      compact: compact,
    );
  }
}
