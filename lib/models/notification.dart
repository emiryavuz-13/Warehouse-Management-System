import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Bildirim merkezindeki tek kayıt (şartname 20. bölüm).
///
/// Sınıf adı `Notification` değil `AppNotification`: Flutter'ın kendi
/// `Notification` sınıfıyla çakışmasın.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.targetRoute,
  });

  final String id;

  /// Kısa başlık, ör. `Kritik stok`.
  final String title;

  /// Açıklama, ör. `Logitech Mouse stok seviyesi 3'e düştü.`
  final String message;

  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  /// Dokunulduğunda gidilecek ekranın yolu, ör. `/products/p-04`.
  ///
  /// Boşsa bildirim yalnızca okundu olarak işaretlenir.
  final String? targetRoute;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? targetRoute,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute ?? this.targetRoute,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    message,
    type,
    createdAt,
    isRead,
    targetRoute,
  ];
}
