import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/alerts.dart';
import '../services/background.dart';
import '../services/differ.dart';
import '../services/extraction/fetcher.dart';
import '../services/extraction/menu_reader.dart';
import '../services/extraction/page_renderer.dart';
import '../services/monitor.dart';
import '../services/storage.dart';

/// Preenchidos em `main()` depois de abrir o arquivo de dados.
final storeProvider = Provider<Store>((ref) => throw UnimplementedError());
final initialDataProvider = Provider<AppData>((ref) => const AppData());

final alertsProvider = Provider<Alerts>((ref) => Alerts());

/// Reagenda a verificação em segundo plano. Trocado nos testes.
final schedulerProvider = Provider<Future<void> Function(int minutes)>(
  (ref) => scheduleBackgroundChecks,
);

/// Leitor usado com o app aberto, com navegador embutido disponível.
final readerProvider = Provider<MenuReader>((ref) {
  final reader = MenuReader(render: PageRenderer.instance.render);
  ref.onDispose(reader.close);
  return reader;
});

/// Cardápio a abrir quando o app foi iniciado pelo toque em um aviso.
final launchMenuProvider = Provider<String?>((ref) => null);

final notificationsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(alertsProvider).isEnabled(),
);

/// Ids dos cardápios que estão sendo verificados agora.
final checkingProvider = NotifierProvider<CheckingController, Set<String>>(
  CheckingController.new,
);

class CheckingController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void set(String menuId, bool running) {
    state = running
        ? {...state, menuId}
        : {
            for (final id in state)
              if (id != menuId) id,
          };
  }
}

final appProvider = NotifierProvider<AppController, AppData>(
  AppController.new,
);

class AppController extends Notifier<AppData> {
  @override
  AppData build() => ref.watch(initialDataProvider);

  Store get _store => ref.read(storeProvider);

  Future<void> reload() async {
    state = await _store.load();
  }

  Future<void> _update(AppData Function(AppData current) change) async {
    state = await _store.update(change);
  }

  Future<void> _updateMenu(String id, Menu Function(Menu menu) change) =>
      _update(
        (d) => d.copyWith(
          menus: [
            for (final m in d.menus) m.id == id ? change(m) : m,
          ],
        ),
      );

  // Ajustes

  Future<void> updateSettings(
    AppSettings Function(AppSettings settings) change,
  ) async {
    final before = state.settings.frequencyMinutes;
    await _update((d) => d.copyWith(settings: change(d.settings)));
    final after = state.settings.frequencyMinutes;
    if (after != before) {
      try {
        await ref.read(schedulerProvider)(after);
      } catch (_) {
        // O agendamento antigo continua valendo; o novo intervalo é
        // aplicado na próxima abertura do app.
      }
    }
  }

  // Cardápios

  /// Guarda um cardápio recém-lido e devolve o id dele.
  Future<String> addMenu(ReadResult read, String name) async {
    final now = DateTime.now();
    final menu = Menu(
      id: newId(),
      name: name.trim(),
      url: read.url,
      sourceType: read.sourceType,
      dishes: dishesFromParsed(read.parsed, now: now),
      referenceDate: read.parsed.referenceDate,
      createdAt: now,
      lastCheckedAt: now,
    );
    await _update((d) => d.copyWith(menus: [...d.menus, menu]));
    return menu.id;
  }

  Menu? menuWithUrl(String url) {
    for (final m in state.menus) {
      if (m.url == url) return m;
    }
    return null;
  }

  Future<void> renameMenu(String id, String name) =>
      _updateMenu(id, (m) => m.copyWith(name: name.trim()));

  Future<void> togglePinned(String id) =>
      _updateMenu(id, (m) => m.copyWith(favorite: !m.favorite));

  /// Aponta o cardápio para outro link. O novo link é lido antes; se a
  /// leitura falhar, nada muda e a falha é lançada como [ReadFailure].
  Future<void> changeUrl(String id, String url) async {
    final read = await ref.read(readerProvider).read(url);
    final now = DateTime.now();
    await _update((d) {
      final before = d.menuById(id);
      if (before == null) return d;
      final diff = diffMenu(before, read.parsed, now: now);
      final date = read.parsed.referenceDate;
      final after = before.copyWith(
        url: read.url,
        sourceType: read.sourceType,
        dishes: diff.dishes,
        status: MenuStatus.ok,
        clearError: true,
        referenceDate: date,
        clearReferenceDate: date == null,
        lastCheckedAt: now,
        lastChangedAt: diff.changes.isEmpty ? null : now,
      );
      return d.copyWith(
        menus: [
          for (final m in d.menus) m.id == id ? after : m,
        ],
        history: [...diff.changes, ...d.history],
      );
    });
  }

  Future<void> deleteMenu(String id) => _update(
    (d) => d.copyWith(
      menus: d.menus.where((m) => m.id != id).toList(),
      history: d.history.where((h) => h.menuId != id).toList(),
      notifications: d.notifications.where((n) => n.menuId != id).toList(),
    ),
  );

  Future<void> toggleDishFavorite(String menuId, String dishId) => _updateMenu(
    menuId,
    (m) => m.copyWith(
      dishes: [
        for (final dish in m.dishes)
          if (dish.id != dishId)
            dish
          // Um prato que já saiu do cardápio só era mantido por ser favorito.
          else if (dish.present || !dish.favorite)
            dish.copyWith(favorite: !dish.favorite),
      ],
    ),
  );

  // Avisos

  Future<void> markRead(String id) => _update(
    (d) => d.copyWith(
      notifications: [
        for (final n in d.notifications)
          n.id == id && !n.read ? n.copyWith(read: true) : n,
      ],
    ),
  );

  Future<void> markAllRead() => _update(
    (d) => d.copyWith(
      notifications: [
        for (final n in d.notifications) n.read ? n : n.copyWith(read: true),
      ],
    ),
  );

  Future<void> clearNotifications() =>
      _update((d) => d.copyWith(notifications: const []));

  // Verificação

  Monitor _monitor({required bool notify}) => Monitor(
    store: _store,
    reader: ref.read(readerProvider),
    notifier: notify ? ref.read(alertsProvider) : null,
  );

  /// Verifica um cardápio agora. Devolve a falha, se houver.
  Future<ReadFailure?> checkMenu(String id, {bool notify = false}) async {
    final checking = ref.read(checkingProvider.notifier);
    if (ref.read(checkingProvider).contains(id)) return null;
    checking.set(id, true);
    try {
      return await _monitor(notify: notify).checkMenu(id);
    } finally {
      checking.set(id, false);
      await reload();
    }
  }

  /// Verifica todos os cardápios, um por vez. Devolve quantos falharam.
  Future<int> checkAll() async {
    var failures = 0;
    for (final menu in [...state.menus]) {
      if (await checkMenu(menu.id) != null) failures++;
    }
    return failures;
  }

  /// Chamado quando o app abre ou volta para a frente: relê o arquivo (a
  /// verificação em segundo plano pode ter gravado) e verifica o que está
  /// atrasado, o que inclui os cardápios que dependem do navegador.
  Future<void> refreshStale() async {
    await reload();
    final now = DateTime.now();
    for (final menu in [...state.menus]) {
      final last = menu.lastCheckedAt;
      final limit = menu.sourceType.needsBrowser
          ? 15
          : state.settings.frequencyMinutes;
      final stale =
          last == null ||
          menu.status == MenuStatus.waitingApp ||
          now.difference(last).inMinutes >= limit;
      if (stale) await checkMenu(menu.id, notify: true);
    }
  }
}
