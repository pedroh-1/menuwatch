import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Guarda todos os dados do app em um arquivo JSON no próprio aparelho.
///
/// Toda alteração relê o arquivo antes de gravar, porque a verificação em
/// segundo plano roda em outro isolate e pode ter gravado nesse meio-tempo.
class Store {
  Store(this._file);

  final File _file;
  Future<void> _queue = Future.value();

  static const _maxHistory = 1000;
  static const _maxNotifications = 200;

  static Future<Store> open() async {
    final dir = await getApplicationSupportDirectory();
    return Store(File('${dir.path}/menuwatch.json'));
  }

  Future<AppData> load() async {
    try {
      if (!await _file.exists()) return const AppData();
      final text = await _file.readAsString();
      if (text.trim().isEmpty) return const AppData();
      return AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on FormatException {
      // Arquivo corrompido: preserva uma cópia e recomeça vazio.
      await _file.copy('${_file.path}.corrompido');
      return const AppData();
    }
  }

  Future<AppData> update(AppData Function(AppData current) change) {
    final result = _queue.then((_) async {
      var next = change(await load());
      if (next.history.length > _maxHistory) {
        next = next.copyWith(history: next.history.sublist(0, _maxHistory));
      }
      if (next.notifications.length > _maxNotifications) {
        next = next.copyWith(
          notifications: next.notifications.sublist(0, _maxNotifications),
        );
      }
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(jsonEncode(next.toJson()), flush: true);
      await tmp.rename(_file.path);
      return next;
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
