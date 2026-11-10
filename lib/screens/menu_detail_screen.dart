import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/extraction/fetcher.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';
import '../widgets/change_row.dart';
import '../widgets/common.dart';
import '../widgets/dish_list.dart';
import '../widgets/dish_row.dart';
import '../widgets/dish_sheet.dart';

enum _Tab { dishes, history }

enum _Action { open, rename, changeUrl, pin, delete }

class MenuDetailScreen extends ConsumerStatefulWidget {
  const MenuDetailScreen({
    super.key,
    required this.menuId,
    this.openHistory = false,
  });

  final String menuId;
  final bool openHistory;

  @override
  ConsumerState<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends ConsumerState<MenuDetailScreen> {
  late var _tab = widget.openHistory ? _Tab.history : _Tab.dishes;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  AppController get _app => ref.read(appProvider.notifier);

  Future<void> _refresh() async {
    final before = ref.read(appProvider).history.length;
    final failure = await _app.checkMenu(widget.menuId);
    if (!mounted) return;
    final found = ref.read(appProvider).history.length - before;
    showMessage(
      context,
      failure != null
          ? failure.message
          : found > 0
          ? '${plural(found, 'mudança encontrada', 'mudanças encontradas')}.'
          : 'Nenhuma mudança desde a última verificação.',
    );
  }

  Future<void> _openLink(Menu menu) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(menu.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      showMessage(context, 'Nenhum app do celular conseguiu abrir este link.');
    }
  }

