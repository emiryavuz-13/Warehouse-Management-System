import 'package:intl/intl.dart';

/// Türkçe tarih, saat ve sayı formatlayıcıları.
///
/// Tüm ekranlar buradan okur; hiçbir widget kendi [DateFormat] örneğini
/// oluşturmaz. `initializeDateFormatting('tr_TR')` uygulama açılışında bir kez
/// çağrılır (bkz. `main.dart`).
abstract final class Formatters {
  static const String _locale = 'tr_TR';

  /// `24.09.2026`
  static final DateFormat date = DateFormat('dd.MM.yyyy', _locale);

  /// `24.09.2026 12:42`
  static final DateFormat dateTime = DateFormat('dd.MM.yyyy HH:mm', _locale);

  /// `12:42`
  static final DateFormat time = DateFormat('HH:mm', _locale);

  /// `24 Eylül 2026 Perşembe` — dashboard başlığında kullanılır.
  static final DateFormat longDate = DateFormat('d MMMM yyyy EEEE', _locale);

  /// `24 Eyl` — grafik eksen etiketleri.
  static final DateFormat shortDate = DateFormat('d MMM', _locale);

  /// Binlik ayraçlı tam sayı: `1.248`
  static final NumberFormat integer = NumberFormat.decimalPattern(_locale);

  /// İşaretli tam sayı: `+10`, `-2`, `0`
  ///
  /// Stok hareketlerinde yönü tek bakışta göstermek için kullanılır.
  static String signedInteger(int value) {
    if (value > 0) return '+${integer.format(value)}';
    return integer.format(value);
  }

  /// Yüzde: `%72`
  static String percent(double ratio) => '%${(ratio * 100).round()}';

  /// Miktarı birimiyle birlikte yazar: `24 adet`
  static String quantity(int value, String unit) =>
      '${integer.format(value)} $unit';

  /// Bir tarihin ne kadar önce olduğunu Türkçe anlatır: `3 saat önce`
  ///
  /// Bildirim ve hareket listelerinde tam tarihten daha okunabilirdir.
  static String relative(DateTime moment, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration diff = reference.difference(moment);

    if (diff.isNegative) return date.format(moment);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return date.format(moment);
  }

  /// Gün başlıkları için: `Bugün`, `Dün` veya tam tarih.
  ///
  /// Stok hareketleri ekranında kayıtlar güne göre gruplanırken kullanılır.
  static String dayHeader(DateTime moment, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime a = DateTime(moment.year, moment.month, moment.day);
    final DateTime b = DateTime(reference.year, reference.month, reference.day);
    final int days = b.difference(a).inDays;

    if (days == 0) return 'Bugün';
    if (days == 1) return 'Dün';
    return date.format(moment);
  }
}
