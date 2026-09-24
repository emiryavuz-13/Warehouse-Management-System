import 'package:flutter/material.dart';

/// Tipografi ölçeği.
///
/// Şartname 5. bölüm "büyük ve okunabilir sayılar" maddesi gereği metrik
/// gösterimleri için ayrı, belirgin stiller tanımlanmıştır.
abstract final class AppTypography {
  /// Dashboard özet kartlarındaki büyük sayı (ör. "1.248").
  static const TextStyle metricLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
  );

  /// Kart içindeki orta boy sayı (ör. stok miktarı).
  static const TextStyle metricMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// SKU, barkod, lokasyon kodu gibi teknik kodlar.
  ///
  /// Monospace kullanımı `A-01-01` ile `A-01-11` gibi kodların gözle
  /// ayrıştırılmasını kolaylaştırır.
  static const TextStyle code = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Roboto Mono', 'Courier New'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Badge/chip etiketleri.
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// Bölüm başlıkları ("Son Hareketler", "Kritik Stok").
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  /// Material 3 varsayılan ölçeğini kurumsal ağırlıklarla düzenler.
  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
      bodySmall: base.bodySmall?.copyWith(height: 1.35),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}
