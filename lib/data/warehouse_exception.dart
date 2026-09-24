/// Bir iş kuralının ihlal edildiğini bildiren hata.
///
/// Şartname 26. bölümündeki kurallar `WarehouseDatabase` içinde uygulanır ve
/// ihlal durumunda bu hata fırlatılır. Mesajlar doğrudan kullanıcıya
/// gösterilebilecek şekilde Türkçe ve somut yazılır: "Yetersiz stok" yerine
/// "A-01-01 lokasyonunda 3 adet var, 5 adet istendi".
///
/// Beklenmeyen program hatalarından ([StateError], [ArgumentError]) bilinçli
/// olarak ayrılmıştır: bu hata "kullanıcı yapamayacağı bir şeyi denedi"
/// anlamına gelir ve arayüzde uyarı olarak gösterilir, çökme olarak değil.
class WarehouseException implements Exception {
  const WarehouseException(this.message, {this.code});

  /// Kullanıcıya gösterilebilecek Türkçe açıklama.
  final String message;

  /// Testlerin hata türünü metne bakmadan ayırt etmesi için kısa kod.
  final WarehouseErrorCode? code;

  // --- Stok ve transfer ---

  factory WarehouseException.insufficientStock({
    required String productName,
    required String locationCode,
    required int available,
    required int requested,
  }) {
    return WarehouseException(
      '$locationCode lokasyonunda $productName için $available adet var, '
      '$requested adet istendi.',
      code: WarehouseErrorCode.insufficientStock,
    );
  }

  factory WarehouseException.invalidQuantity([String? detail]) {
    return WarehouseException(
      detail ?? 'Miktar sıfırdan büyük olmalıdır.',
      code: WarehouseErrorCode.invalidQuantity,
    );
  }

  factory WarehouseException.sameLocation() {
    return const WarehouseException(
      'Kaynak ve hedef lokasyon aynı olamaz.',
      code: WarehouseErrorCode.sameLocation,
    );
  }

  factory WarehouseException.capacityExceeded({
    required String locationCode,
    required int freeCapacity,
    required int requested,
  }) {
    return WarehouseException(
      '$locationCode lokasyonunda $freeCapacity adetlik yer kaldı, '
      '$requested adet yerleştirilmek istendi.',
      code: WarehouseErrorCode.capacityExceeded,
    );
  }

  // --- Toplama ---

  factory WarehouseException.exceedsRequested({
    required String productName,
    required int remaining,
    required int requested,
  }) {
    return WarehouseException(
      '$productName için $remaining adet toplanması gerekiyor, '
      '$requested adet girildi.',
      code: WarehouseErrorCode.exceedsRequested,
    );
  }

  factory WarehouseException.pickingNotAllowed(String orderNumber) {
    return WarehouseException(
      '#$orderNumber siparişi toplamaya uygun durumda değil.',
      code: WarehouseErrorCode.pickingNotAllowed,
    );
  }

  // --- Sayım ---

  factory WarehouseException.negativeCount() {
    return const WarehouseException(
      'Fiziksel sayım negatif olamaz.',
      code: WarehouseErrorCode.negativeCount,
    );
  }

  factory WarehouseException.countIncomplete(int remaining) {
    return WarehouseException(
      'Sayım tamamlanamaz: $remaining ürün henüz sayılmadı.',
      code: WarehouseErrorCode.countIncomplete,
    );
  }

  // --- Sevkiyat ---

  factory WarehouseException.notPicked(String orderNumber) {
    return WarehouseException(
      '#$orderNumber siparişi tamamen toplanmadan sevk edilemez.',
      code: WarehouseErrorCode.notPicked,
    );
  }

  factory WarehouseException.alreadyShipped(String orderNumber) {
    return WarehouseException(
      '#$orderNumber siparişi zaten sevk edilmiş.',
      code: WarehouseErrorCode.alreadyShipped,
    );
  }

  // --- Kayıt bulunamadı ---

  factory WarehouseException.notFound(String what, String id) {
    return WarehouseException(
      '$what bulunamadı ($id).',
      code: WarehouseErrorCode.notFound,
    );
  }

  /// Mock servisin hata simülasyonu (şartname 25. bölüm).
  factory WarehouseException.simulatedFailure() {
    return const WarehouseException(
      'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.',
      code: WarehouseErrorCode.simulatedFailure,
    );
  }

  @override
  String toString() => message;
}

/// Hata türleri. Testler ve arayüz metne bakmadan ayrım yapabilsin diye.
enum WarehouseErrorCode {
  insufficientStock,
  invalidQuantity,
  sameLocation,
  capacityExceeded,
  exceedsRequested,
  pickingNotAllowed,
  negativeCount,
  countIncomplete,
  notPicked,
  alreadyShipped,
  notFound,
  simulatedFailure,
}
