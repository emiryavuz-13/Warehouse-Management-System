/// Repository katmanını tek noktadan dışa aktarır.
///
/// Şartname 36. bölüm: gerçek API'ye geçildiğinde bu dosyadaki arayüzler
/// aynı kalır, yalnızca Mock* implementasyonlarının yerine Api* sınıfları
/// gelir. UI katmanı hangisini kullandığını bilmez.
library;

export 'movement_repository.dart';
export 'order_repository.dart';
export 'product_repository.dart';
export 'stock_repository.dart';
export 'warehouse_repository.dart';
