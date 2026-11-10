import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/providers.dart';
import '../theme/tokens.dart';

/// Moldura das quatro áreas principais, com a barra de navegação.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mw;
    final unread = ref.watch(appProvider.select((d) => d.unreadCount));
    final index = shell.currentIndex;

    return PopScope(
      // Voltar em qualquer aba leva ao Início antes de sair do app.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == index),
            destinations: [
              const NavigationDestination(
                icon: Icon(LucideIcons.house),
                label: 'Início',
              ),
              const NavigationDestination(
                icon: Icon(LucideIcons.heart),
                label: 'Favoritos',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: c.accent,
                  textColor: const Color(0xFF2B1D00),
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(LucideIcons.bell),
                ),
                label: 'Avisos',
              ),
              const NavigationDestination(
                icon: Icon(LucideIcons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
