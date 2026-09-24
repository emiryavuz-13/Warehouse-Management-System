import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/providers.dart';
import '../../../app/theme/app_colors.dart';

/// Bottom navigation kabuğu (şartname 6. bölüm).
///
/// Beş sekme: Ana Sayfa, Stok, Siparişler, Tara, Profil.
///
/// `StatefulShellRoute` kullanıldığı için **her sekme kendi geçmişini
/// korur**: kullanıcı Siparişler sekmesinde bir detaya girip Stok sekmesine
/// geçer ve geri döndüğünde yine o detayda olur. Tek bir Navigator
/// kullansaydık her sekme değişiminde yığın sıfırlanırdı.
///
/// Sekme sırası şartname 6. bölümündeki listeden bir noktada ayrılıyor:
/// "Tara" dördüncü değil, **ortada**. Şartname 10. bölüm merkezi bir tarama
/// aksiyonu, 34. bölüm ise taramanın bir-iki dokunuşta bulunmasını istiyor;
/// orta konum başparmakla en kolay ulaşılan yerdir.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStatusColors status = Theme.of(context).status;
    final ColorScheme colors = Theme.of(context).colorScheme;

    // Bildirim rozeti: okunmamış varsa profil sekmesinde nokta gösterilir.
    final int unread = ref
        .watch(unreadNotificationCountProvider)
        .maybeWhen(data: (int value) => value, orElse: () => 0);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: status.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: <Widget>[
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Ana Sayfa',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Stok',
            ),
            // Merkezi tarama aksiyonu — dolgulu daire ile vurgulanır.
            NavigationDestination(
              icon: _ScanIcon(
                background: colors.primary,
                foreground: colors.onPrimary,
              ),
              selectedIcon: _ScanIcon(
                background: colors.primary,
                foreground: colors.onPrimary,
                elevated: true,
              ),
              label: 'Tara',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Siparişler',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.person_outline_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.person_rounded),
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Aktif sekmeye tekrar dokunulursa o sekmenin köküne dönülür — kullanıcı
    // derin bir sayfadayken sekme ikonuna basınca listeye dönmeyi bekler.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// Bottom bar'ın ortasındaki tarama ikonu.
///
/// Şartname 10. bölüm merkezi bir "Tara" aksiyonu istiyor. Ayrı bir FAB
/// yerine sekmenin kendisi vurgulandı: FAB, bottom bar'ın üzerine binerek
/// liste içeriğini kapatır ve geri navigasyonu karmaşıklaştırırdı.
class _ScanIcon extends StatelessWidget {
  const _ScanIcon({
    required this.background,
    required this.foreground,
    this.elevated = false,
  });

  final Color background;
  final Color foreground;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: background.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(Icons.qr_code_scanner_rounded, size: 22, color: foreground),
    );
  }
}
