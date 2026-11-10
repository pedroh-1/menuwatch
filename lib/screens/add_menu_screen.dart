import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../routes/router.dart';
import '../services/extraction/fetcher.dart';
import '../services/extraction/menu_reader.dart';
import '../services/parser/menu_parser.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';
import '../widgets/common.dart';
import '../widgets/dish_list.dart';
import '../widgets/dish_row.dart';

enum _Phase { input, reading, preview }

/// Adicionar cardápio: colar o link, acompanhar a leitura, conferir o que
/// foi encontrado e só então guardar.
class AddMenuScreen extends ConsumerStatefulWidget {
  const AddMenuScreen({super.key});

  @override
  ConsumerState<AddMenuScreen> createState() => _AddMenuScreenState();
}

class _AddMenuScreenState extends ConsumerState<AddMenuScreen> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  var _phase = _Phase.input;
  var _stages = <ReadStage>[];
  String? _error;
  ReadResult? _result;
  var _run = 0;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _url.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _run++;
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      showMessage(context, 'Não há texto copiado para colar.');
      return;
    }
    _url.text = text;
    setState(() => _error = null);
  }

  Future<void> _read() async {
    FocusScope.of(context).unfocus();
    final run = ++_run;
    setState(() {
      _phase = _Phase.reading;
      _stages = [ReadStage.fetching];
      _error = null;
    });

    String? failure;
    ReadResult? result;
    try {
      final existing = ref
          .read(appProvider.notifier)
          .menuWithUrl(normalizeUrl(_url.text).toString());
      if (existing != null) {
        throw ReadFailure('Você já acompanha este link em “${existing.name}”.');
      }
      result = await ref
          .read(readerProvider)
          .read(
            _url.text,
            onStage: (stage) {
              if (run != _run || !mounted || _stages.contains(stage)) return;
              setState(() => _stages = [..._stages, stage]);
            },
          );
    } on ReadFailure catch (f) {
      failure = f.message;
    } catch (_) {
      failure = 'Aconteceu um erro inesperado ao ler este link. Tente de novo.';
    }
    if (run != _run || !mounted) return;

    setState(() {
      if (result == null) {
        _phase = _Phase.input;
        _error = failure;
      } else {
        _phase = _Phase.preview;
        _result = result;
        _name.text = result.suggestedName ?? '';
      }
    });
  }

  void _backToInput() {
    _run++;
    setState(() {
      _phase = _Phase.input;
      _result = null;
    });
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving) return;
    setState(() => _saving = true);
    final app = ref.read(appProvider.notifier);
    final router = GoRouter.of(context);
    try {
      final id = await app.addMenu(result, _name.text);
      if (!mounted) return;
      if (!ref.read(appProvider).settings.onboarded) {
        await _offerNotifications();
      }
      router.pushReplacement(Routes.menu(id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, 'Não foi possível guardar o cardápio. Tente de novo.');
    }
  }

  /// Pede a permissão de notificação no momento em que ela faz sentido:
  /// logo depois do primeiro cardápio.
  Future<void> _offerNotifications() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => const _NotificationOffer(),
    );
    if (accepted == true) {
      await ref.read(alertsProvider).requestPermission();
      ref.invalidate(notificationsEnabledProvider);
    }
    await ref
        .read(appProvider.notifier)
        .updateSettings((s) => s.copyWith(onboarded: true));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.input,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _backToInput();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
          title: const Text('Adicionar cardápio'),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            child: switch (_phase) {
              _Phase.input => _buildInput(context),
              _Phase.reading => _buildReading(context),
              _Phase.preview => _buildPreview(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final c = context.mw;
    return ListView(
      key: const ValueKey('input'),
      padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
      children: [
        Text('Cole o link do cardápio', style: displayStyle(28, color: c.ink)),
        const SizedBox(height: 8),
        Text(
          'Funciona com sites, PDFs, imagens e páginas do Canva.',
          style: bodyStyle(15.5, color: c.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          minLines: 1,
          maxLines: 3,
          onSubmitted: (_) {
            if (_url.text.trim().isNotEmpty) _read();
          },
          decoration: InputDecoration(
            hintText: 'https://',
            prefixIcon: Icon(LucideIcons.link, size: 20, color: c.inkFaint),
            suffixIcon: _url.text.isEmpty
                ? TextButton(onPressed: _paste, child: const Text('Colar'))
                : IconButton(
                    tooltip: 'Limpar',
                    icon: Icon(LucideIcons.x, size: 18, color: c.inkSoft),
                    onPressed: () {
                      _url.clear();
                      setState(() => _error = null);
                    },
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Note(
            text: _error!,
            icon: LucideIcons.circleAlert,
            tone: NoteTone.error,
          ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.08, end: 0),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _url.text.trim().isEmpty ? null : _read,
          child: const Text('Ler cardápio'),
        ),
        const SizedBox(height: 28),
        Text(
          'O app lê apenas páginas abertas ao público. Cardápios que pedem '
          'login ou que o site proíbe de ler automaticamente não são '
          'acompanhados.',
          style: bodyStyle(13.5, color: c.inkFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildReading(BuildContext context) {
    final c = context.mw;
    return ListView(
      key: const ValueKey('reading'),
      padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
      children: [
        Text('Lendo o cardápio', style: displayStyle(28, color: c.ink)),
        const SizedBox(height: 6),
        Text(
          hostOf(_safeUrl()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bodyStyle(15.5, color: c.inkSoft),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < _stages.length; i++)
          _StageLine(
            label: _stages[i].label,
            done: i < _stages.length - 1,
          ).animate().fadeIn(duration: 220.ms).slideX(begin: -0.04, end: 0),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 8),
        const DishSkeleton(rows: 5),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _backToInput,
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }

  String _safeUrl() {
    try {
      return normalizeUrl(_url.text).toString();
    } on ReadFailure {
      return _url.text.trim();
    }
  }

  Widget _buildPreview(BuildContext context) {
    final c = context.mw;
    final result = _result!;
    final parsed = result.parsed;
    final groups = groupByCategory<ParsedDish>(parsed.dishes, (d) => d.category);
    final date = parsed.referenceDate;
    final now = DateTime.now();
    final anyConfirmed = parsed.dishes.any(
      (d) => d.availability == Availability.confirmed,
    );

    final String dateNote;
    if (date != null && sameDay(date, now)) {
      dateNote = 'É o cardápio de hoje, ${shortDate(date)}.';
    } else if (date != null) {
      dateNote =
          'O cardápio é de ${shortDate(date)}. Os pratos só aparecem como '
          'disponíveis no dia a que ele se refere.';
    } else if (anyConfirmed) {
      dateNote = 'O cardápio separa os pratos por dia da semana.';
    } else {
      dateNote =
          'O cardápio não informa a data. O app avisa quando um prato entra, '
          'sai ou muda de preço, mas não afirma que ele é servido hoje.';
    }

    return Column(
      key: const ValueKey('preview'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plural(
                        parsed.dishes.length,
                        'prato encontrado',
                        'pratos encontrados',
                      ),
                      style: displayStyle(28, color: c.ink),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          sourceIcon(result.sourceType),
                          size: 16,
                          color: c.inkSoft,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${result.sourceType.label} em ${hostOf(result.url)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyStyle(14.5, color: c.inkSoft),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Nome do cardápio',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Note(
                      text: dateNote,
                      icon: date != null && sameDay(date, now)
                          ? LucideIcons.calendarCheck
                          : LucideIcons.calendar,
                      tone: date != null && sameDay(date, now)
                          ? NoteTone.success
                          : NoteTone.neutral,
                    ),
                    if (result.sourceType.needsBrowser) ...[
                      const SizedBox(height: 10),
                      const Note(
                        icon: LucideIcons.monitorSmartphone,
                        text:
                            'Esta página precisa de um navegador para mostrar '
                            'o cardápio. Ela só é verificada quando você abre '
                            'o app, não em segundo plano.',
                      ),
                    ],
                  ],
                ),
              ),
              for (final group in groups.entries) ...[
                CategoryTitle(group.key, count: group.value.length),
                for (var i = 0; i < group.value.length; i++) ...[
                  if (i > 0) const DishDivider(),
                  DishRow(
                    name: group.value[i].name,
                    description: group.value[i].description,
                    price: group.value[i].price,
                    status: switch (group.value[i].availability) {
                      Availability.confirmed => 'Disponível hoje',
                      Availability.unavailable => 'Indisponível',
                      Availability.unknown => null,
                    },
                    statusColor:
                        group.value[i].availability == Availability.confirmed
                        ? c.green
                        : c.red,
                  ),
                ],
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.bg,
            border: Border(top: BorderSide(color: c.line)),
          ),
          padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: _saving ? null : _backToInput,
                child: const Text('Outro link'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Acompanhar cardápio'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? Container(
                    decoration: BoxDecoration(
                      color: c.greenSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.check, size: 14, color: c.green),
                  )
                : Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: c.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: bodyStyle(
              15.5,
              weight: done ? 400 : 600,
              color: done ? c.inkSoft : c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationOffer extends StatelessWidget {
  const _NotificationOffer();

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.bellRing, color: c.primary, size: 24),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quer ser avisado quando o cardápio mudar?',
              style: displayStyle(23, color: c.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'O MenuWatch verifica os cardápios de tempos em tempos e manda '
              'uma notificação quando um prato entra, sai, muda de preço ou '
              'quando um favorito seu aparece.',
              style: bodyStyle(15, color: c.inkSoft, height: 1.45),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ativar notificações'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Agora não'),
            ),
          ],
        ),
      ),
    );
  }
}
