import '../../models/models.dart';

/// Demo kullanıcıları (şartname 21. bölüm).
///
/// Gerçek kimlik doğrulama yoktur; [currentUserId] ile sabit bir kullanıcı
/// oturum açmış kabul edilir. Yine de stok hareketleri bu kullanıcılara
/// yazılır, böylece hareket geçmişinde "kim yaptı" bilgisi gerçekçi görünür.
abstract final class MockUsers {
  /// Uygulamayı kullanan kişi.
  static const String currentUserId = 'usr-01';

  static List<AppUser> build(DateTime now) => <AppUser>[
    AppUser(
      id: 'usr-01',
      fullName: 'Emir Yavuz',
      role: UserRole.supervisor,
      warehouseId: 'w-01',
      lastLoginAt: now.subtract(const Duration(hours: 2, minutes: 14)),
      permissions: const <String>[
        'Mal Kabul',
        'Ürün Yerleştirme',
        'Stok Transferi',
        'Sipariş Toplama',
        'Stok Sayımı',
        'Sevkiyat',
      ],
    ),
    AppUser(
      id: 'usr-02',
      fullName: 'Ayşe Demir',
      role: UserRole.operator,
      warehouseId: 'w-01',
      lastLoginAt: now.subtract(const Duration(hours: 5)),
      permissions: const <String>[
        'Mal Kabul',
        'Ürün Yerleştirme',
        'Sipariş Toplama',
      ],
    ),
    AppUser(
      id: 'usr-03',
      fullName: 'Mehmet Kaya',
      role: UserRole.admin,
      warehouseId: 'w-01',
      lastLoginAt: now.subtract(const Duration(days: 1, hours: 3)),
      permissions: const <String>[
        'Mal Kabul',
        'Ürün Yerleştirme',
        'Stok Transferi',
        'Sipariş Toplama',
        'Stok Sayımı',
        'Sevkiyat',
        'Kullanıcı Yönetimi',
      ],
    ),
  ];
}
