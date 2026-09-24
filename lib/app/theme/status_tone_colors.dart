import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/enums.dart';
import 'app_colors.dart';

/// Model katmanındaki [StatusTone] ile tema renkleri ve ikonları arasındaki
/// köprü.
///
/// Modeller Flutter'ı tanımadığı için "ben kritiğim, tonum warning" der;
/// rengi ve ikonu bu dosya seçer. Böylece aynı durum açık ve koyu temada
/// doğru kontrastı alır ve hiçbir ekranda sabit renk yazılmaz.
///
/// **İkon ailesi:** uygulama boyunca yalnızca Lucide kullanılır. Şartname 5.
/// bölüm "tutarlı ikonografi" istiyor; iki ikon ailesini karıştırmak (ince
/// çizgi + dolu) yan yana geldiklerinde göze hemen çarpar. Lucide lojistik
/// ikonlarını da (forklift, warehouse, boxes, scanBarcode) içerdiği için
/// ikinci bir pakete gerek kalmadı.
extension StatusToneColors on StatusTone {
  /// Metin ve ikon rengi — okunabilir, doygun ton.
  Color foreground(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    return switch (this) {
      StatusTone.success => status.success,
      StatusTone.warning => status.warning,
      StatusTone.danger => status.danger,
      StatusTone.info => status.info,
      StatusTone.transfer => status.transfer,
      StatusTone.neutral => status.neutral,
    };
  }

  /// Rozet ve ikon kutusu arka planı — açık, dikkat dağıtmayan ton.
  Color background(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;
    return switch (this) {
      StatusTone.success => status.successContainer,
      StatusTone.warning => status.warningContainer,
      StatusTone.danger => status.dangerContainer,
      StatusTone.info => status.infoContainer,
      StatusTone.transfer => status.transferContainer,
      StatusTone.neutral => status.neutralContainer,
    };
  }

  /// Durumu anlatan ikon. Aynı ton uygulamanın her yerinde aynı ikonla
  /// görünür.
  IconData get icon => switch (this) {
    StatusTone.success => LucideIcons.circleCheck,
    StatusTone.warning => LucideIcons.triangleAlert,
    StatusTone.danger => LucideIcons.circleX,
    StatusTone.info => LucideIcons.refreshCw,
    StatusTone.transfer => LucideIcons.arrowLeftRight,
    StatusTone.neutral => LucideIcons.circleDashed,
  };
}

/// Hareket türlerinin ikonları (şartname 19. bölüm).
extension MovementTypeIcon on MovementType {
  IconData get icon => switch (this) {
    MovementType.goodsReceipt => LucideIcons.packagePlus,
    MovementType.putaway => LucideIcons.arrowDownToLine,
    MovementType.pick => LucideIcons.shoppingBasket,
    MovementType.transfer => LucideIcons.arrowLeftRight,
    MovementType.countAdjustment => LucideIcons.clipboardCheck,
    MovementType.shipment => LucideIcons.truck,
    MovementType.returned => LucideIcons.undo2,
  };
}

/// Bildirim türlerinin ikonları (şartname 20. bölüm).
extension NotificationTypeIcon on NotificationType {
  IconData get icon => switch (this) {
    NotificationType.criticalStock => LucideIcons.triangleAlert,
    NotificationType.newTask => LucideIcons.clipboardList,
    NotificationType.goodsReceipt => LucideIcons.packagePlus,
    NotificationType.inventoryCount => LucideIcons.clipboardCheck,
    NotificationType.shipment => LucideIcons.truck,
  };
}

/// Lokasyon türlerinin ikonları (şartname 18. bölüm).
extension LocationTypeIcon on LocationType {
  IconData get icon => switch (this) {
    LocationType.storage => LucideIcons.warehouse,
    LocationType.receiving => LucideIcons.packagePlus,
    LocationType.shipping => LucideIcons.truck,
    LocationType.quarantine => LucideIcons.shieldAlert,
  };
}

/// Ürün kategorilerinin ikonları.
///
/// Model katmanı `ProductCategory.iconKey` alanında metin anahtarı tutar;
/// çeviri burada yapılır. Bilinmeyen anahtarda genel bir kutu ikonu döner,
/// böylece yeni kategori eklendiğinde ekran boş ikonla kalmaz.
IconData categoryIcon(String iconKey) => switch (iconKey) {
  'phone' => LucideIcons.smartphone,
  'laptop' => LucideIcons.laptop,
  'cable' => LucideIcons.cable,
  'headphones' => LucideIcons.headphones,
  _ => LucideIcons.package,
};

/// Uygulama genelinde tekrar eden ikonlar.
///
/// Ekranlar `LucideIcons.xxx` yazmak yerine buradan okur; bir ikon
/// değiştirilmek istendiğinde tek yer güncellenir.
abstract final class AppIcons {
  // Navigasyon
  static const IconData dashboard = LucideIcons.layoutDashboard;
  static const IconData stock = LucideIcons.packageSearch;
  static const IconData scan = LucideIcons.scanLine;
  static const IconData orders = LucideIcons.clipboardList;
  static const IconData profile = LucideIcons.user;

  // Modüller
  static const IconData products = LucideIcons.boxes;
  static const IconData receiving = LucideIcons.packagePlus;
  static const IconData putaway = LucideIcons.arrowDownToLine;
  static const IconData transfer = LucideIcons.arrowLeftRight;
  static const IconData count = LucideIcons.clipboardCheck;
  static const IconData shipment = LucideIcons.truck;
  static const IconData locations = LucideIcons.warehouse;
  static const IconData movements = LucideIcons.history;
  static const IconData notifications = LucideIcons.bell;
  static const IconData reports = LucideIcons.trendingUp;
  static const IconData picking = LucideIcons.shoppingBasket;
  static const IconData forklift = LucideIcons.forklift;

  // Eylemler
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.listFilter;
  static const IconData close = LucideIcons.x;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData add = LucideIcons.plus;
  static const IconData remove = LucideIcons.minus;
  static const IconData confirm = LucideIcons.check;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData barcode = LucideIcons.barcode;

  // Trend gostergeleri
  static const IconData trendUp = LucideIcons.arrowUp;
  static const IconData trendDown = LucideIcons.arrowDown;

  // Durum ekranları
  static const IconData empty = LucideIcons.inbox;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData noResults = LucideIcons.searchX;

  // Tema
  static const IconData themeLight = LucideIcons.sunMedium;
  static const IconData themeDark = LucideIcons.moon;
  static const IconData themeSystem = LucideIcons.monitorSmartphone;
}
