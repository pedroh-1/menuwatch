import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import 'brand_mark.dart';

/// Título de uma seção da tela, com uma ação opcional à direita.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.count});

  final String title;
  final Widget? action;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 28, gutter - 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                children: [
                  if (count != null)
                    TextSpan(
                      text: '  $count',
                      style: displayStyle(19, weight: 500, color: c.inkFaint),
                    ),
                ],
              ),
              style: displayStyle(19, weight: 600, color: c.ink),
            ),
          ),
          if (action != null) action! else const SizedBox(height: 44, width: 8),
        ],
      ),
    );
  }
}

/// Lista agrupada: uma única superfície com linhas finas entre os itens.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.inset = 56});

  final List<Widget> children;

  /// Recuo da linha divisória, alinhado ao início do texto dos itens.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: gutter - 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(indent: inset, height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Linha de lista com ícone, título, texto de apoio e algo à direita.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.chevron = false,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (icon != null)
                Icon(icon, size: 22, color: c.inkSoft),
              if (leading != null || icon != null) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: bodyStyle(16, weight: 600, color: c.ink, height: 1.25),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: bodyStyle(
                          13.5,
                          color: subtitleColor ?? c.inkSoft,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight, size: 18, color: c.inkFaint),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

IconData sourceIcon(SourceType type) => switch (type) {
  SourceType.html => LucideIcons.globe,
  SourceType.dynamicPage => LucideIcons.monitorSmartphone,
  SourceType.canva => LucideIcons.layoutTemplate,
  SourceType.pdf => LucideIcons.fileText,
  SourceType.image => LucideIcons.image,
};

/// Quadradinho com o ícone do tipo de fonte do cardápio.
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.type, {super.key, this.size = 40});

  final SourceType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(sourceIcon(type), size: size * 0.48, color: c.primary),
    );
  }
}

/// Tela sem conteúdo: desenho, o que falta e o que fazer.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                EmptyPlate(color: c.primary),
                if (icon != null) Icon(icon, size: 30, color: c.primary),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: displayStyle(23, color: c.ink),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: bodyStyle(15, color: c.inkSoft, height: 1.45),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Barra de carregamento que pulsa, no formato do conteúdo que virá.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, this.width, this.height = 14});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 1, end: 0.45, duration: 800.ms, curve: Curves.easeInOut);
  }
}

/// Linhas de pratos em carregamento.
class DishSkeleton extends StatelessWidget {
  const DishSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    const widths = [0.62, 0.48, 0.7, 0.4, 0.56, 0.66];
    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  SkeletonBar(width: box.maxWidth * widths[i % widths.length]),
                  const Spacer(),
                  const SkeletonBar(width: 52),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Aviso em linha: explica uma condição do conteúdo ao lado.
class Note extends StatelessWidget {
  const Note({
    super.key,
    required this.text,
    this.icon = LucideIcons.info,
    this.tone = NoteTone.neutral,
    this.action,
  });

  final String text;
  final IconData icon;
  final NoteTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final (bg, fg) = switch (tone) {
      NoteTone.neutral => (c.surfaceAlt, c.inkSoft),
      NoteTone.error => (c.redSoft, c.red),
      NoteTone.success => (c.greenSoft, c.green),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: bodyStyle(
                    14,
                    color: tone == NoteTone.neutral ? c.inkSoft : c.ink,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 4), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum NoteTone { neutral, error, success }

/// Controle de duas ou três opções lado a lado.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final keys = options.keys.toList();
    final index = keys.indexOf(value).clamp(0, keys.length - 1);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              keys.length == 1 ? 0 : -1 + 2 * index / (keys.length - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / keys.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final key in keys)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: key == value,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(key),
                      child: Center(
                        child: Text(
                          options[key]!,
                          style: bodyStyle(
                            14.5,
                            weight: key == value ? 700 : 500,
                            color: key == value ? c.ink : c.inkSoft,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
