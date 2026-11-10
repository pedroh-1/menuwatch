import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../routes/router.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';
import '../widgets/common.dart';

enum _Action { readAll, clear }

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mw;
    final data = ref.watch(appProvider);
    final app = ref.read(appProvider.notifier);
    final enabled = ref.watch(notificationsEnabledProvider).value;
    final items = data.notifications;
    final unread = data.unreadCount;

    Future<void> enable() async {
      final granted = await ref.read(alertsProvider).requestPermission();
      ref.invalidate(notificationsEnabledProvider);
      if (!granted && context.mounted) {
        showMessage(
          context,
          'O Android não liberou as notificações. Ative-as nos ajustes do '
          'aparelho, em Apps, MenuWatch.',
        );
      }
    }

    Future<void> clear() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apagar todos os avisos?'),
          content: const Text(
            'A lista fica vazia. O histórico de mudanças de cada cardápio '
            'continua guardado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apagar'),
            ),
          ],
        ),
      );
      if (confirmed == true) await app.clearNotifications();
    }

    void open(AppNotification n) {
      if (!n.read) app.markRead(n.id);
      final menuId = n.menuId;
      if (menuId == null) return;
      if (data.menuById(menuId) == null) {
        showMessage(context, 'O cardápio deste aviso foi removido.');
        return;
      }
      context.push(
        Routes.menu(menuId, history: n.kind != NotificationKind.error),
      );
    }

    // O botão de opções tem 48 px de altura; o título fica na mesma altura
    // dos títulos das outras abas.
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text('Avisos', style: displayStyle(32, color: c.ink)),
          ),
          if (items.isNotEmpty)
            PopupMenuButton<_Action>(
              tooltip: 'Mais opções',
              icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: c.ink),
              onSelected: (action) => switch (action) {
                _Action.readAll => app.markAllRead(),
                _Action.clear => clear(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _Action.readAll,
                  enabled: unread > 0,
                  child: const Text('Marcar tudo como lido'),
                ),
                const PopupMenuItem(
                  value: _Action.clear,
                  child: Text('Apagar todos os avisos'),
                ),
              ],
            )
          else
            const SizedBox(height: 48),
        ],
      ),
    );

    final permission = enabled == false
        ? Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
            child: Note(
              icon: LucideIcons.bellOff,
              text:
                  'As notificações do Android estão desativadas. Os avisos '
                  'aparecem só aqui, quando você abre o app.',
              action: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                onPressed: enable,
                child: const Text('Ativar notificações'),
              ),
            ),
          )
        : null;

    if (items.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              ?permission,
              Expanded(
                child: EmptyState(
                  icon: LucideIcons.bell,
                  title: 'Nenhum aviso',
                  message: data.menus.isEmpty
                      ? 'Os avisos aparecem aqui depois que você adiciona um '
                            'cardápio e ele muda.'
                      : 'Quando um cardápio mudar ou um prato favorito '
                            'aparecer, o aviso fica guardado aqui.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final days = <String, List<AppNotification>>{};
    for (final n in items) {
      days.putIfAbsent(dayLabel(n.createdAt), () => []).add(n);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            header,
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
              child: Text(
                unread == 0
                    ? 'Tudo lido.'
                    : plural(unread, 'aviso não lido', 'avisos não lidos'),
                style: bodyStyle(15, color: c.inkSoft),
              ),
            ),
            ?permission,
            for (final day in days.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 24, gutter, 4),
                child: Text(
                  day.key,
                  style: bodyStyle(14, weight: 600, color: c.inkSoft),
                ),
              ),
              for (final n in day.value)
                _NotificationRow(
                  key: ValueKey(n.id),
                  notification: n,
                  onTap: () => open(n),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final n = notification;
    final (icon, fg, bg) = switch (n.kind) {
      NotificationKind.favorite => (LucideIcons.heart, c.red, c.redSoft),
      NotificationKind.menuChanged => (
        LucideIcons.utensils,
        c.primary,
        c.primarySoft,
      ),
      NotificationKind.error => (
        LucideIcons.triangleAlert,
        c.inkSoft,
        c.surfaceAlt,
      ),
    };
    return Semantics(
      label: n.read ? null : 'Não lido',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: bodyStyle(
                        15.5,
                        weight: n.read ? 500 : 700,
                        color: n.read ? c.inkSoft : c.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      style: bodyStyle(14, color: c.inkSoft, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    clockTime(n.createdAt),
                    style: bodyStyle(12.5, color: c.inkFaint, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    opacity: n.read ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
