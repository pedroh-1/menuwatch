import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/models.dart';
import 'providers/providers.dart';
import 'routes/router.dart';
import 'services/alerts.dart';
import 'services/background.dart';
import 'services/storage.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/render_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await Store.open();
  final data = await store.load();

  final alerts = Alerts();
  late final ProviderContainer container;
  String? launchMenuId;
  try {
    await alerts.init(
      onOpen: (menuId) {
        if (menuId == null) return;
        if (container.read(appProvider).menuById(menuId) == null) return;
        container.read(routerProvider).push(Routes.menu(menuId, history: true));
      },
    );
    launchMenuId = await alerts.launchMenuId();
  } catch (_) {
    // Sem notificações o app continua funcionando; os avisos ficam na lista.
  }

  container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      initialDataProvider.overrideWithValue(data),
      alertsProvider.overrideWithValue(alerts),
      launchMenuProvider.overrideWithValue(launchMenuId),
    ],
  );

  try {
    await scheduleBackgroundChecks(data.settings.frequencyMinutes);
  } catch (_) {
    // Sem o agendamento, os cardápios ainda são verificados ao abrir o app.
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const MenuWatchApp()),
  );
}

class MenuWatchApp extends ConsumerStatefulWidget {
  const MenuWatchApp({super.key});

  @override
  ConsumerState<MenuWatchApp> createState() => _MenuWatchAppState();
}

class _MenuWatchAppState extends ConsumerState<MenuWatchApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _catchUp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A permissão pode ter sido mudada nos ajustes do Android.
      ref.invalidate(notificationsEnabledProvider);
      _catchUp();
    }
  }

  var _running = false;

  /// Relê os dados e verifica o que ficou para trás enquanto o app estava
  /// fechado.
  Future<void> _catchUp() async {
    if (_running) return;
    _running = true;
    try {
      await ref.read(appProvider.notifier).refreshStale();
    } catch (_) {
      // Cada cardápio registra a própria falha; nada a mostrar aqui.
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appProvider.select((d) => d.settings.themeMode));
    return MaterialApp.router(
      title: 'MenuWatch',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final icons = dark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            systemNavigationBarColor: context.mw.bg,
            systemNavigationBarIconBrightness: icons,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: RenderHost(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
