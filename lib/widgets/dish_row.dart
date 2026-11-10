import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';

/// Texto curto e cor para a situação de um prato hoje.
(String, Color) availabilityInfo(BuildContext context, Dish dish) {
  final c = context.mw;
  if (!dish.present) return ('Fora do cardápio', c.inkFaint);
  return switch (dish.availability) {
    Availability.confirmed => ('Disponível hoje', c.green),
    Availability.unavailable => ('Indisponível', c.red),
    Availability.unknown => (
      'No cardápio, sem confirmação para hoje',
      c.inkSoft,
    ),
  };
}

/// Linha de prato como em um cardápio impresso: nome, pontilhado e preço.
class DishRow extends StatelessWidget {
  const DishRow({
    super.key,
    required this.name,
    this.description,
    this.price,
    this.status,
    this.statusColor,
    this.favorite,
    this.onToggleFavorite,
    this.onTap,
    this.muted = false,
    this.padding = const EdgeInsets.symmetric(horizontal: gutter),
  });

  final String name;
  final String? description;
  final double? price;

  /// Linha de situação abaixo do nome ("Disponível hoje", "Indisponível"…).
  final String? status;
  final Color? statusColor;

  /// Nulo esconde o coração.
  final bool? favorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTap;
  final bool muted;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final nameStyle = bodyStyle(
      16,
      weight: 600,
      color: muted ? c.inkFaint : c.ink,
      height: 1.3,
    );
    final priceStyle = displayStyle(
      16,
      weight: 600,
      color: muted ? c.inkFaint : c.ink,
      height: 1.3,
    );
    final priceText = price == null ? null : formatPrice(price!);
    final hasHeart = favorite != null;
    // O coração ocupa 48 px; a primeira linha do nome fica centrada nele.
    final firstLine = MediaQuery.textScalerOf(context).scale(16) * 1.3;
    final textTop = hasHeart ? ((48 - firstLine) / 2).clamp(0.0, 12.0) : 12.0;

    final content = Padding(
      padding: EdgeInsets.only(
        left: padding.left,
        right: hasHeart ? padding.right - 12 : padding.right,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: textTop, bottom: textTop),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (priceText == null)
                    Text(name, style: nameStyle)
                  else
                    _NameAndPrice(
                      name: name,
                      price: priceText,
                      nameStyle: nameStyle,
                      priceStyle: priceStyle,
                      leader: c.inkFaint.withValues(alpha: 0.7),
                    ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle(13.5, color: c.inkSoft, height: 1.4),
                    ),
                  ],
                  if (status != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor ?? c.inkSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            status!,
                            style: bodyStyle(
                              13,
                              weight: 600,
                              color: statusColor ?? c.inkSoft,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasHeart)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: FavoriteButton(
                active: favorite!,
                onPressed: onToggleFavorite,
                label: favorite!
                    ? 'Tirar $name dos favoritos'
                    : 'Favoritar $name',
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _NameAndPrice extends StatelessWidget {
  const _NameAndPrice({
    required this.name,
    required this.price,
    required this.nameStyle,
    required this.priceStyle,
    required this.leader,
  });

  final String name;
  final String price;
  final TextStyle nameStyle;
  final TextStyle priceStyle;
  final Color leader;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final pricePainter = TextPainter(
          text: TextSpan(text: price, style: priceStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        // O pontilhado nunca some: sobra ao menos um trecho entre nome e preço.
        final maxName = (box.maxWidth - pricePainter.width - 30).clamp(
          60.0,
          box.maxWidth,
        );
        final namePainter = TextPainter(
          text: TextSpan(text: name, style: nameStyle),
          textDirection: direction,
          textScaler: scaler,
          textWidthBasis: TextWidthBasis.longestLine,
        )..layout(maxWidth: maxName);
        final nameWidth = namePainter.width;
        final baseline = namePainter.computeDistanceToActualBaseline(
          TextBaseline.alphabetic,
        );
        pricePainter.dispose();
        namePainter.dispose();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: nameWidth + 0.5,
              child: Text(name, style: nameStyle),
            ),
            // O espaço em branco dá ao pontilhado a mesma linha de base do
            // nome e do preço.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Stack(
                  children: [
                    Text(' ', style: nameStyle, maxLines: 1),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LeaderPainter(leader, baseline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(price, style: priceStyle, maxLines: 1),
          ],
        );
      },
    );
  }
}

class _LeaderPainter extends CustomPainter {
  _LeaderPainter(this.color, this.baseline);
  final Color color;

  /// Distância do topo até a linha de base do texto ao lado.
  final double baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 6.0;
    // Alinha os pontos à direita, junto do preço.
    for (var x = size.width - 1; x >= 1; x -= gap) {
      canvas.drawCircle(Offset(x, baseline - 1.2), 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(_LeaderPainter old) =>
      old.color != color || old.baseline != baseline;
}

/// Coração de favorito, com um pequeno salto ao ser marcado.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.active,
    required this.onPressed,
    required this.label,
  });

  final bool active;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final icon = active
        ? Icon(Icons.favorite_rounded, size: 22, color: c.red)
        : Icon(LucideIcons.heart, size: 21, color: c.inkFaint);
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            Icon(
                  Icons.favorite_rounded,
                  size: 22,
                  color: c.red.withValues(alpha: 0.22),
                )
                .animate(key: const ValueKey('halo'))
                .scaleXY(
                  begin: 1,
                  end: 1.9,
                  duration: 380.ms,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 380.ms),
          active
              ? icon
                    .animate(key: const ValueKey('on'))
                    .scaleXY(
                      begin: 0.7,
                      end: 1,
                      duration: 320.ms,
                      curve: Curves.easeOutBack,
                    )
              : icon,
        ],
      ),
    );
  }
}
