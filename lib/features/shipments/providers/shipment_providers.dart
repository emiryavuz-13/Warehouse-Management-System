/// Sevkiyat modülünün veri kaynakları (şartname 17. bölüm).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/views.dart';
import '../../../models/models.dart';

/// Tüm sevkiyat kayıtları — sevk bekleyenler üstte.
final FutureProvider<List<Shipment>> shipmentsProvider =
    FutureProvider<List<Shipment>>((Ref ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(orderRepositoryProvider).getShipments();
    });

/// Tek bir sevkiyatın siparişi, satırları ve ürün bilgileri.
final shipmentDetailProvider = FutureProvider.family<ShipmentDetail?, String>((
  Ref ref,
  String shipmentId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(orderRepositoryProvider).getShipmentDetail(shipmentId);
});

/// Toplanmış ama henüz sevkiyat kaydı açılmamış siparişler.
///
/// Şartname 17. bölümün akışında "Toplama Tamamlandı → Sevkiyat Hazır" bir
/// adım; bu sağlayıcı o adımda takılı kalan siparişleri gösterir. Normalde
/// kullanıcı toplama biter bitmez "Sevkiyata Geç" der ve kayıt açılır, ama
/// ekrandan çıkıp gidebilir de — o siparişler sevkiyat listesinde kaybolmamalı.
final FutureProvider<List<SalesOrder>> awaitingShipmentProvider =
    FutureProvider<List<SalesOrder>>((Ref ref) async {
      ref.watch(dataRevisionProvider);

      final List<SalesOrder> orders = await ref
          .watch(orderRepositoryProvider)
          .getOrders(const OrderFilter(statuses: <OrderStatus>{
            OrderStatus.picked,
            OrderStatus.ready,
          }));
      final List<Shipment> shipments = await ref.watch(
        shipmentsProvider.future,
      );

      final Set<String> covered = <String>{
        for (final Shipment shipment in shipments) shipment.orderId,
      };

      return orders
          .where((SalesOrder order) => !covered.contains(order.id))
          .toList();
    });
