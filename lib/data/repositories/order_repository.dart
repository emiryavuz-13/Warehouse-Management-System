import '../../models/models.dart';
import '../mock_config.dart';
import '../views.dart';
import '../warehouse_database.dart';

/// Sipariş listesine uygulanacak arama ve filtreler (şartname 13. bölüm).
class OrderFilter {
  const OrderFilter({
    this.query = '',
    this.statuses = const <OrderStatus>{},
    this.priority,
    this.onlyToday = false,
  });

  /// Sipariş numarası veya müşteri adında aranır.
  final String query;

  /// Boşsa tüm durumlar gösterilir.
  final Set<OrderStatus> statuses;

  final OrderPriority? priority;

  /// Yalnızca bugün oluşturulan siparişler.
  final bool onlyToday;

  bool get isActive => statuses.isNotEmpty || priority != null || onlyToday;

  int get activeCount =>
      (statuses.isEmpty ? 0 : 1) +
      (priority == null ? 0 : 1) +
      (onlyToday ? 1 : 0);

  OrderFilter copyWith({
    String? query,
    Set<OrderStatus>? statuses,
    OrderPriority? priority,
    bool? onlyToday,
    bool clearPriority = false,
  }) {
    return OrderFilter(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      priority: clearPriority ? null : (priority ?? this.priority),
      onlyToday: onlyToday ?? this.onlyToday,
    );
  }

  OrderFilter cleared() => OrderFilter(query: query);
}

/// Sipariş, toplama, mal kabul ve sevkiyat işlemleri.
///
/// Dördü aynı arayüzde toplandı çünkü hepsi siparişin yaşam döngüsünün
/// parçası ve birbirlerinin durumunu değiştiriyorlar: toplama bitince sipariş
/// "Toplandı" olur, sevkiyat açılabilir hale gelir.
abstract interface class OrderRepository {
  // --- Siparişler ---

  Future<List<SalesOrder>> getOrders([OrderFilter filter]);

  Future<OrderDetail?> getOrderDetail(String orderId);

  // --- Toplama (şartname 14. bölüm) ---

  Future<List<PickingTask>> getPickingTasks();

  /// Sipariş için toplama görevi oluşturur veya mevcut görevi döner.
  Future<PickingTask> startPicking({
    required String orderId,
    required String userId,
  });

  /// Toplama görevinin sıradaki adımı. Görev bittiyse `null`.
  /// Toplama görevinin bir adımı.
  ///
  /// [lineIndex] verilmezse sıradaki (ilk tamamlanmamış) satır döner.
  /// Verilirse o satır döner — çalışan adımlar arasında gezinebilmeli;
  /// deponun içinde yürürken sıradaki rafa değil, yanından geçtiği rafa
  /// uğramak isteyebilir.
  Future<PickingStep?> getPickingStep(String taskId, {int? lineIndex});

  /// Bir satırdan ürün toplar: stok düşer, hareket oluşur, sipariş ilerler.
  Future<PickingTask> pickLine({
    required String taskId,
    required String productId,
    required int quantity,
    required String userId,
    String? locationId,
  });

  // --- Mal kabul (şartname 11-12. bölümler) ---

  Future<List<GoodsReceipt>> getGoodsReceipts();

  Future<ReceiptDetail?> getReceiptDetail(String receiptId);

  /// Malı kabul edip seçilen lokasyona yerleştirir; stok artar.
  Future<ReceiptDetail> receiveGoods({
    required String receiptId,
    required String productId,
    required int quantity,
    required String targetLocationId,
    required String userId,
  });

  /// Mal kabul alanında bekleyen ürünü rafa kaldırır.
  Future<ReceiptDetail> putaway({
    required String receiptId,
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String userId,
  });

  // --- Sevkiyat (şartname 17. bölüm) ---

  Future<List<Shipment>> getShipments();

  Future<ShipmentDetail?> getShipmentDetail(String shipmentId);

  /// Toplanmış sipariş için sevkiyat kaydı açar.
  Future<Shipment> createShipment({required String orderId});

  /// Sevkiyatı gerçekleştirir; sipariş "Sevk Edildi" durumuna geçer.
  Future<ShipmentDetail> shipOrder({
    required String shipmentId,
    required String userId,
  });
}

/// [OrderRepository]'nin mock veriyle çalışan implementasyonu.
class MockOrderRepository implements OrderRepository {
  MockOrderRepository(this._db, this._config);

