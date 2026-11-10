import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

(IconData, Color, Color) changeLook(BuildContext context, ChangeType type) {
  final c = context.mw;
  return switch (type) {
    ChangeType.added => (LucideIcons.plus, c.green, c.greenSoft),
    ChangeType.returned => (LucideIcons.arrowUpRight, c.green, c.greenSoft),
    ChangeType.removed => (LucideIcons.minus, c.red, c.redSoft),
    ChangeType.price => (LucideIcons.tag, c.primary, c.primarySoft),
    ChangeType.availability => (
      LucideIcons.calendarCheck,
      c.primary,
      c.primarySoft,
    ),
  };
}

/// Uma mudança registrada: o que aconteceu, com qual prato e quando.
class ChangeRow extends StatelessWidget {
  const ChangeRow({
    super.key,
    required this.entry,
    required this.time,
    this.context2,
    this.showDish = true,
    this.onTap,
  });

  final ChangeEntry entry;

  /// Texto já formatado do momento ("há 12 min", "09:30").
  final String time;

  /// Complemento da descrição, como o nome do cardápio.
  final String? context2;

  /// Falso quando a lista já é de um prato só e repetir o nome não ajuda.
  final bool showDish;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final (icon, fg, bg) = changeLook(context, entry.type);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDish) ...[
                    Text(
                      entry.dishName,
                      style: bodyStyle(
                        15.5,
                        weight: 600,
                        color: c.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context2 == null
                          ? entry.description
                          : '${entry.description} em $context2',
                      style: bodyStyle(13.5, color: c.inkSoft, height: 1.35),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        entry.description,
                        style: bodyStyle(15, color: c.ink, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: EdgeInsets.only(top: showDish ? 2 : 7),
              child: Text(
                time,
                style: bodyStyle(12.5, color: c.inkFaint, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
