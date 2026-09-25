import '../models/models.dart';
import 'mock/mock_data.dart';
import 'warehouse_exception.dart';

/// Uygulamanın tek değiştirilebilir veri kaynağı.
///
/// Şartname 24. bölüm: "API olmamasına rağmen kullanıcı işlemleri uygulama
/// içerisinde state'i değiştirmelidir." Bu sınıf o sözü tutar — transfer,
/// mal kabul, toplama, sayım ve sevkiyat burada gerçekten veriyi değiştirir.
///
/// **Neden tek sınıf:** stok birden fazla yerden değişebilir (transfer,
/// picking, mal kabul, sayım). Bu mantık ekranlara dağılsaydı her ekranın
/// negatif stok kontrolünü ayrı ayrı yapması gerekirdi ve biri unutulurdu.
/// Tek kapı olduğu için kurallar atlanamaz.
///
/// **Neden repository'ler doğrudan bunu kullanmıyor da sarmalıyor:** gelecekte
/// gerçek API'ye geçildiğinde bu sınıf silinir, repository arayüzleri kalır.
/// UI hiçbir şekilde bu sınıfı tanımaz (şartname 36. bölüm).
///
/// Sınıf bilinçli olarak **senkrondur**. Gecikme ve hata simülasyonu
/// repository katmanının işidir; iş kuralları saf ve test edilebilir kalır.
class WarehouseDatabase {
  WarehouseDatabase._(this._data, this._clock);

  /// Başlangıç verisiyle yeni bir veritabanı kurar.
  ///
  /// [clock] testlerde sabit bir zaman vermek için kullanılır; verilmezse
  /// gerçek saat kullanılır.
  factory WarehouseDatabase({DateTime Function()? clock}) {
    final DateTime Function() resolved = clock ?? DateTime.now;
    return WarehouseDatabase._(MockDataset.seed(now: resolved()), resolved);
  }

  final MockDataset _data;
  final DateTime Function() _clock;

  /// Yeni kayıtlara benzersiz kimlik üretmek için artan sayaç.
  int _sequence = 0;

  DateTime get _now => _clock();

  String _nextId(String prefix) {
    _sequence++;
    return '$prefix-n${_sequence.toString().padLeft(3, '0')}';
  }

  // ===========================================================================
  // OKUMA — hepsi değiştirilemez görünüm döner
  // ===========================================================================