  final WarehouseDatabase _db;
  final MockConfig _config;

  // ===========================================================================
  // Siparişler
  // ===========================================================================

  @override
  Future<List<SalesOrder>> getOrders([
    OrderFilter filter = const OrderFilter(),
  ]) async {
    await _config.beforeRead(long: true);

    final String query = filter.query.trim().toLowerCase();
    final DateTime startOfToday = _startOfToday();

    final List<SalesOrder> result = _db.orders.where((SalesOrder order) {
      if (query.isNotEmpty && !order.searchText.contains(query)) return false;
      if (filter.statuses.isNotEmpty &&
          !filter.statuses.contains(order.status)) {
        return false;
      }
      if (filter.priority != null && order.priority != filter.priority) {
        return false;
      }
      if (filter.onlyToday && order.createdAt.isBefore(startOfToday)) {
        return false;
      }
      return true;
    }).toList();

    // Açık siparişler üstte; içlerinde acil olanlar önce, sonra yeniden eskiye.
    result.sort((SalesOrder a, SalesOrder b) {
      if (a.status.isClosed != b.status.isClosed) {
        return a.status.isClosed ? 1 : -1;
      }
      final int byPriority = b.priority.index.compareTo(a.priority.index);
      if (byPriority != 0) return byPriority;
      return b.createdAt.compareTo(a.createdAt);
    });

    return result;
  }

  @override
  Future<OrderDetail?> getOrderDetail(String orderId) async {
    await _config.beforeRead();
    return _buildOrderDetail(orderId);
  }

  // ===========================================================================
  // Toplama
  // ===========================================================================

