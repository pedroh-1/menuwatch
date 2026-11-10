import '../models/models.dart';
import '../utils/text_utils.dart';
import 'differ.dart';
import 'extraction/fetcher.dart';
import 'extraction/menu_reader.dart';
import 'alerts.dart';
import 'storage.dart';

/// Relê os cardápios guardados, registra o que mudou e avisa o usuário.
class Monitor {
  Monitor({required this.store, required this.reader, this.notifier});

  final Store store;
  final MenuReader reader;
  final Alerts? notifier;

  Future<void> checkAll({
    void Function(String menuId, bool running)? onProgress,
  }) async {
    final data = await store.load();
    for (final menu in data.menus) {
      onProgress?.call(menu.id, true);
      try {
        await checkMenu(menu.id);
      } finally {
        onProgress?.call(menu.id, false);
      }
    }
  }

  /// Devolve a falha de leitura, ou nulo quando a verificação deu certo.
  Future<ReadFailure?> checkMenu(String menuId) async {
    final menu = (await store.load()).menuById(menuId);
    if (menu == null) return null;
    final now = DateTime.now();

    final ReadResult read;
    try {
      read = await reader.read(menu.url, hint: menu.sourceType);
    } on ReadFailure catch (failure) {
      await _recordFailure(menuId, failure);
      return failure;
    } catch (_) {
      const failure = ReadFailure(
        'Aconteceu um erro inesperado ao ler este cardápio.',
        transient: true,
      );
      await _recordFailure(menuId, failure);
      return failure;
    }

    var created = const <AppNotification>[];
    await store.update((current) {
      final before = current.menuById(menuId);
      if (before == null) return current;
      final diff = diffMenu(before, read.parsed, now: now);
      final date = read.parsed.referenceDate;
      final after = before.copyWith(
        dishes: diff.dishes,
        sourceType: read.sourceType,
        status: MenuStatus.ok,
        clearError: true,
        referenceDate: date,
        clearReferenceDate: date == null,
        lastCheckedAt: now,
        lastChangedAt: diff.changes.isEmpty ? null : now,
      );
      created = buildNotifications(
        before: before,
        after: after,
        changes: diff.changes,
        settings: current.settings,
        now: now,
      );
      return current.copyWith(
        menus: [
          for (final m in current.menus) m.id == menuId ? after : m,
        ],
        history: [...diff.changes, ...current.history],
        notifications: [...created, ...current.notifications],
      );
    });
    for (final n in created) {
      await _show(n);
    }
    return null;
  }

  Future<void> _recordFailure(String menuId, ReadFailure failure) async {
    AppNotification? created;
    await store.update((current) {
      final menu = current.menuById(menuId);
      if (menu == null) return current;
      // Só vira aviso o problema novo e duradouro; falta de internet e
      // repetição do mesmo erro ficam apenas registradas no cardápio.
      final isNews =
          !failure.transient &&
          !failure.needsApp &&
          (menu.status != MenuStatus.error || menu.lastError != failure.message);
      if (isNews) {
        created = AppNotification(
          id: newId(),
          title: 'Não foi possível ler ${menu.name}',
          message: failure.message,
          kind: NotificationKind.error,
          menuId: menuId,
        );
      }
      final updated = failure.needsApp
          ? menu.copyWith(status: MenuStatus.waitingApp, clearError: true)
          : menu.copyWith(status: MenuStatus.error, lastError: failure.message);
      return current.copyWith(
        menus: [
          for (final m in current.menus) m.id == menuId ? updated : m,
        ],
        notifications: [?created, ...current.notifications],
      );
    });
    if (created != null) await _show(created!);
  }

  Future<void> _show(AppNotification n) async {
    try {
      await notifier?.show(n);
    } catch (_) {
      // Sem permissão de notificação, o aviso continua na lista do app.
    }
  }
}

