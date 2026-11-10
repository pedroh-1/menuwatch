import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/tokens.dart';
import '../utils/text_utils.dart';
import '../widgets/common.dart';

const appVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mw;
    final data = ref.watch(appProvider);
    final settings = data.settings;
    final app = ref.read(appProvider.notifier);
    final enabled = ref.watch(notificationsEnabledProvider).value;
    final checking = ref.watch(checkingProvider).isNotEmpty;
    final canNotify = enabled == true;

    Future<void> enable() async {
      final granted = await ref.read(alertsProvider).requestPermission();
      ref.invalidate(notificationsEnabledProvider);
      if (!granted && context.mounted) {
        showMessage(
          context,
          'O Android não liberou as notificações. Ative-as nos ajustes do '
          'aparelho, em Apps, MenuWatch.',
        );
      }
    }

    Future<void> editName() async {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => _NameDialog(initial: settings.userName),
      );
      if (name == null) return;
      await app.updateSettings((s) => s.copyWith(userName: name.trim()));
    }

    Future<void> pickFrequency() async {
      final minutes = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) =>
            _FrequencySheet(current: settings.frequencyMinutes),
      );
      if (minutes == null || minutes == settings.frequencyMinutes) return;
      await app.updateSettings((s) => s.copyWith(frequencyMinutes: minutes));
    }

    Future<void> checkNow() async {
      final failures = await app.checkAll();
      if (!context.mounted) return;
      showMessage(
        context,
        failures == 0
            ? 'Cardápios verificados.'
            : '${plural(failures, 'cardápio não pôde', 'cardápios não puderam')} '
                  'ser lido${failures == 1 ? '' : 's'} agora.',
      );
    }

    Widget toggle(bool value, ValueChanged<bool> onChanged) => Switch(
      value: value && canNotify,
      onChanged: canNotify ? onChanged : null,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 18),
              child: Text('Ajustes', style: displayStyle(32, color: c.ink)),
            ),
            GroupedList(
              children: [
                ListRow(
                  icon: LucideIcons.user,
                  title: settings.userName.trim().isEmpty
                      ? 'Seu nome'
                      : settings.userName.trim(),
                  subtitle: settings.userName.trim().isEmpty
                      ? 'Aparece na saudação da tela inicial'
                      : 'Nome usado na saudação',
                  chevron: true,
                  onTap: editName,
                ),
              ],
            ),
            const SectionTitle('Notificações'),
            if (enabled == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter - 4, 0, gutter - 4, 12),
                child: Note(
                  icon: LucideIcons.bellOff,
                  text:
                      'As notificações do Android estão desativadas para o '
                      'MenuWatch. As opções abaixo só valem depois de '
                      'ativá-las.',
                  action: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: enable,
                    child: const Text('Ativar notificações'),
                  ),
                ),
              ),
            GroupedList(
              children: [
                ListRow(
                  icon: LucideIcons.heart,
                  title: 'Pratos favoritos',
                  subtitle: 'Quando um favorito aparece ou fica disponível',
                  trailing: toggle(
                    settings.notifyFavorites,
                    (v) => app.updateSettings(
                      (s) => s.copyWith(notifyFavorites: v),
                    ),
                  ),
                ),
                ListRow(
                  icon: LucideIcons.utensils,
                  title: 'Mudanças no cardápio',
                  subtitle: 'Pratos novos e pratos que saíram',
                  trailing: toggle(
                    settings.notifyMenuChanges,
                    (v) => app.updateSettings(
                      (s) => s.copyWith(notifyMenuChanges: v),
                    ),
                  ),
                ),
                ListRow(
                  icon: LucideIcons.tag,
                  title: 'Mudanças de preço',
                  subtitle: 'Quando um prato fica mais caro ou mais barato',
                  trailing: toggle(
                    settings.notifyPriceChanges,
                    (v) => app.updateSettings(
                      (s) => s.copyWith(notifyPriceChanges: v),
                    ),
                  ),
                ),
              ],
            ),
            const SectionTitle('Verificação'),
            GroupedList(
              children: [
                ListRow(
                  icon: LucideIcons.clock,
                  title: 'Verificar os cardápios',
                  subtitle: frequencyLabel(settings.frequencyMinutes),
                  chevron: true,
                  onTap: pickFrequency,
                ),
                ListRow(
                  icon: LucideIcons.refreshCw,
                  title: 'Verificar tudo agora',
                  subtitle: data.menus.isEmpty
                      ? 'Nenhum cardápio para verificar'
                      : checking
                      ? 'Verificando…'
                      : plural(data.menus.length, 'cardápio', 'cardápios'),
                  trailing: checking
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                          ),
                        )
                      : null,
                  onTap: data.menus.isEmpty || checking ? null : checkNow,
                ),
              ],
            ),
            const SectionTitle('Aparência'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter - 4),
              child: Segmented<AppThemeMode>(
                value: settings.themeMode,
                options: const {
                  AppThemeMode.system: 'Do aparelho',
                  AppThemeMode.light: 'Claro',
                  AppThemeMode.dark: 'Escuro',
                },
                onChanged: (mode) =>
                    app.updateSettings((s) => s.copyWith(themeMode: mode)),
              ),
            ),
            const SectionTitle('Como o MenuWatch funciona'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final text in const [
                    'Tudo acontece no seu celular. Não há conta, servidor nem '
                        'envio dos seus dados: os cardápios ficam guardados '
                        'só neste aparelho.',
                    'A verificação roda em segundo plano, mas quem decide a '
                        'hora exata é o Android. Com economia de bateria ou '
                        'sem internet, ela pode atrasar.',
                    'Páginas que só montam o conteúdo no navegador, como '
                        'alguns links do Canva, são verificadas apenas com o '
                        'app aberto.',
                    'A leitura segue regras fixas de formato. Em cardápios '
                        'com layout muito livre, alguns pratos podem não ser '
                        'reconhecidos ou vir com o nome incompleto.',
                    'Só páginas públicas são lidas. O app respeita o '
                        'robots.txt dos sites e não contorna login nem '
                        'bloqueios.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        text,
                        style: bodyStyle(14.5, color: c.inkSoft, height: 1.5),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'MenuWatch $appVersion',
                    style: bodyStyle(13.5, color: c.inkFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Como você se chama?'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 30,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Nome', counterText: ''),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Salvar'),
      ),
    ],
  );
}

class _FrequencySheet extends StatelessWidget {
  const _FrequencySheet({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.mw;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 4),
              child: Text(
                'Verificar os cardápios',
                style: displayStyle(21, color: c.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 10),
              child: Text(
                'Intervalos curtos gastam mais bateria e dados. O Android '
                'pode atrasar a verificação.',
                style: bodyStyle(14, color: c.inkSoft, height: 1.4),
              ),
            ),
            for (final minutes in AppSettings.frequencyOptions)
              InkWell(
                onTap: () => Navigator.of(context).pop(minutes),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          frequencyLabel(minutes),
                          style: bodyStyle(
                            16,
                            weight: minutes == current ? 700 : 500,
                            color: c.ink,
                          ),
                        ),
                      ),
                      if (minutes == current)
                        Icon(LucideIcons.check, size: 20, color: c.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