  List<Product> get products => List<Product>.unmodifiable(_data.products);
  List<ProductCategory> get categories =>
      List<ProductCategory>.unmodifiable(_data.categories);
  List<Warehouse> get warehouses =>
      List<Warehouse>.unmodifiable(_data.warehouses);
  List<Zone> get zones => List<Zone>.unmodifiable(_data.zones);
  List<WarehouseLocation> get locations =>
      List<WarehouseLocation>.unmodifiable(_data.locations);
  List<Stock> get stocks => List<Stock>.unmodifiable(_data.stocks);
  List<SalesOrder> get orders => List<SalesOrder>.unmodifiable(_data.orders);
  List<PickingTask> get pickingTasks =>
      List<PickingTask>.unmodifiable(_data.pickingTasks);
  List<GoodsReceipt> get goodsReceipts =>
      List<GoodsReceipt>.unmodifiable(_data.goodsReceipts);
  List<Shipment> get shipments => List<Shipment>.unmodifiable(_data.shipments);
  List<InventoryCount> get inventoryCounts =>
      List<InventoryCount>.unmodifiable(_data.inventoryCounts);
  List<StockMovement> get movements =>
      List<StockMovement>.unmodifiable(_data.movements);
  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_data.notifications);
  List<AppUser> get users => List<AppUser>.unmodifiable(_data.users);

  // --- Tekil arama ---

  Product? productById(String id) =>
      _firstOrNull(_data.products, (Product p) => p.id == id);

  Product? productByBarcode(String barcode) {
    final String trimmed = barcode.trim();
    return _firstOrNull(_data.products, (Product p) => p.barcode == trimmed);
  }

  /// SKU veya barkoda göre arar — tarayıcı ekranı ikisini de kabul eder.
  ///
  /// Karşılaştırmada dil bağımsız `toUpperCase` kullanılır, Türkçe olan
  /// değil: SKU ve barkodlar ASCII'dir (`IP15-128-BLK`), Türkçe kural
  /// burada `i` harfini `İ`ye çevirerek eşleşmeyi bozardı.
  Product? productByCode(String code) {
    final String trimmed = code.trim().toUpperCase();
    return _firstOrNull(
      _data.products,
      (Product p) => p.barcode == trimmed || p.sku.toUpperCase() == trimmed,
    );
  }

  ProductCategory? categoryById(String id) =>
      _firstOrNull(_data.categories, (ProductCategory c) => c.id == id);

  WarehouseLocation? locationById(String id) =>
      _firstOrNull(_data.locations, (WarehouseLocation l) => l.id == id);

  WarehouseLocation? locationByCode(String code) {
    final String trimmed = code.trim().toUpperCase();
    return _firstOrNull(
      _data.locations,
      (WarehouseLocation l) => l.code.toUpperCase() == trimmed,
    );
  }

  Zone? zoneById(String id) =>
      _firstOrNull(_data.zones, (Zone z) => z.id == id);

  Warehouse? warehouseById(String id) =>
      _firstOrNull(_data.warehouses, (Warehouse w) => w.id == id);

  SalesOrder? orderById(String id) =>
      _firstOrNull(_data.orders, (SalesOrder o) => o.id == id);

  PickingTask? pickingTaskById(String id) =>
      _firstOrNull(_data.pickingTasks, (PickingTask t) => t.id == id);

  /// Bir siparişin toplama görevi. Henüz başlatılmamışsa `null`.
  PickingTask? pickingTaskForOrder(String orderId) =>
      _firstOrNull(_data.pickingTasks, (PickingTask t) => t.orderId == orderId);

  GoodsReceipt? receiptById(String id) =>
      _firstOrNull(_data.goodsReceipts, (GoodsReceipt r) => r.id == id);

  Shipment? shipmentById(String id) =>
      _firstOrNull(_data.shipments, (Shipment s) => s.id == id);

  Shipment? shipmentForOrder(String orderId) =>
      _firstOrNull(_data.shipments, (Shipment s) => s.orderId == orderId);

  InventoryCount? countById(String id) =>
      _firstOrNull(_data.inventoryCounts, (InventoryCount c) => c.id == id);

  AppUser? userById(String id) =>
      _firstOrNull(_data.users, (AppUser u) => u.id == id);

  // --- Stok sorguları ---

  /// Bir ürünün tüm lokasyonlardaki toplam miktarı.
  ///
  /// Toplam hiçbir yerde saklanmaz, her zaman buradan hesaplanır.
  int totalStockOf(String productId) => _data.stocks
      .where((Stock s) => s.productId == productId)
      .fold(0, (int sum, Stock s) => sum + s.quantity);

  /// Bir ürünün belirli bir lokasyondaki miktarı.
  int quantityAt(String productId, String locationId) => _data.stocks
      .where(
        (Stock s) => s.productId == productId && s.locationId == locationId,
      )
      .fold(0, (int sum, Stock s) => sum + s.quantity);

  /// Bir ürünün bulunduğu tüm stok kayıtları (boş olanlar hariç).
  List<Stock> stocksOfProduct(String productId, {bool includeEmpty = false}) =>
      _data.stocks
          .where(
            (Stock s) =>
                s.productId == productId && (includeEmpty || s.quantity > 0),
          )
          .toList();

  /// Bir lokasyondaki tüm stok kayıtları.
  List<Stock> stocksAtLocation(
    String locationId, {
    bool includeEmpty = false,
  }) => _data.stocks
      .where(
        (Stock s) =>
            s.locationId == locationId && (includeEmpty || s.quantity > 0),
      )
      .toList();

  /// Bir lokasyonda kullanılan toplam kapasite.
  int usedCapacityOf(String locationId) => _data.stocks
      .where((Stock s) => s.locationId == locationId)
      .fold(0, (int sum, Stock s) => sum + s.quantity);

  /// Ürünün toplam stoğuna göre durumu.
  StockStatus statusOf(String productId) {
    final Product? product = productById(productId);
    if (product == null) return StockStatus.outOfStock;
    return StockStatus.fromQuantity(totalStockOf(productId), product.minStock);
  }

  /// Kritik seviyedeki ve tükenmiş ürünler.
  ///
  /// Dashboard'un kritik stok bölümü ve uyarı sayacı buradan beslenir.
  List<Product> criticalProducts() => _data.products
      .where((Product p) => statusOf(p.id) != StockStatus.normal)
      .toList();

  /// Bir ürünün son hareketleri, yeniden eskiye.
  List<StockMovement> movementsOfProduct(String productId, {int? limit}) {
    final List<StockMovement> result = _data.movements
        .where((StockMovement m) => m.productId == productId)
        .toList();
    return limit == null || result.length <= limit
        ? result
        : result.sublist(0, limit);
  }

  // ===========================================================================
  // YAZMA — şartname 26. bölümündeki iş kuralları burada uygulanır
  // ===========================================================================

  /// Lokasyonlar arası stok transferi (şartname 15. bölüm).
  ///
  /// Kurallar:
  /// - Miktar sıfırdan büyük olmalı
  /// - Kaynak ve hedef aynı olamaz
  /// - Kaynak stok yeterli olmalı (negatif stok oluşamaz)
  /// - Hedef lokasyonun kapasitesi aşılamaz
  StockMovement transferStock({
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String userId,
    String reference = 'Stok transferi',
  }) {
    final Product product = _requireProduct(productId);
    final WarehouseLocation source = _requireLocation(sourceLocationId);
    final WarehouseLocation target = _requireLocation(targetLocationId);

    if (quantity <= 0) throw WarehouseException.invalidQuantity();
    if (sourceLocationId == targetLocationId) {
      throw WarehouseException.sameLocation();
    }

    final int available = quantityAt(productId, sourceLocationId);
    if (available < quantity) {
      throw WarehouseException.insufficientStock(
        productName: product.name,
        locationCode: source.code,
        available: available,
        requested: quantity,
      );
    }

    _assertCapacity(target, quantity);

    _addQuantity(productId, sourceLocationId, -quantity);
    _addQuantity(productId, targetLocationId, quantity);

    return _recordMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.transfer,
      userId: userId,
      reference: reference,
      sourceLocationId: sourceLocationId,
      targetLocationId: targetLocationId,
    );
  }

  /// Mal kabul: gelen ürünü sisteme alır ve lokasyona yerleştirir
  /// (şartname 11-12. bölümler).
  ///
  /// Beklenenden fazla kabul **engellenmez** — gerçek depoda fazla mal
  /// gelebilir. Arayüz bunu uyarı olarak gösterir (şartname 26. bölüm:
  /// "uyarı gösterilebilir").
  GoodsReceipt receiveGoods({
    required String receiptId,
    required String productId,
    required int quantity,
    required String targetLocationId,
    required String userId,
  }) {
    final GoodsReceipt receipt = _requireReceipt(receiptId);
    final Product product = _requireProduct(productId);
    final WarehouseLocation target = _requireLocation(targetLocationId);

    if (quantity <= 0) throw WarehouseException.invalidQuantity();

    final int lineIndex = receipt.lines.indexWhere(
      (GoodsReceiptLine l) => l.productId == productId,
    );
    if (lineIndex == -1) {
      throw WarehouseException.notFound(
        '${receipt.code} kaydında ${product.name}',
        productId,
      );
    }

    _assertCapacity(target, quantity);

    final GoodsReceiptLine line = receipt.lines[lineIndex];
    final List<GoodsReceiptLine> lines = List<GoodsReceiptLine>.of(
      receipt.lines,
    );
    lines[lineIndex] = line.copyWith(
      receivedQuantity: line.receivedQuantity + quantity,
      targetLocationId: targetLocationId,
    );

    _addQuantity(productId, targetLocationId, quantity);

    _recordMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.goodsReceipt,
      userId: userId,
      reference: '${receipt.code} · ${receipt.supplierName}',
      targetLocationId: targetLocationId,
    );

    final bool allDone = lines.every((GoodsReceiptLine l) => l.isCompleted);
    final GoodsReceipt updated = receipt.copyWith(
      lines: lines,
      status: allDone ? ReceiptStatus.completed : ReceiptStatus.receiving,
      completedAt: allDone ? _now : null,
    );

    _replaceReceipt(updated);
    return updated;
  }

  /// Putaway: mal kabul alanında bekleyen ürünü rafa kaldırır
  /// (şartname 12. bölüm).
  ///
  /// Transferden farkı, ilgili mal kabul satırının hedef lokasyonunu da
  /// güncellemesi ve hareketi `putaway` türüyle kaydetmesidir.
  GoodsReceipt putaway({
    required String receiptId,
    required String productId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String userId,
  }) {
    final GoodsReceipt receipt = _requireReceipt(receiptId);
    final Product product = _requireProduct(productId);
    final WarehouseLocation source = _requireLocation(sourceLocationId);
    final WarehouseLocation target = _requireLocation(targetLocationId);

    if (quantity <= 0) throw WarehouseException.invalidQuantity();
    if (sourceLocationId == targetLocationId) {
      throw WarehouseException.sameLocation();
    }

    final int available = quantityAt(productId, sourceLocationId);
    if (available < quantity) {
      throw WarehouseException.insufficientStock(
        productName: product.name,
        locationCode: source.code,
        available: available,
        requested: quantity,
      );
    }

    _assertCapacity(target, quantity);

    _addQuantity(productId, sourceLocationId, -quantity);
    _addQuantity(productId, targetLocationId, quantity);

    _recordMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.putaway,
      userId: userId,
      reference: '${receipt.code} yerleştirme',
      sourceLocationId: sourceLocationId,
      targetLocationId: targetLocationId,
    );

    final int lineIndex = receipt.lines.indexWhere(
      (GoodsReceiptLine l) => l.productId == productId,
    );
    if (lineIndex == -1) return receipt;

    final List<GoodsReceiptLine> lines = List<GoodsReceiptLine>.of(
      receipt.lines,
    );
    lines[lineIndex] = lines[lineIndex].copyWith(
      targetLocationId: targetLocationId,
    );

    final bool allDone = lines.every(
      (GoodsReceiptLine l) => l.isCompleted && l.isPutAway,
    );
    final GoodsReceipt updated = receipt.copyWith(
      lines: lines,
      status: allDone ? ReceiptStatus.completed : receipt.status,
      completedAt: allDone ? (receipt.completedAt ?? _now) : null,
    );

    _replaceReceipt(updated);
    return updated;
  }

  /// Bir sipariş için toplama görevi oluşturur (şartname 14. bölüm).
  ///
  /// Her satır için, o üründen en çok stoğu bulunan lokasyon kaynak seçilir.
  /// Görev zaten varsa mevcut görev döner — aynı sipariş iki kez toplanamaz.
  PickingTask startPicking({required String orderId, required String userId}) {
    final SalesOrder order = _requireOrder(orderId);

    // Durum kontrolü mevcut görev kontrolünden **önce** gelir. Aksi halde
    // sevk edilmiş veya iptal edilmiş bir siparişin tamamlanmış görevi geri
    // döner ve kullanıcı kapalı bir siparişi yeniden toplamaya başlayabilir.
    if (!order.status.canStartPicking) {
      throw WarehouseException.pickingNotAllowed(order.orderNumber);
    }

    final PickingTask? existing = pickingTaskForOrder(orderId);
    if (existing != null) {
      if (order.status == OrderStatus.newOrder) {
        _replaceOrder(order.copyWith(status: OrderStatus.picking));
      }
      return existing;
    }

    final List<PickingLine> lines = <PickingLine>[];
    for (final OrderItem item in order.items) {
      lines.add(
        PickingLine(
          productId: item.productId,
          locationId: _bestSourceLocation(item.productId),
          requestedQuantity: item.requestedQuantity,
          pickedQuantity: item.pickedQuantity,
        ),
      );
    }

    final PickingTask task = PickingTask(
      id: _nextId('pk'),
      code: 'PK-${order.orderNumber}',
      orderId: orderId,
      lines: lines,
      status: PickingStatus.inProgress,
      assignedUserId: userId,
      createdAt: _now,
    );

    _data.pickingTasks.insert(0, task);
    _replaceOrder(order.copyWith(status: OrderStatus.picking));

    _addNotification(
      title: 'Yeni görev',
      message:
          'Sipariş #${order.orderNumber} için ${task.code} toplama görevi '
          'oluşturuldu.',
      type: NotificationType.newTask,
      targetRoute: '/orders/$orderId',
    );

    return task;
  }

  /// Toplama görevinin bir satırından ürün toplar (şartname 14. bölüm).
  ///
  /// Kurallar:
  /// - Miktar sıfırdan büyük olmalı
  /// - Toplanan miktar siparişte istenen miktarı aşamaz
  /// - Ürün seçilen lokasyondan alınır ve orada yeterli stok olmalı
  /// - Tüm satırlar tamamlanmadan sipariş "Toplandı" durumuna geçmez
  ///
  /// [locationId] verilmezse satırın önerilen lokasyonu kullanılır. Aynı ürün
  /// birden fazla rafta durabilir; görev açılırken en çok stoğun bulunduğu
  /// raf önerilir ama çalışan başka bir raftan alabilir — önerilen raf
  /// kapalı, dolu ya da uzakta olabilir. Seçilen raf satıra yazılır, böylece
  /// kısmi toplamalarda ve sipariş detayında nereden alındığı görünür.
  PickingTask pickLine({
    required String taskId,
    required String productId,
    required int quantity,
    required String userId,
    String? locationId,
  }) {
    final PickingTask task = _requireTask(taskId);
    final Product product = _requireProduct(productId);

    if (quantity <= 0) throw WarehouseException.invalidQuantity();

    final int lineIndex = task.lines.indexWhere(
      (PickingLine l) => l.productId == productId,
    );
    if (lineIndex == -1) {
      throw WarehouseException.notFound(
        '${task.code} görevinde ${product.name}',
        productId,
      );
    }

    final PickingLine line = task.lines[lineIndex];
    if (quantity > line.remainingQuantity) {
      throw WarehouseException.exceedsRequested(
        productName: product.name,
        remaining: line.remainingQuantity,
        requested: quantity,
      );
    }

    final String sourceId = locationId ?? line.locationId;
    final WarehouseLocation source = _requireLocation(sourceId);
    final int available = quantityAt(productId, sourceId);
    if (available < quantity) {
      throw WarehouseException.insufficientStock(
        productName: product.name,
        locationCode: source.code,
        available: available,
        requested: quantity,
      );
    }

    // Stok rafından düşer (şartname 24 ve 38. bölümler).
    _addQuantity(productId, sourceId, -quantity);

    final SalesOrder order = _requireOrder(task.orderId);

    _recordMovement(
      productId: productId,
      quantity: -quantity,
      type: MovementType.pick,
      userId: userId,
      reference: '#${order.orderNumber}',
      sourceLocationId: sourceId,
    );

    final List<PickingLine> lines = List<PickingLine>.of(task.lines);
    lines[lineIndex] = line.copyWith(
      pickedQuantity: line.pickedQuantity + quantity,
      locationId: sourceId,
    );

    final bool finished = lines.every((PickingLine l) => l.isCompleted);
    final PickingTask updatedTask = task.copyWith(
      lines: lines,
      status: finished ? PickingStatus.completed : PickingStatus.inProgress,
      completedAt: finished ? _now : null,
    );
    _replaceTask(updatedTask);

    // Sipariş satırlarını da ilerlet.
    final List<OrderItem> items = order.items.map((OrderItem item) {
      if (item.productId != productId) return item;
      return item.copyWith(pickedQuantity: item.pickedQuantity + quantity);
    }).toList();

    _replaceOrder(
      order.copyWith(
        items: items,
        status: finished ? OrderStatus.picked : OrderStatus.picking,
      ),
    );

    if (finished) {
      _addNotification(
        title: 'Toplama tamamlandı',
        message: 'Sipariş #${order.orderNumber} toplandı, sevkiyata hazır.',
        type: NotificationType.newTask,
        targetRoute: '/orders/${order.id}',
      );
    }

    return updatedTask;
  }

  /// Sayım satırına fiziksel miktar girer (şartname 16. bölüm).
  ///
  /// Henüz stok değişmez; değişiklik [completeCount] ile uygulanır. Böylece
  /// kullanıcı tüm satırları girip farkları görebilir, sonra onaylar.
  InventoryCount recordCount({
    required String countId,
    required String productId,
    required int countedQuantity,
  }) {
    final InventoryCount count = _requireCount(countId);

    if (countedQuantity < 0) throw WarehouseException.negativeCount();

    final int lineIndex = count.lines.indexWhere(
      (InventoryCountLine l) => l.productId == productId,
    );
    if (lineIndex == -1) {
      throw WarehouseException.notFound(
        '${count.code} sayımında ürün',
        productId,
      );
    }

    final List<InventoryCountLine> lines = List<InventoryCountLine>.of(
      count.lines,
    );
    lines[lineIndex] = lines[lineIndex].copyWith(
      countedQuantity: countedQuantity,
    );

    final InventoryCount updated = count.copyWith(
      lines: lines,
      status: CountStatus.inProgress,
    );

    _replaceCount(updated);
    return updated;
  }

  /// Sayımı tamamlar ve farkları stoka uygular (şartname 16. bölüm).
  ///
  /// Farkı olan her satır için stok sayılan değere çekilir ve bir sayım
  /// düzeltmesi hareketi oluşturulur. Farkı olmayan satırlar hareket üretmez.
  InventoryCount completeCount({
    required String countId,
    required String userId,
  }) {
    final InventoryCount count = _requireCount(countId);

    if (!count.isFullyCounted) {
      final int remaining = count.lines.length - count.countedLineCount;
      throw WarehouseException.countIncomplete(remaining);
    }

    for (final InventoryCountLine line in count.lines) {
      final int difference = line.difference ?? 0;
      if (difference == 0) continue;

      _setQuantity(line.productId, count.locationId, line.countedQuantity!);

      _recordMovement(
        productId: line.productId,
        quantity: difference,
        type: MovementType.countAdjustment,
        userId: userId,
        reference: count.code,
        sourceLocationId: count.locationId,
      );
    }

    final InventoryCount updated = count.copyWith(
      status: CountStatus.completed,
      completedAt: _now,
    );
    _replaceCount(updated);

    final WarehouseLocation? location = locationById(count.locationId);
    _addNotification(
      title: 'Sayım',
      message: updated.differenceCount == 0
          ? '${location?.code ?? count.locationId} sayımı tamamlandı, fark yok.'
          : '${location?.code ?? count.locationId} sayımı tamamlandı, '
                '${updated.differenceCount} üründe fark tespit edildi.',
      type: NotificationType.inventoryCount,
      targetRoute: '/counts/$countId',
    );

    return updated;
  }

  /// Toplanmış bir sipariş için sevkiyat kaydı açar (şartname 17. bölüm).
  ///
  /// Kayıt zaten varsa mevcut kayıt döner.
  Shipment createShipment({
    required String orderId,
    int packageCount = 1,
    String carrier = 'Aras Kargo',
  }) {
    final SalesOrder order = _requireOrder(orderId);

    final Shipment? existing = shipmentForOrder(orderId);
    if (existing != null) return existing;

    if (!order.isFullyPicked) {
      throw WarehouseException.notPicked(order.orderNumber);
    }

    final Shipment shipment = Shipment(
      id: _nextId('shp'),
      code: 'SH-${_now.year}-${order.orderNumber}',
      orderId: orderId,
      packageCount: packageCount,
      carrier: carrier,
      status: ShipmentStatus.ready,
      createdAt: _now,
    );

    _data.shipments.insert(0, shipment);
    _replaceOrder(order.copyWith(status: OrderStatus.ready));

    return shipment;
  }

  /// Sevkiyatı gerçekleştirir (şartname 17. bölüm).
  ///
  /// Kurallar:
  /// - Sipariş tamamen toplanmış olmalı
  /// - Sevk edilmiş sipariş yeniden sevk edilemez
  ///
  /// Stok hareketi **oluşturmaz**: mal zaten toplama sırasında raftan
  /// düşmüştür. İkinci bir hareket aynı malın iki kez çıkmış görünmesine ve
  /// raporların şişmesine yol açardı.
  Shipment shipOrder({required String shipmentId, required String userId}) {
    final Shipment shipment = _requireShipment(shipmentId);
    final SalesOrder order = _requireOrder(shipment.orderId);

    if (shipment.status.isShipped || order.status == OrderStatus.shipped) {
      throw WarehouseException.alreadyShipped(order.orderNumber);
    }
    if (!order.isFullyPicked) {
      throw WarehouseException.notPicked(order.orderNumber);
    }

    final DateTime shippedAt = _now;
    final Shipment updated = shipment.copyWith(
      status: ShipmentStatus.shipped,
      shippedAt: shippedAt,
      trackingNumber:
          shipment.trackingNumber ??
          'TR${shippedAt.millisecondsSinceEpoch.toString().substring(4)}',
    );

    _replaceShipment(updated);
    _replaceOrder(
      order.copyWith(status: OrderStatus.shipped, shippedAt: shippedAt),
    );

    _addNotification(
      title: 'Sevkiyat',
      message:
          'Sipariş #${order.orderNumber} ${updated.carrier} ile sevk edildi.',
      type: NotificationType.shipment,
      targetRoute: '/shipments/${updated.id}',
    );

    return updated;
  }

  // --- Bildirimler ---

  AppNotification markNotificationRead(String id) {
    final int index = _data.notifications.indexWhere(
      (AppNotification n) => n.id == id,
    );
    if (index == -1) {
      throw WarehouseException.notFound('Bildirim', id);
    }
    final AppNotification updated = _data.notifications[index].copyWith(
      isRead: true,
    );
    _data.notifications[index] = updated;
    return updated;
  }

  void markAllNotificationsRead() {
    for (int i = 0; i < _data.notifications.length; i++) {
      _data.notifications[i] = _data.notifications[i].copyWith(isRead: true);
    }
  }

  int get unreadNotificationCount =>
      _data.notifications.where((AppNotification n) => !n.isRead).length;

  // ===========================================================================
  // İÇ YARDIMCILAR
  // ===========================================================================

  /// Bir ürünü toplamak için en uygun lokasyon: en çok stoğu olan raf.
  ///
  /// Hiç stok yoksa ürünün bilinen bir lokasyonu, o da yoksa varsayılan
  /// deponun ilk rafı döner. Böylece stoksuz ürün için de görev oluşur ve
  /// kullanıcı "yetersiz stok" uyarısını toplama ekranında görür.
  String _bestSourceLocation(String productId) {
    final List<Stock> candidates = stocksOfProduct(productId);
    if (candidates.isNotEmpty) {
      candidates.sort((Stock a, Stock b) => b.quantity.compareTo(a.quantity));
      return candidates.first.locationId;
    }

    final Stock? any = _firstOrNull(
      _data.stocks,
      (Stock s) => s.productId == productId,
    );
    if (any != null) return any.locationId;

    return _data.locations
        .firstWhere(
          (WarehouseLocation l) => l.type == LocationType.storage,
          orElse: () => _data.locations.first,
        )
        .id;
  }

  /// Lokasyona [quantity] kadar ekleme yapılabilir mi?
  void _assertCapacity(WarehouseLocation location, int quantity) {
    final int free = location.availableCapacity(usedCapacityOf(location.id));
    if (quantity > free) {
      throw WarehouseException.capacityExceeded(
        locationCode: location.code,
        freeCapacity: free,
        requested: quantity,
      );
    }
  }

  /// Stok miktarını [delta] kadar değiştirir; kayıt yoksa oluşturur.
  ///
  /// Negatif sonuç oluşamaz — çağıran taraf zaten kontrol eder, buradaki
  /// kontrol son savunma hattıdır.
  void _addQuantity(String productId, String locationId, int delta) {
    final int index = _data.stocks.indexWhere(
      (Stock s) => s.productId == productId && s.locationId == locationId,
    );

    if (index == -1) {
      if (delta < 0) {
        throw WarehouseException.invalidQuantity(
          'Bu lokasyonda bu üründen stok bulunmuyor.',
        );
      }
      _data.stocks.add(
        Stock(
          id: _nextId('stk'),
          productId: productId,
          locationId: locationId,
          quantity: delta,
        ),
      );
      return;
    }

    final int next = _data.stocks[index].quantity + delta;
    if (next < 0) {
      throw WarehouseException.invalidQuantity('Stok negatife düşemez.');
    }
    _data.stocks[index] = _data.stocks[index].copyWith(quantity: next);
  }

  /// Stok miktarını doğrudan verilen değere çeker (sayım düzeltmesi).
  void _setQuantity(String productId, String locationId, int quantity) {
    if (quantity < 0) throw WarehouseException.negativeCount();

    final int index = _data.stocks.indexWhere(
      (Stock s) => s.productId == productId && s.locationId == locationId,
    );

    if (index == -1) {
      _data.stocks.add(
        Stock(
          id: _nextId('stk'),
          productId: productId,
          locationId: locationId,
          quantity: quantity,
        ),
      );
      return;
    }

    _data.stocks[index] = _data.stocks[index].copyWith(quantity: quantity);
  }

  /// Hareketi listenin başına ekler — liste her zaman yeniden eskiye sıralı.
  StockMovement _recordMovement({
    required String productId,
    required int quantity,
    required MovementType type,
    required String userId,
    required String reference,
    String? sourceLocationId,
    String? targetLocationId,
    String? note,
  }) {
    final StockMovement movement = StockMovement(
      id: _nextId('mov'),
      productId: productId,
      quantity: quantity,
      type: type,
      userId: userId,
      timestamp: _now,
      reference: reference,
      sourceLocationId: sourceLocationId,
      targetLocationId: targetLocationId,
      note: note,
    );

    _data.movements.insert(0, movement);
    _notifyIfCritical(productId);
    return movement;
  }

  /// Stok kritik seviyeye düştüyse bildirim üretir.
  ///
  /// Aynı ürün için okunmamış bir kritik stok bildirimi varsa tekrar
  /// eklenmez; aksi halde bildirim merkezi aynı uyarıyla dolar.
  void _notifyIfCritical(String productId) {
    final Product? product = productById(productId);
    if (product == null) return;

    final StockStatus status = statusOf(productId);
    if (status == StockStatus.normal) return;

    final String route = '/products/$productId';
    final bool alreadyWarned = _data.notifications.any(
      (AppNotification n) =>
          !n.isRead &&
          n.type == NotificationType.criticalStock &&
          n.targetRoute == route,
    );
    if (alreadyWarned) return;

    final int total = totalStockOf(productId);
    _addNotification(
      title: 'Kritik stok',
      message: status == StockStatus.outOfStock
          ? '${product.name} stoğu tükendi.'
          : '${product.name} stok seviyesi $total ${product.unit}e düştü.',
      type: NotificationType.criticalStock,
      targetRoute: route,
    );
  }

  void _addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? targetRoute,
  }) {
    _data.notifications.insert(
      0,
      AppNotification(
        id: _nextId('ntf'),
        title: title,
        message: message,
        type: type,
        createdAt: _now,
        targetRoute: targetRoute,
      ),
    );
  }

  // --- Liste güncelleyiciler ---

  void _replaceOrder(SalesOrder order) =>
      _replaceIn(_data.orders, (SalesOrder o) => o.id == order.id, order);

  void _replaceTask(PickingTask task) =>
      _replaceIn(_data.pickingTasks, (PickingTask t) => t.id == task.id, task);

  void _replaceReceipt(GoodsReceipt receipt) => _replaceIn(
    _data.goodsReceipts,
    (GoodsReceipt r) => r.id == receipt.id,
    receipt,
  );

  void _replaceShipment(Shipment shipment) => _replaceIn(
    _data.shipments,
    (Shipment s) => s.id == shipment.id,
    shipment,
  );

  void _replaceCount(InventoryCount count) => _replaceIn(
    _data.inventoryCounts,
    (InventoryCount c) => c.id == count.id,
    count,
  );

  static void _replaceIn<T>(
    List<T> list,
    bool Function(T) matcher,
    T replacement,
  ) {
    final int index = list.indexWhere(matcher);
    if (index != -1) list[index] = replacement;
  }

  // --- Zorunlu aramalar ---

  Product _requireProduct(String id) =>
      productById(id) ?? (throw WarehouseException.notFound('Ürün', id));

  WarehouseLocation _requireLocation(String id) =>
      locationById(id) ?? (throw WarehouseException.notFound('Lokasyon', id));

  SalesOrder _requireOrder(String id) =>
      orderById(id) ?? (throw WarehouseException.notFound('Sipariş', id));

  PickingTask _requireTask(String id) =>
      pickingTaskById(id) ??
      (throw WarehouseException.notFound('Toplama görevi', id));

  GoodsReceipt _requireReceipt(String id) =>
      receiptById(id) ?? (throw WarehouseException.notFound('Mal kabul', id));

  Shipment _requireShipment(String id) =>
      shipmentById(id) ?? (throw WarehouseException.notFound('Sevkiyat', id));

  InventoryCount _requireCount(String id) =>
      countById(id) ?? (throw WarehouseException.notFound('Sayım', id));

  static T? _firstOrNull<T>(List<T> list, bool Function(T) matcher) {
    for (final T item in list) {
      if (matcher(item)) return item;
    }
    return null;
  }
}