String _list(List<String> names, {int max = 3}) {
  if (names.length <= max) {
    if (names.length < 2) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
  }
  final rest = names.length - max;
  return '${names.take(max).join(', ')} e mais $rest';
}

String _count(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

/// Decide quais avisos uma verificação gera. Cada mudança entra em no
/// máximo um aviso, e uma verificação sem mudança não gera nenhum.
List<AppNotification> buildNotifications({
  required Menu before,
  required Menu after,
  required List<ChangeEntry> changes,
  required AppSettings settings,
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final out = <AppNotification>[];
  final old = {for (final d in before.dishes) d.id: d};
  final handled = <String>{};

  if (settings.notifyFavorites) {
    for (final dish in after.dishes) {
      if (!dish.favorite || !dish.present) continue;
      final was = old[dish.id];
      final wasPresent = was != null && was.present;
      final wasAvailable = wasPresent && was.availability == Availability.confirmed;
      final price = dish.price == null ? '' : ' por ${formatPrice(dish.price!)}';

      if (dish.availability == Availability.confirmed && !wasAvailable) {
        out.add(
          AppNotification(
            id: newId(),
            title: 'Seu prato favorito está disponível!',
            message: '${dish.name} está no cardápio de hoje de ${after.name}$price.',
            kind: NotificationKind.favorite,
            menuId: after.id,
            createdAt: when,
          ),
        );
        handled.add(dish.id);
      } else if (!wasPresent && dish.availability != Availability.unavailable) {
        out.add(
          AppNotification(
            id: newId(),
            title: 'Seu prato favorito voltou ao cardápio',
            message:
                '${dish.name} voltou ao cardápio de ${after.name}$price. O '
                'cardápio não informa se o prato é servido hoje.',
            kind: NotificationKind.favorite,
            menuId: after.id,
            createdAt: when,
          ),
        );
        handled.add(dish.id);
      }
    }
  }

  final added = <String>[];
  final removed = <String>[];
  final priced = <ChangeEntry>[];
  for (final c in changes) {
    if (c.dishId != null && handled.contains(c.dishId)) continue;
    switch (c.type) {
      case ChangeType.added || ChangeType.returned:
        if (settings.notifyMenuChanges) added.add(c.dishName);
      case ChangeType.removed:
        if (settings.notifyMenuChanges) removed.add(c.dishName);
      case ChangeType.price:
        if (settings.notifyPriceChanges) priced.add(c);
      case ChangeType.availability:
        break; // só interessa para favoritos, tratados acima
    }
  }
  if (added.isEmpty && removed.isEmpty && priced.isEmpty) return out;

  final date = after.referenceDate;
  final isNewDay =
      date != null &&
      (before.referenceDate == null || !sameDay(before.referenceDate!, date));

  final String title;
  final String message;
  if (isNewDay && added.isNotEmpty) {
    final day = sameDay(date, when) ? 'hoje' : shortDate(date);
    title = 'Novo cardápio em ${after.name}';
    message =
        '${_count(after.presentDishes.length, 'prato', 'pratos')} para $day. '
        'Entre as novidades: ${_list(added)}.';
  } else if (added.isEmpty && removed.isEmpty && priced.length == 1) {
    title = 'Preço alterado em ${after.name}';
    message = '${priced.first.dishName}: ${priced.first.description.toLowerCase()}.';
  } else {
    title = '${after.name} mudou';
    message = '${[
      if (added.isNotEmpty) '${_count(added.length, 'prato novo', 'pratos novos')} (${_list(added)})',
      if (removed.isNotEmpty) '${_count(removed.length, 'prato saiu', 'pratos saíram')} (${_list(removed)})',
      if (priced.isNotEmpty) _count(priced.length, 'preço mudou', 'preços mudaram'),
    ].join(', ')}.';
  }
  out.add(
    AppNotification(
      id: newId(),
      title: title,
      message: message,
      kind: NotificationKind.menuChanged,
      menuId: after.id,
      createdAt: when,
    ),
  );
  return out;
}
