import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../routes/router.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';
import 'change_row.dart';
import 'dish_row.dart';

/// Abre os detalhes de um prato: situação hoje, preço e histórico.
Future<void> showDishSheet(
  BuildContext context, {
  required String menuId,
  required String dishId,
  bool linkToMenu = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _DishSheet(menuId: menuId, dishId: dishId, linkToMenu: linkToMenu),
);

class _DishSheet extends ConsumerWidget {
  const _DishSheet({
    required this.menuId,
    required this.dishId,
    required this.linkToMenu,
  });

  final String menuId;
  final String dishId;
  final bool linkToMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mw;
    final data = ref.watch(appProvider);
    final menu = data.menuById(menuId);
    Dish? dish;
    for (final d in menu?.dishes ?? const <Dish>[]) {
      if (d.id == dishId) dish = d;
    }
    // O prato pode sair da lista com a folha aberta (deixou de ser favorito
    // depois de sair do cardápio).
    if (menu == null || dish == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 32),
        child: Text(
          'Este prato não está mais na lista.',
          style: bodyStyle(15, color: c.inkSoft),
        ),
      );
    }
    final found = dish;
    final history = data.history.where((h) => h.dishId == found.id).toList();
    final (status, statusColor) = availabilityInfo(context, found);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 0, gutter - 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(found.name, style: displayStyle(24, color: c.ink)),
                      const SizedBox(height: 4),
                      Text(
                        '${found.category} em ${menu.name}',
                        style: bodyStyle(14, color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
                FavoriteButton(
                  active: found.favorite,
                  label: found.favorite
                      ? 'Tirar dos favoritos'
                      : 'Favoritar este prato',
                  onPressed: () => ref
                      .read(appProvider.notifier)
                      .toggleDishFavorite(menuId, dishId),
                ),
              ],
            ),
          ),
          if (found.description != null && found.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
              child: Text(
                found.description!,
                style: bodyStyle(15, color: c.inkSoft, height: 1.45),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: 'Preço',
                    value: found.price == null
                        ? 'Não informado'
                        : formatPrice(found.price!),
                    display: found.price != null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _Fact(
                    label: 'Hoje',
                    value: status,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (found.present && found.availability == Availability.unknown)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 10, gutter, 0),
              child: Text(
                'O cardápio não informa em que dia este prato é servido.',
                style: bodyStyle(13.5, color: c.inkFaint, height: 1.4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 24, gutter, 6),
            child: Text(
              'Histórico',
              style: displayStyle(17, weight: 600, color: c.ink),
            ),
          ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: Text(
                'Nenhuma mudança desde ${shortDate(found.firstSeenAt)}, '
                'quando o prato foi visto pela primeira vez.',
                style: bodyStyle(14.5, color: c.inkSoft, height: 1.45),
              ),
            )
          else
            for (final h in history.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: gutter - 14),
                child: ChangeRow(
                  entry: h,
                  time: relativeTime(h.detectedAt),
                  showDish: false,
                ),
              ),
          if (linkToMenu)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(Routes.menu(menuId));
                },
                icon: const Icon(LucideIcons.utensils, size: 18),
                label: const Text('Abrir cardápio'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.color,
    this.display = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool display;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: bodyStyle(12.5, weight: 500, color: c.inkSoft)),
          const SizedBox(height: 4),
          Text(
            value,
            style: display
                ? displayStyle(18, weight: 600, color: color ?? c.ink)
                : bodyStyle(
                    15,
                    weight: 600,
                    color: color ?? c.ink,
                    height: 1.3,
                  ),
          ),
        ],
      ),
    );
  }
}
