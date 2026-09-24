import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/module_placeholder.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/splash/presentation/splash_page.dart';
import 'routes.dart';
import 'theme/status_tone_colors.dart';

/// Uygulamanın rota ağacı.
///
/// Ağaç **baştan bütün olarak** kuruldu: şartname 28. bölümündeki 24 ekranın
/// tamamı burada tanımlı. Henüz yazılmamış olanlar geçici bir ekrana bağlı ve
/// modüller tamamlandıkça yerlerini alacak. Rotaları parça parça eklemek,
/// her modülde ağacı yeniden düzenlemek anlamına gelirdi.
///
/// **İki katmanlı yapı:**
///
/// - Sekme kökleri `StatefulShellRoute` içinde — bottom bar görünür kalır ve
///   her sekme kendi geçmişini korur.
/// - Detay ve modül ekranları üst seviyede — kabuğun üzerine tam ekran
///   itilirler. Operasyonel ekranlarda (toplama, transfer, sayım) kullanıcı
///   tek bir işe odaklanmalı; bottom bar hem yer kaplar hem yarım kalmış bir
///   işlemden kazara çıkmayı kolaylaştırır.
///
/// Bildirimlerin `targetRoute` değerleri bu yollarla eşleşir, dolayısıyla
/// bildirime dokunmak doğrudan ilgili kaydı açar.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashPage(),
      ),

      // ---------------------------------------------------------------------
      // Bottom navigation sekmeleri (şartname 6. bölüm)
      // ---------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          // 0 — Ana Sayfa
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dashboard,
                name: AppRouteNames.dashboard,
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardPage(),
              ),
            ],
          ),

          // 1 — Stok
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.stock,
                name: AppRouteNames.stock,
                builder: (BuildContext context, GoRouterState state) =>
                    const ModulePlaceholder(
                      title: 'Stok',
                      icon: AppIcons.stock,
                      description:
                          'Operasyonel stok listesi ve stok detayı '
                          'sıradaki adımlarda eklenecek.',
                      showAppBar: false,
                    ),
              ),
            ],
          ),

          // 2 — Tara (merkezi aksiyon, şartname 10. bölüm)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.scan,
                name: AppRouteNames.scan,
                builder: (BuildContext context, GoRouterState state) =>
                    const ModulePlaceholder(
                      title: 'Barkod Tara',
                      icon: AppIcons.scan,
                      description:
                          'Kamera ile tarama ve demo barkod listesi '
                          'sıradaki adımlarda eklenecek.',
                      showAppBar: false,
                    ),
              ),
            ],
          ),

          // 3 — Siparişler
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.orders,
                name: AppRouteNames.orders,
                builder: (BuildContext context, GoRouterState state) =>
                    const ModulePlaceholder(
                      title: 'Siparişler',
                      icon: AppIcons.orders,
                      description:
                          'Sipariş listesi, detayı ve toplama akışı '
                          'sıradaki adımlarda eklenecek.',
                      showAppBar: false,
                    ),
              ),
            ],
          ),

          // 4 — Profil
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                name: AppRouteNames.profile,
                builder: (BuildContext context, GoRouterState state) =>
                    const ModulePlaceholder(
                      title: 'Profil',
                      icon: AppIcons.profile,
                      description:
                          'Kullanıcı bilgileri, yetkiler ve tema ayarı '
                          'sıradaki adımlarda eklenecek.',
                      showAppBar: false,
                    ),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------------------
      // Kabuğun üzerine itilen ekranlar
      // ---------------------------------------------------------------------

      // Ürünler (şartname 8. bölüm)
      GoRoute(
        path: AppRoutes.products,
        name: AppRouteNames.products,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(title: 'Ürünler', icon: AppIcons.products),
        routes: <RouteBase>[
          GoRoute(
            path: ':productId',
            name: AppRouteNames.productDetail,
            builder: (BuildContext context, GoRouterState state) =>
                const ModulePlaceholder(
                  title: 'Ürün Detayı',
                  icon: AppIcons.stock,
                ),
          ),
        ],
      ),

      // Mal kabul ve yerleştirme (şartname 11-12. bölümler)
      GoRoute(
        path: AppRoutes.receiving,
        name: AppRouteNames.receiving,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(
              title: 'Mal Kabul',
              icon: AppIcons.receiving,
            ),
        routes: <RouteBase>[
          GoRoute(
            path: ':receiptId',
            name: AppRouteNames.receiptDetail,
            builder: (BuildContext context, GoRouterState state) =>
                const ModulePlaceholder(
                  title: 'Mal Kabul Detayı',
                  icon: AppIcons.receiving,
                ),
            routes: <RouteBase>[
              GoRoute(
                path: 'putaway',
                name: AppRouteNames.putaway,
                builder: (BuildContext context, GoRouterState state) =>
                    const ModulePlaceholder(
                      title: 'Ürün Yerleştirme',
                      icon: AppIcons.locations,
                    ),
              ),
            ],
          ),
        ],
      ),

      // Sipariş detayı ve toplama (şartname 13-14. bölümler)
      GoRoute(
        path: '${AppRoutes.orders}/:orderId',
        name: AppRouteNames.orderDetail,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(
              title: 'Sipariş Detayı',
              icon: AppIcons.orders,
            ),
        routes: <RouteBase>[
          GoRoute(
            path: 'picking',
            name: AppRouteNames.picking,
            builder: (BuildContext context, GoRouterState state) =>
                const ModulePlaceholder(
                  title: 'Toplama Görevi',
                  icon: AppIcons.picking,
                ),
          ),
        ],
      ),

      // Transfer (şartname 15. bölüm)
      GoRoute(
        path: AppRoutes.transfer,
        name: AppRouteNames.transfer,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(
              title: 'Stok Transferi',
              icon: AppIcons.transfer,
            ),
      ),

      // Sayım (şartname 16. bölüm)
      GoRoute(
        path: AppRoutes.counts,
        name: AppRouteNames.counts,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(title: 'Stok Sayımı', icon: AppIcons.count),
        routes: <RouteBase>[
          GoRoute(
            path: ':countId',
            name: AppRouteNames.countDetail,
            builder: (BuildContext context, GoRouterState state) =>
                const ModulePlaceholder(
                  title: 'Sayım Detayı',
                  icon: AppIcons.count,
                ),
          ),
        ],
      ),

      // Sevkiyat (şartname 17. bölüm)
      GoRoute(
        path: AppRoutes.shipments,
        name: AppRouteNames.shipments,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(title: 'Sevkiyat', icon: AppIcons.shipment),
        routes: <RouteBase>[
          GoRoute(
            path: ':shipmentId',
            name: AppRouteNames.shipmentDetail,
            builder: (BuildContext context, GoRouterState state) =>
                const ModulePlaceholder(
                  title: 'Sevkiyat Detayı',
                  icon: AppIcons.shipment,
                ),
          ),
        ],
      ),

      // Lokasyonlar (şartname 18. bölüm)
      GoRoute(
        path: AppRoutes.locations,
        name: AppRouteNames.locations,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(
              title: 'Lokasyonlar',
              icon: AppIcons.locations,
            ),
        routes: <RouteBase>[
          GoRoute(
            path: ':locationId',
            name: AppRouteNames.locationDetail,
            builder: (BuildContext context, GoRouterState state) =>
                const ModulePlaceholder(
                  title: 'Lokasyon Detayı',
                  icon: AppIcons.locations,
                ),
          ),
        ],
      ),

      // Hareketler ve bildirimler (şartname 19-20. bölümler)
      GoRoute(
        path: AppRoutes.movements,
        name: AppRouteNames.movements,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(
              title: 'Stok Hareketleri',
              icon: AppIcons.movements,
            ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRouteNames.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(
              title: 'Bildirimler',
              icon: AppIcons.notifications,
            ),
      ),

      // Raporlar (şartname 22. bölüm)
      GoRoute(
        path: AppRoutes.reports,
        name: AppRouteNames.reports,
        builder: (BuildContext context, GoRouterState state) =>
            const ModulePlaceholder(title: 'Raporlar', icon: AppIcons.reports),
      ),
    ],

    // Bilinmeyen bir yola gidilirse boş ekran yerine açıklayıcı bir sayfa.
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Sayfa bulunamadı')),
      body: const ModulePlaceholder(
        title: 'Sayfa bulunamadı',
        icon: AppIcons.error,
        description: 'Aradığınız ekran mevcut değil.',
        showAppBar: false,
      ),
    ),
  );
});
