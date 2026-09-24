/// Türkçeye özgü metin işlemleri.
///
/// Dart'ın `toUpperCase` ve `toLowerCase` metotları dil bağımsızdır ve
/// Türkçedeki noktalı/noktasız i ayrımını bilmez:
///
/// ```
/// 'Sevkiyat'.toUpperCase()   // SEVKIYAT  ← yanlış, noktasız I
/// 'Sevkiyat'.toUpperCaseTr() // SEVKİYAT  ← doğru
/// ```
///
/// Tüm arayüz Türkçe olduğu için büyük harfe çevirme her zaman buradan
/// yapılır. Aksi halde "TOPLANIYOR" doğru, "SEVKIYAT" yanlış yazılır ve
/// kurumsal bir uygulamada bu hata hemen göze çarpar.
library;

extension TurkishCase on String {
  /// Türkçe kurallarına göre büyük harfe çevirir.
  ///
  /// Yalnızca `i → İ` dönüşümü elle yapılır; `ı → I`, `ğ → Ğ`, `ü → Ü`,
  /// `ş → Ş`, `ö → Ö` ve `ç → Ç` dönüşümlerini Unicode zaten doğru yapar.
  String toUpperCaseTr() => replaceAll('i', 'İ').toUpperCase();

  /// Türkçe kurallarına göre küçük harfe çevirir.
  ///
  /// `I → ı` dönüşümü elle yapılır; Dart varsayılanı `I → i` verir.
  String toLowerCaseTr() => replaceAll('I', 'ı').toLowerCase();
}