  Future<void> _rename(Menu menu) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _TextDialog(
        title: 'Renomear cardápio',
        label: 'Nome',
        initial: menu.name,
        confirm: 'Salvar',
        maxLength: 60,
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == menu.name) return;
    await _app.renameMenu(menu.id, name);
  }

  Future<void> _changeUrl(Menu menu) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChangeUrlDialog(menu: menu),
    );
    if (changed == true && mounted) {
      showMessage(context, 'Link trocado. O cardápio foi lido de novo.');
    }
  }

  Future<void> _delete(Menu menu) async {
    final c = context.mw;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${menu.name}?'),
        content: const Text(
          'O cardápio deixa de ser acompanhado. Os pratos favoritos, o '
          'histórico e os avisos dele também são apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _app.deleteMenu(menu.id);
    router.pop();
    messenger.showSnackBar(SnackBar(content: Text('${menu.name} removido.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    final data = ref.watch(appProvider);
    final menu = data.menuById(widget.menuId);
    final checking = ref.watch(checkingProvider).contains(widget.menuId);

    if (menu == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          title: 'Cardápio não encontrado',
          message: 'Ele pode ter sido removido. Volte e escolha outro.',
        ),
      );
    }

    final history = data.history.where((h) => h.menuId == menu.id).toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (checking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primary,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Verificar agora',
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: _refresh,
            ),
          PopupMenuButton<_Action>(
            tooltip: 'Mais opções',
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            onSelected: (action) => switch (action) {
              _Action.open => _openLink(menu),
              _Action.rename => _rename(menu),
              _Action.changeUrl => _changeUrl(menu),
              _Action.pin => _app.togglePinned(menu.id),
              _Action.delete => _delete(menu),
            },
            itemBuilder: (context) => [
              _item(_Action.open, LucideIcons.externalLink, 'Abrir link'),
              _item(
                _Action.pin,
                menu.favorite ? LucideIcons.pinOff : LucideIcons.pin,
                menu.favorite ? 'Desafixar do topo' : 'Fixar no topo',
              ),
              _item(_Action.rename, LucideIcons.pencil, 'Renomear'),
              _item(_Action.changeUrl, LucideIcons.link, 'Trocar link'),
              _item(_Action.delete, LucideIcons.trash2, 'Remover', c.red),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context, menu, checking)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
                child: Segmented<_Tab>(
                  value: _tab,
                  options: {
                    _Tab.dishes: 'Pratos',
                    _Tab.history: history.isEmpty
                        ? 'Histórico'
                        : 'Histórico (${history.length})',
                  },
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
            ),
            if (_tab == _Tab.dishes)
              ..._dishSlivers(context, menu)
            else
              ..._historySlivers(context, menu, history),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_Action> _item(
    _Action action,
    IconData icon,
    String label, [
    Color? color,
  ]) {
    final c = context.mw;
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? c.inkSoft),
          const SizedBox(width: 14),
          Text(label, style: bodyStyle(15, weight: 500, color: color ?? c.ink)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Menu menu, bool checking) {
    final c = context.mw;
    final date = menu.referenceDate;
    final isToday = date != null && sameDay(date, DateTime.now());
    final anyConfirmed = menu.presentDishes.any(
      (d) => d.availability == Availability.confirmed,
    );

    final checked = checking
        ? 'Verificando agora…'
        : menu.lastCheckedAt == null
        ? 'Ainda não verificado'
        : 'Verificado ${relativeTime(menu.lastCheckedAt!)}';

    Widget? note;
    if (menu.status == MenuStatus.error) {
      note = Note(
        tone: NoteTone.error,
        icon: LucideIcons.circleAlert,
        text:
            '${menu.lastError ?? 'Não foi possível ler o cardápio.'} Os '
            'pratos abaixo são da última leitura que deu certo.',
        action: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            foregroundColor: c.red,
          ),
          onPressed: checking ? null : _refresh,
          child: const Text('Tentar de novo'),
        ),
      );
    } else if (isToday) {
      note = Note(
        tone: NoteTone.success,
        icon: LucideIcons.calendarCheck,
        text: menu.presentDishes.every(
              (d) => d.availability != Availability.unknown,
            )
            ? 'Cardápio de hoje, ${shortDate(date)}. Os pratos abaixo estão '
                  'confirmados para hoje.'
            : 'Cardápio de hoje, ${shortDate(date)}.',
      );
    } else if (date != null) {
      note = Note(
        icon: LucideIcons.calendar,
        text:
            'Este cardápio é de ${shortDate(date)}. Enquanto ele não for '
            'atualizado, nenhum prato aparece como disponível hoje.',
      );
    } else if (!anyConfirmed) {
      note = const Note(
        text:
            'Este cardápio não informa a data. O app acompanha o que entra, '
            'sai e muda de preço, mas não afirma que um prato é servido hoje.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(menu.name, style: displayStyle(30, color: c.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(sourceIcon(menu.sourceType), size: 15, color: c.inkSoft),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '${menu.sourceType.label} em ${hostOf(menu.url)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(14, color: c.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(checked, style: bodyStyle(14, color: c.inkSoft)),
          if (menu.sourceType.needsBrowser) ...[
            const SizedBox(height: 3),
            Text(
              'Só é verificado com o app aberto.',
              style: bodyStyle(14, color: c.inkSoft),
            ),
          ],
          if (note != null) ...[const SizedBox(height: 16), note],
        ],
      ),
    );
  }

  List<Widget> _dishSlivers(BuildContext context, Menu menu) {
    final c = context.mw;
    final present = menu.presentDishes;
    final gone = menu.dishes.where((d) => !d.present).toList();
    final query = fold(_search.text);
    final visible = query.isEmpty
        ? present
        : present
              .where(
                (d) =>
                    fold(d.name).contains(query) ||
                    fold(d.description ?? '').contains(query),
              )
              .toList();
    final groups = groupByCategory<Dish>(visible, (d) => d.category);

    // Quando o cardápio inteiro vale para hoje, o aviso do topo já diz isso;
    // repetir "Disponível hoje" em todas as linhas só faria barulho.
    final allToday = present.every(
      (d) => d.availability != Availability.unknown,
    );

    Widget row(Dish dish) {
      final (String? status, Color? color) = switch (dish) {
        Dish(present: false) => ('Fora do cardápio', c.inkFaint),
        Dish(availability: Availability.confirmed) when !allToday => (
          'Disponível hoje',
          c.green,
        ),
        Dish(availability: Availability.unavailable) => ('Indisponível', c.red),
        _ => (null, null),
      };
      return DishRow(
        key: ValueKey(dish.id),
        name: dish.name,
        description: dish.description,
        price: dish.price,
        status: status,
        statusColor: color,
        muted: !dish.present || dish.availability == Availability.unavailable,
        favorite: dish.favorite,
        onToggleFavorite: () => _app.toggleDishFavorite(menu.id, dish.id),
        onTap: () =>
            showDishSheet(context, menuId: menu.id, dishId: dish.id),
      );
    }

    return [
      if (present.length > 8)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar prato',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                prefixIcon: Icon(LucideIcons.search, size: 19, color: c.inkFaint),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: Icon(LucideIcons.x, size: 18, color: c.inkSoft),
                        onPressed: _search.clear,
                      ),
              ),
            ),
          ),
        ),
      if (present.isEmpty && gone.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
            child: Text(
              'A última leitura não trouxe nenhum prato.',
              style: bodyStyle(15, color: c.inkSoft),
            ),
          ),
        ),
      if (visible.isEmpty && query.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
            child: Text(
              'Nenhum prato com “${_search.text.trim()}” neste cardápio.',
              style: bodyStyle(15, color: c.inkSoft),
            ),
          ),
        ),
      for (final group in groups.entries) ...[
        SliverToBoxAdapter(
          child: CategoryTitle(group.key, count: group.value.length),
        ),
        SliverList.separated(
          itemCount: group.value.length,
          separatorBuilder: (_, _) => const DishDivider(),
          itemBuilder: (context, i) => row(group.value[i]),
        ),
      ],
      if (gone.isNotEmpty && query.isEmpty) ...[
        const SliverToBoxAdapter(
          child: CategoryTitle('Favoritos fora do cardápio'),
        ),
        SliverList.separated(
          itemCount: gone.length,
          separatorBuilder: (_, _) => const DishDivider(),
          itemBuilder: (context, i) => row(gone[i]),
        ),
      ],
    ];
  }

  List<Widget> _historySlivers(
    BuildContext context,
    Menu menu,
    List<ChangeEntry> history,
  ) {
    final c = context.mw;
    if (history.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhuma mudança registrada',
                  style: displayStyle(19, weight: 600, color: c.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'O histórico começa quando uma verificação encontrar um '
                  'prato novo, removido ou com outro preço. Acompanhado '
                  'desde ${shortDate(menu.createdAt)}.',
                  style: bodyStyle(15, color: c.inkSoft, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final days = <String, List<ChangeEntry>>{};
    for (final h in history) {
      days.putIfAbsent(dayLabel(h.detectedAt), () => []).add(h);
    }
    return [
      for (final day in days.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 22, gutter, 2),
            child: Text(
              day.key,
              style: bodyStyle(14, weight: 600, color: c.inkSoft),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: gutter - 14),
          sliver: SliverList.builder(
            itemCount: day.value.length,
            itemBuilder: (context, i) => ChangeRow(
              entry: day.value[i],
              time: clockTime(day.value[i].detectedAt),
              onTap: day.value[i].dishId == null
                  ? null
                  : () => _openDish(menu, day.value[i].dishId!),
            ),
          ),
        ),
      ],
    ];
  }

  void _openDish(Menu menu, String dishId) {
    if (menu.dishes.any((d) => d.id == dishId)) {
      showDishSheet(context, menuId: menu.id, dishId: dishId);
    } else {
      showMessage(context, 'Este prato não está mais no cardápio.');
    }
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirm,
    this.maxLength,
  });

  final String title;
  final String label;
  final String initial;
  final String confirm;
  final int? maxLength;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: widget.maxLength,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: widget.label, counterText: ''),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: Text(widget.confirm),
      ),
    ],
  );
}

/// Troca o link de um cardápio. O novo link é lido antes de valer.
class _ChangeUrlDialog extends ConsumerStatefulWidget {
  const _ChangeUrlDialog({required this.menu});

  final Menu menu;

  @override
  ConsumerState<_ChangeUrlDialog> createState() => _ChangeUrlDialogState();
}

class _ChangeUrlDialogState extends ConsumerState<_ChangeUrlDialog> {
  late final _controller = TextEditingController(text: widget.menu.url);
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? failure;
    try {
      await ref
          .read(appProvider.notifier)
          .changeUrl(widget.menu.id, _controller.text);
    } on ReadFailure catch (f) {
      failure = f.message;
    } catch (_) {
      failure = 'Aconteceu um erro inesperado ao ler o novo link.';
    }
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return AlertDialog(
      title: const Text('Trocar link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O novo link é lido agora. Os favoritos e o histórico são '
            'mantidos.',
            style: bodyStyle(14.5, color: c.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Link', errorText: _error, errorMaxLines: 6),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            Text('Lendo o novo link…', style: bodyStyle(13.5, color: c.inkSoft)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Ler e trocar'),
        ),
      ],
    );
  }
}
