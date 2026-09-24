import 'package:equatable/equatable.dart';

import '../core/extensions/string_extensions.dart';

import 'enums.dart';

/// Uygulamayı kullanan depo personeli (şartname 21. bölüm).
///
/// Demo'da gerçek kimlik doğrulama yoktur; oturum açmış kullanıcı sabittir.
/// Yine de stok hareketleri bu kullanıcıya yazılır, böylece hareket
/// geçmişinde "kim yaptı" bilgisi gerçekçi görünür.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.warehouseId,
    required this.lastLoginAt,
    this.permissions = const <String>[],
  });

  final String id;
  final String fullName;
  final UserRole role;

  /// Kullanıcının bağlı olduğu depo.
  final String warehouseId;

  final DateTime lastLoginAt;

  /// Yetki etiketleri, ör. `Mal Kabul`, `Sayım`.
  ///
  /// Demo'da yetkiler işlemleri gerçekten kısıtlamaz; profil ekranında
  /// bilgi amaçlı listelenir.
  final List<String> permissions;

  /// Avatar dairesinde gösterilecek baş harfler, ör. `EY`.
  String get initials {
    final List<String> words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCaseTr();
    }
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCaseTr();
  }

  /// Dashboard başlığındaki selamlamada kullanılan ilk ad.
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  AppUser copyWith({
    String? id,
    String? fullName,
    UserRole? role,
    String? warehouseId,
    DateTime? lastLoginAt,
    List<String>? permissions,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      warehouseId: warehouseId ?? this.warehouseId,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    fullName,
    role,
    warehouseId,
    lastLoginAt,
    permissions,
  ];
}
