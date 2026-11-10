import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/add_menu_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/menu_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../widgets/app_shell.dart';

abstract final class Routes {
  static const splash = '/abertura';
  static const home = '/';
  static const favorites = '/favoritos';
  static const notifications = '/avisos';
  static const settings = '/ajustes';
  static const add = '/adicionar';
  static String menu(String id, {bool history = false}) =>
      '/cardapio/$id${history ? '?aba=historico' : ''}';
}

/// Trocado nos testes para pular a abertura.
final initialLocationProvider = Provider<String>((ref) => Routes.splash);

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => CustomTransitionPage(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          child: AppShell(shell: shell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.add,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: AddMenuScreen(),
        ),
      ),
      GoRoute(
        path: '/cardapio/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => MenuDetailScreen(
          menuId: state.pathParameters['id']!,
          openHistory: state.uri.queryParameters['aba'] == 'historico',
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
