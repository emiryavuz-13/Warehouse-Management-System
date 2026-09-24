import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/views.dart';
import '../../models/models.dart';
import 'data_revision.dart';
import 'repository_providers.dart';

/// Veriyi değiştiren tüm işlemlerin tek kapısı.
///
/// **Neden ayrı bir sınıf:** her yazma işleminden sonra [DataRevision.bump]
/// çağrılmalı, yoksa ekranlar eski veriyi göstermeye devam eder. Bu çağrıyı
/// ekranlara bıraksaydık, yeni bir ekran yazan kişinin bunu bilmesi ve
/// hatırlaması gerekirdi. Burada toplandığı için unutulması mümkün değil.
///
/// **İkinci faydası:** ekranlar `userId` taşımak zorunda kalmıyor. Oturum
/// açmış kullanıcı burada okunup repository'ye geçiliyor.
///
/// İş kuralı ihlallerinde `WarehouseException` fırlatır; ekranlar bunu
/// yakalayıp kullanıcıya uyarı olarak gösterir.
class WarehouseActions {
  WarehouseActions(this._ref);

  final Ref _ref;

  String get _userId => _ref.read(currentUserIdProvider);

  /// İşlem bittikten sonra tüm okuma provider'larını tetikler.
  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  // --- Stok transferi (şartname 15. bölüm) ---

  Future<StockMovement> transferStock({
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
  }) async {
    final StockMovement movement = await _ref
        .read(stockRepositoryProvider)
        .transferStock(
          productId: productId,
          sourceLocationId: sourceLocationId,
          targetLocationId: targetLocationId,
          quantity: quantity,
          userId: _userId,
        );
    _bump();
    return movement;
  }

  // --- Mal kabul ve yerleştirme (şartname 11-12. bölümler) ---

  Future<ReceiptDetail> receiveGoods({
    required String receiptId,
    required String productId,
    required int quantity,
    required String targetLocationId,
  }) async {
    final ReceiptDetail detail = await _ref
        .read(orderRepositoryProvider)
        .receiveGoods(
          receiptId: receiptId,
          productId: productId,
          quantity: quantity,
          targetLocationId: targetLocationId,
          userId: _userId,
        );
    _bump();
    return detail;
  }

  Future<ReceiptDetail> putaway({
    required String receiptId,
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
  }) async {
    final ReceiptDetail detail = await _ref
        .read(orderRepositoryProvider)
        .putaway(
          receiptId: receiptId,
          productId: productId,
          sourceLocationId: sourceLocationId,
          targetLocationId: targetLocationId,
          quantity: quantity,
          userId: _userId,
        );
    _bump();
    return detail;
  }

  // --- Toplama (şartname 14. bölüm) ---

  Future<PickingTask> startPicking(String orderId) async {
    final PickingTask task = await _ref
        .read(orderRepositoryProvider)
        .startPicking(orderId: orderId, userId: _userId);
    _bump();
    return task;
  }

  Future<PickingTask> pickLine({
    required String taskId,
    required String productId,
    required int quantity,
  }) async {
    final PickingTask task = await _ref
        .read(orderRepositoryProvider)
        .pickLine(
          taskId: taskId,
          productId: productId,
          quantity: quantity,
          userId: _userId,
        );
    _bump();
    return task;
  }

  // --- Sayım (şartname 16. bölüm) ---

  /// Bir satıra fiziksel miktar girer. Stok henüz değişmez.
  ///
  /// Sayaç yine de artırılır: fark göstergesi ve ilerleme çubuğu anında
  /// güncellenmeli.
  Future<CountDetail> recordCount({
    required String countId,
    required String productId,
    required int countedQuantity,
  }) async {
    final CountDetail detail = await _ref
        .read(stockRepositoryProvider)
        .recordCount(
          countId: countId,
          productId: productId,
          countedQuantity: countedQuantity,
        );
    _bump();
    return detail;
  }

  Future<CountDetail> completeCount(String countId) async {
    final CountDetail detail = await _ref
        .read(stockRepositoryProvider)
        .completeCount(countId: countId, userId: _userId);
    _bump();
    return detail;
  }

  // --- Sevkiyat (şartname 17. bölüm) ---

  Future<Shipment> createShipment(String orderId) async {
    final Shipment shipment = await _ref
        .read(orderRepositoryProvider)
        .createShipment(orderId: orderId);
    _bump();
    return shipment;
  }

  Future<ShipmentDetail> shipOrder(String shipmentId) async {
    final ShipmentDetail detail = await _ref
        .read(orderRepositoryProvider)
        .shipOrder(shipmentId: shipmentId, userId: _userId);
    _bump();
    return detail;
  }

  // --- Bildirimler (şartname 20. bölüm) ---

  Future<void> markNotificationRead(String id) async {
    await _ref.read(warehouseRepositoryProvider).markNotificationRead(id);
    _bump();
  }

  Future<void> markAllNotificationsRead() async {
    await _ref.read(warehouseRepositoryProvider).markAllNotificationsRead();
    _bump();
  }

  /// Kullanıcı aşağı çekerek yenileme yaptığında çağrılır.
  ///
  /// Veri değişmese bile provider'ları tetikler; kullanıcı yenileme
  /// hareketinin karşılık bulduğunu görmeli.
  void refreshAll() => _bump();
}

final Provider<WarehouseActions> warehouseActionsProvider =
    Provider<WarehouseActions>(WarehouseActions.new);
