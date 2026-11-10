import '../models/models.dart';
import '../utils/text_utils.dart';
import 'parser/menu_parser.dart';

class DiffResult {
  const DiffResult({required this.dishes, required this.changes});

  final List<Dish> dishes;
  final List<ChangeEntry> changes;
}

/// Converte o resultado de uma primeira leitura em pratos, sem histórico.
List<Dish> dishesFromParsed(ParsedMenu parsed, {DateTime? now}) => [
  for (final p in parsed.dishes)
    Dish(
      id: newId(),
      name: p.name,
      description: p.description,
      price: p.price,
      category: p.category,
      availability: p.availability,
      firstSeenAt: now,
      lastSeenAt: now,
    ),
];

/// Compara a leitura nova com o que estava guardado. Pratos são casados
/// pelo nome, ignorando maiúsculas, acentos e pontuação.
DiffResult diffMenu(Menu menu, ParsedMenu parsed, {DateTime? now}) {
  final when = now ?? DateTime.now();
  final old = {for (final d in menu.dishes) fold(d.name): d};
  final matched = <String>{};
  final dishes = <Dish>[];
  final changes = <ChangeEntry>[];

  void record(Dish dish, ChangeType type, String description) {
    changes.add(
      ChangeEntry(
        id: newId(),
        menuId: menu.id,
        dishId: dish.id,
        dishName: dish.name,
        type: type,
        description: description,
        detectedAt: when,
      ),
    );
  }

  for (final p in parsed.dishes) {
    final key = fold(p.name);
    final before = old[key];
    matched.add(key);

    if (before == null) {
      final dish = Dish(
        id: newId(),
        name: p.name,
        description: p.description,
        price: p.price,
        category: p.category,
        availability: p.availability,
        firstSeenAt: when,
        lastSeenAt: when,
      );
      dishes.add(dish);
      record(
        dish,
        ChangeType.added,
        p.price == null
            ? 'Entrou no cardápio'
            : 'Entrou no cardápio por ${formatPrice(p.price!)}',
      );
      continue;
    }

    final dish = before.copyWith(
      name: p.name,
      description: p.description,
      price: p.price,
      clearPrice: p.price == null,
      category: p.category,
      availability: p.availability,
      present: true,
      lastSeenAt: when,
    );
    dishes.add(dish);

    if (!before.present) {
      record(dish, ChangeType.returned, 'Voltou ao cardápio');
      continue;
    }
    if (before.price != null &&
        p.price != null &&
        (before.price! - p.price!).abs() > 0.004) {
      record(
        dish,
        ChangeType.price,
        'De ${formatPrice(before.price!)} para ${formatPrice(p.price!)}',
      );
    }
    // Voltar a "não identificada" (a data do cardápio ficou para trás) não
    // é novidade para ninguém; só o que confirma ou nega entra no histórico.
    if (before.availability != p.availability &&
        p.availability != Availability.unknown) {
      record(dish, ChangeType.availability, p.availability.label);
    }
  }

  for (final entry in old.entries) {
    if (matched.contains(entry.key)) continue;
    final before = entry.value;
    if (!before.present) {
      dishes.add(before);
      continue;
    }
    record(before, ChangeType.removed, 'Saiu do cardápio');
    if (before.favorite) {
      dishes.add(
        before.copyWith(present: false, availability: Availability.unknown),
      );
    }
  }

  return DiffResult(dishes: dishes, changes: changes);
}
