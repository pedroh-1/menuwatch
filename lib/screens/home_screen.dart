import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../routes/router.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';
import '../widgets/brand_mark.dart';
import '../widgets/change_row.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mw;
    final data = ref.watch(appProvider);
    final checking = ref.watch(checkingProvider);
    final name = data.settings.userName.trim();
    final hello = greeting(DateTime.now());

    final menus = [...data.menus]
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final today = [
      for (final m in data.menus)
        for (final d in m.dishes)
          if (d.favorite && d.availableNow) (m, d),
    ];
    final recent = data.history.take(5).toList();

    Future<void> refresh() async {
      final failures = await ref.read(appProvider.notifier).checkAll();
      if (!context.mounted) return;
      showMessage(
        context,
        failures == 0
            ? 'Cardápios verificados.'
            : '${plural(failures, 'cardápio não pôde', 'cardápios não puderam')} '
                  'ser lido${failures == 1 ? '' : 's'} agora.',
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandMark(
                size: 26,
                ring: c.primary,
                dot: c.accent,
                background: c.bg,
              ),
              const SizedBox(width: 6),
              Text(
                'MenuWatch',
                style: displayStyle(17, weight: 700, color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            name.isEmpty ? hello : '$hello, $name',
            style: displayStyle(32, color: c.ink),
          ),
        ],
      ),
    );

    if (menus.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: EmptyState(
                  icon: LucideIcons.utensils,
                  title: 'Nenhum cardápio por aqui',
                  message:
                      'Cole o link de um cardápio (site, PDF, imagem ou '
                      'Canva) e o MenuWatch avisa quando ele mudar.',
                  action: FilledButton.icon(
                    onPressed: () => context.push(Routes.add),
                    icon: const Icon(LucideIcons.plus, size: 20),
                    label: const Text('Adicionar cardápio'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lastCheck = data.menus
        .map((m) => m.lastCheckedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.add),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Adicionar cardápio'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: refresh,
          color: c.primary,
          backgroundColor: c.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 104),
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 6, gutter, 0),
                child: Text(
                  checking.isNotEmpty
                      ? 'Verificando os cardápios…'
                      : lastCheck == null
                      ? 'Ainda sem verificações.'
                      : 'Última verificação ${relativeTime(lastCheck)}.',
                  style: bodyStyle(15, color: c.inkSoft),
                ),
              ),
              if (today.isNotEmpty) _TodayBlock(items: today),
              SectionTitle('Seus cardápios', count: menus.length),
              GroupedList(
                inset: 72,
                children: [
                  for (final m in menus)
                    _MenuRow(menu: m, checking: checking.contains(m.id)),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SectionTitle('Últimas mudanças'),
                GroupedList(
                  children: [
                    for (final h in recent)
                      ChangeRow(
                        entry: h,
                        time: relativeTime(h.detectedAt),
                        context2: data.menuById(h.menuId)?.name,
                        onTap: () =>
                            context.push(Routes.menu(h.menuId, history: true)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Destaque do dia: favoritos que o cardápio confirma para hoje.
class _TodayBlock extends StatelessWidget {
  const _TodayBlock({required this.items});

  final List<(Menu, Dish)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final soft = c.onFeature.withValues(alpha: 0.72);
    return Container(
      margin: const EdgeInsets.fromLTRB(gutter - 4, 22, gutter - 4, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 10),
      decoration: BoxDecoration(
        color: c.feature,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text(
                items.length == 1
                    ? 'Seu favorito está disponível hoje'
                    : 'Seus favoritos disponíveis hoje',
                style: bodyStyle(14.5, weight: 600, color: soft, height: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (menu, dish) in items)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(Routes.menu(menu.id)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 9, 4, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.name,
                            style: displayStyle(
                              21,
                              weight: 600,
                              color: c.onFeature,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dish.price == null
                                ? menu.name
                                : '${menu.name}, ${formatPrice(dish.price!)}',
                            style: bodyStyle(14, color: soft, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: soft),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.menu, required this.checking});

  final Menu menu;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final count = plural(menu.presentDishes.length, 'prato', 'pratos');
    final (String text, Color? color) = switch (menu.status) {
      _ when checking => ('Verificando…', null),
      MenuStatus.error => ('Não foi possível ler na última tentativa', c.red),
      MenuStatus.waitingApp => ('$count, verificado só com o app aberto', null),
      MenuStatus.ok => (
        menu.lastCheckedAt == null
            ? count
            : '$count, verificado ${relativeTime(menu.lastCheckedAt!)}',
        null,
      ),
    };
    return ListRow(
      leading: SourceBadge(menu.sourceType),
      title: menu.name,
      subtitle: text,
      subtitleColor: color,
      chevron: !checking,
      trailing: checking
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
            )
          : menu.favorite
          ? Icon(LucideIcons.pin, size: 16, color: c.accent)
          : null,
      onTap: () => context.push(Routes.menu(menu.id)),
    );
  }
}
