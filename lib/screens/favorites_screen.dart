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
import '../widgets/dish_list.dart';
import '../widgets/dish_row.dart';
import '../widgets/dish_sheet.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mw;
    final data = ref.watch(appProvider);
    final app = ref.read(appProvider.notifier);

    final byMenu = <Menu, List<Dish>>{
      for (final m in data.menus)
        if (m.dishes.any((d) => d.favorite))
          m: m.dishes.where((d) => d.favorite).toList()
            ..sort((a, b) {
              if (a.availableNow != b.availableNow) {
                return a.availableNow ? -1 : 1;
              }
              if (a.present != b.present) return a.present ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }),
    };
    final pinned = data.menus.where((m) => m.favorite).toList();
    final total = byMenu.values.fold<int>(0, (sum, l) => sum + l.length);
    final availableNow = byMenu.values
        .expand((l) => l)
        .where((d) => d.availableNow)
        .length;

    final title = Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
      child: Text('Favoritos', style: displayStyle(32, color: c.ink)),
    );

    if (total == 0 && pinned.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              Expanded(
                child: EmptyState(
                  icon: LucideIcons.heart,
                  title: 'Nenhum favorito ainda',
                  message: data.menus.isEmpty
                      ? 'Adicione um cardápio e toque no coração ao lado dos '
                            'pratos que você não quer perder.'
                      : 'Abra um cardápio e toque no coração ao lado de um '
                            'prato. O MenuWatch avisa quando ele aparecer.',
                  action: data.menus.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => context.push(Routes.add),
                          icon: const Icon(LucideIcons.plus, size: 20),
                          label: const Text('Adicionar cardápio'),
                        )
                      : OutlinedButton(
                          onPressed: () => context.go(Routes.home),
                          child: const Text('Ver cardápios'),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            title,
            if (total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 6, gutter, 0),
                child: Text(
                  availableNow == 0
                      ? '${plural(total, 'prato favorito', 'pratos favoritos')}, '
                            'nenhum confirmado para hoje.'
                      : '${plural(availableNow, 'disponível', 'disponíveis')} '
                            'hoje, de ${plural(total, 'prato favorito', 'pratos favoritos')}.',
                  style: bodyStyle(15, color: c.inkSoft),
                ),
              ),
            for (final entry in byMenu.entries) ...[
              InkWell(
                onTap: () => context.push(Routes.menu(entry.key.id)),
                child: Row(
                  children: [
                    Expanded(child: CategoryTitle(entry.key.name)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 20, gutter - 4, 0),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < entry.value.length; i++) ...[
                if (i > 0) const DishDivider(),
                _row(context, app, entry.key, entry.value[i]),
              ],
            ],
            if (total == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 10, gutter, 0),
                child: Text(
                  'Nenhum prato favorito ainda. Abra um cardápio e toque no '
                  'coração ao lado de um prato.',
                  style: bodyStyle(15, color: c.inkSoft, height: 1.45),
                ),
              ),
            if (pinned.isNotEmpty) ...[
              SectionTitle('Cardápios fixados', count: pinned.length),
              GroupedList(
                inset: 72,
                children: [
                  for (final m in pinned)
                    ListRow(
                      leading: SourceBadge(m.sourceType),
                      title: m.name,
                      subtitle: plural(
                        m.presentDishes.length,
                        'prato',
                        'pratos',
                      ),
                      chevron: true,
                      onTap: () => context.push(Routes.menu(m.id)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppController app, Menu menu, Dish dish) {
    final (status, color) = availabilityInfo(context, dish);
    return DishRow(
      key: ValueKey(dish.id),
      name: dish.name,
      price: dish.present ? dish.price : null,
      status: status,
      statusColor: color,
      muted: !dish.present,
      favorite: true,
      onToggleFavorite: () async {
        await app.toggleDishFavorite(menu.id, dish.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${dish.name} saiu dos favoritos.'),
              action: dish.present
                  ? SnackBarAction(
                      label: 'Desfazer',
                      onPressed: () =>
                          app.toggleDishFavorite(menu.id, dish.id),
                    )
                  : null,
            ),
          );
      },
      onTap: () => showDishSheet(
        context,
        menuId: menu.id,
        dishId: dish.id,
        linkToMenu: true,
      ),
    );
  }
}
