import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Agrupa itens por categoria, preservando a ordem em que aparecem.
Map<String, List<T>> groupByCategory<T>(
  Iterable<T> items,
  String Function(T item) category,
) {
  final groups = <String, List<T>>{};
  for (final item in items) {
    groups.putIfAbsent(category(item), () => []).add(item);
  }
  return groups;
}

/// Título de categoria dentro de um cardápio.
class CategoryTitle extends StatelessWidget {
  const CategoryTitle(this.title, {super.key, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 22, gutter, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              title,
              style: displayStyle(18, weight: 650, color: c.primary),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text('$count', style: bodyStyle(13.5, color: c.inkFaint)),
          ],
        ],
      ),
    );
  }
}

/// Linha fina entre dois pratos da mesma categoria.
class DishDivider extends StatelessWidget {
  const DishDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(indent: gutter, endIndent: gutter, height: 1);
}
