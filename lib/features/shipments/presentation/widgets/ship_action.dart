import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers/providers.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../data/views.dart';
import '../../../../data/warehouse_exception.dart';
import '../../../../models/models.dart';
import '../../../orders/providers/order_providers.dart';

/// "Sevkiyata Geç" akışı (şartname 17. bölüm).
///
/// Şartnamenin akışı `Toplama Tamamlandı → Sevkiyat Hazır → Sevk Onayı`.
/// Ortadaki adım bir ekran değil, bir kayıt oluşturma: bu yüzden buton
/// kullanıcıyı sevkiyat listesine değil **doğrudan kendi sevkiyat kaydına**
/// götürür. Kayıt yoksa açar, varsa açmaz.
///
/// Toplama ekranı ve sipariş detayı aynı işi yaptığı için tek yerde duruyor.
Future<void> openShipmentForOrder({
  required BuildContext context,
  required WidgetRef ref,
  required String orderId,
}) async {
  final OrderDetail? detail = ref.read(orderDetailProvider(orderId)).value;

  // Kayıt zaten varsa yeniden oluşturmaya çalışmadan doğrudan açılır.
  final Shipment? existing = detail?.shipment;
  if (existing != null) {
    context.push(AppRoutes.shipmentDetail(existing.id));
    return;
  }

  try {
    final Shipment shipment = await ref
        .read(warehouseActionsProvider)
        .createShipment(orderId);
    if (!context.mounted) return;
    context.push(AppRoutes.shipmentDetail(shipment.id));
  } on WarehouseException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message),
        backgroundColor: Theme.of(context).status.danger,
      ),
    );
  }
}
