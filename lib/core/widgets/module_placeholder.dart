import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Henüz yazılmamış modüller için geçici ekran.
///
/// Rota ağacı 5. commit'te bir bütün olarak kuruldu; modüller sonraki
/// commitlerde sırayla bu ekranın yerini alacak. Boş bir sayfa yerine ne
/// olacağını anlatan bir ekran göstermek, demo sırasında yanlışlıkla
/// tıklanan bir bağlantının bozuk görünmesini engeller.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    required this.title,
    required this.icon,
    this.description,
    this.showAppBar = true,
    super.key,
  });

  final String title;
  final IconData icon;
  final String? description;

  /// Sekme içeriği olarak kullanıldığında kendi AppBar'ını çizer; itilmiş
  /// bir sayfa olarak kullanıldığında geri butonu da gelir.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(context).status;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: status.neutralContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, size: 32, color: status.neutral),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description ?? 'Bu modül sıradaki adımda eklenecek.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: status.neutral),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