  @override
  Future<List<PickingTask>> getPickingTasks() async {
    await _config.beforeRead();

    final List<PickingTask> tasks = List<PickingTask>.of(_db.pickingTasks);
    tasks.sort((PickingTask a, PickingTask b) {
      if (a.status.isCompleted != b.status.isCompleted) {
        return a.status.isCompleted ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return tasks;
  }

  @override
  Future<PickingTask> startPicking({
    required String orderId,
    required String userId,
  }) async {
    await _config.beforeWrite();
    return _db.startPicking(orderId: orderId, userId: userId);
  }

  @override
  Future<PickingStep?> getPickingStep(String taskId, {int? lineIndex}) async {
    await _config.beforeRead();
    return _buildPickingStep(taskId, lineIndex: lineIndex);
  }

  @override
  Future<PickingTask> pickLine({
    required String taskId,
    required String productId,
    required int quantity,
    required String userId,
    String? locationId,
  }) async {
    await _config.beforeWrite();
    return _db.pickLine(
      taskId: taskId,
      productId: productId,
      quantity: quantity,
      userId: userId,
      locationId: locationId,
    );
  }

  // ===========================================================================
  // Mal kabul
  // ===========================================================================

  @override
  Future<List<GoodsReceipt>> getGoodsReceipts() async {
    await _config.beforeRead();

    final List<GoodsReceipt> receipts = List<GoodsReceipt>.of(
      _db.goodsReceipts,
    );
    // Açık kayıtlar üstte, beklenen tarihi yakın olan önce.
    receipts.sort((GoodsReceipt a, GoodsReceipt b) {
      if (a.status.isCompleted != b.status.isCompleted) {
        return a.status.isCompleted ? 1 : -1;
      }
      return a.expectedDate.compareTo(b.expectedDate);
    });

    return receipts;
  }

  @override
  Future<ReceiptDetail?> getReceiptDetail(String receiptId) async {
    await _config.beforeRead();
    return _buildReceiptDetail(receiptId);
  }

  @override
  Future<ReceiptDetail> receiveGoods({
    required String receiptId,
    required String productId,
    required int quantity,
    required String targetLocationId,
    required String userId,
  }) async {
    await _config.beforeWrite();
    _db.receiveGoods(
      receiptId: receiptId,
      productId: productId,
      quantity: quantity,
      targetLocationId: targetLocationId,
      userId: userId,
    );
    return _buildReceiptDetail(receiptId)!;
  }

  @override
  Future<ReceiptDetail> putaway({
    required String receiptId,
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String userId,
  }) async {
    await _config.beforeWrite();
    _db.putaway(
      receiptId: receiptId,
      productId: productId,
      sourceLocationId: sourceLocationId,
      targetLocationId: targetLocationId,
      quantity: quantity,
      userId: userId,
    );
    return _buildReceiptDetail(receiptId)!;
  }

  // ===========================================================================
  // Sevkiyat
  // ===========================================================================

  @override
  Future<List<Shipment>> getShipments() async {
    await _config.beforeRead();

    final List<Shipment> shipments = List<Shipment>.of(_db.shipments);
    shipments.sort((Shipment a, Shipment b) {
      if (a.status.isShipped != b.status.isShipped) {
        return a.status.isShipped ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return shipments;
  }

  @override
  Future<ShipmentDetail?> getShipmentDetail(String shipmentId) async {
    await _config.beforeRead();
    return _buildShipmentDetail(shipmentId);
  }

  @override
  Future<Shipment> createShipment({required String orderId}) async {
    await _config.beforeWrite();
    return _db.createShipment(orderId: orderId);
  }

  @override
  Future<ShipmentDetail> shipOrder({
    required String shipmentId,
    required String userId,
  }) async {
    await _config.beforeWrite();
    _db.shipOrder(shipmentId: shipmentId, userId: userId);
    return _buildShipmentDetail(shipmentId)!;
  }

  // ===========================================================================
  // Birleştiriciler
  // ===========================================================================

  OrderDetail? _buildOrderDetail(String orderId) {
    final SalesOrder? order = _db.orderById(orderId);
    if (order == null) return null;

    final PickingTask? task = _db.pickingTaskForOrder(orderId);
    return OrderDetail(
      order: order,
      lines: _buildOrderLines(order, task),
      pickingTask: task,
      shipment: _db.shipmentForOrder(orderId),
    );
  }

  List<OrderLineDetail> _buildOrderLines(SalesOrder order, PickingTask? task) {
    final List<OrderLineDetail> lines = <OrderLineDetail>[];

    for (final OrderItem item in order.items) {
      final Product? product = _db.productById(item.productId);
      if (product == null) continue;

      final PickingLine? pickLine = task == null
          ? null
          : _firstOrNull(
              task.lines,
              (PickingLine l) => l.productId == item.productId,
            );

      lines.add(
        OrderLineDetail(
          item: item,
          product: product,
          availableStock: _db.totalStockOf(item.productId),
          pickLocation: pickLine == null
              ? null
              : _db.locationById(pickLine.locationId),
        ),
      );
    }

    return lines;
  }

  PickingStep? _buildPickingStep(String taskId, {int? lineIndex}) {
    final PickingTask? task = _db.pickingTaskById(taskId);
    if (task == null) return null;

    final int index = lineIndex ?? task.currentLineIndex;
    if (index < 0 || index >= task.lines.length) return null;

    final PickingLine line = task.lines[index];
    final Product? product = _db.productById(line.productId);
    final WarehouseLocation? location = _db.locationById(line.locationId);
    final SalesOrder? order = _db.orderById(task.orderId);
    if (product == null || location == null || order == null) return null;

    return PickingStep(
      task: task,
      line: line,
      product: product,
      location: location,
      stepNumber: index + 1,
      totalSteps: task.totalLineCount,
      availableStock: _db.quantityAt(line.productId, line.locationId),
      orderNumber: order.orderNumber,
    );
  }

  ReceiptDetail? _buildReceiptDetail(String receiptId) {
    final GoodsReceipt? receipt = _db.receiptById(receiptId);
    if (receipt == null) return null;

    final List<ReceiptLineDetail> lines = <ReceiptLineDetail>[];
    for (final GoodsReceiptLine line in receipt.lines) {
      final Product? product = _db.productById(line.productId);
      if (product == null) continue;

      final String? target = line.targetLocationId;
      lines.add(
        ReceiptLineDetail(
          line: line,
          product: product,
          targetLocation: target == null ? null : _db.locationById(target),
        ),
      );
    }

    return ReceiptDetail(receipt: receipt, lines: lines);
  }

  ShipmentDetail? _buildShipmentDetail(String shipmentId) {
    final Shipment? shipment = _db.shipmentById(shipmentId);
    if (shipment == null) return null;

    final SalesOrder? order = _db.orderById(shipment.orderId);
    if (order == null) return null;

    return ShipmentDetail(
      shipment: shipment,
      order: order,
      lines: _buildOrderLines(order, _db.pickingTaskForOrder(order.id)),
    );
  }

  DateTime _startOfToday() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static T? _firstOrNull<T>(List<T> list, bool Function(T) matcher) {
    for (final T item in list) {
      if (matcher(item)) return item;
    }
    return null;
  }
}
