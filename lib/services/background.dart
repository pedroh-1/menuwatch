import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import 'extraction/menu_reader.dart';
import 'monitor.dart';
import 'alerts.dart';
import 'storage.dart';

const _taskName = 'br.com.menuwatch.verificar';

/// Ponto de entrada da verificação em segundo plano. O Android chama esta
/// função em um processo sem tela; por isso não há navegador aqui, e os
/// cardápios que dependem dele ficam para quando o app for aberto.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      final store = await Store.open();
      final notifier = Alerts();
      await notifier.init();
      final reader = MenuReader();
      try {
        await Monitor(
          store: store,
          reader: reader,
          notifier: notifier,
        ).checkAll();
      } finally {
        await reader.close();
      }
    } catch (_) {
      // Uma falha aqui não deve fazer o Android repetir a tarefa em sequência;
      // a próxima verificação agendada tenta de novo.
    }
    return true;
  });
}

/// Agenda (ou reagenda) a verificação periódica. O Android decide o momento
/// exato e pode atrasar a execução para economizar bateria.
Future<void> scheduleBackgroundChecks(int minutes) async {
  final every = Duration(minutes: minutes < 15 ? 15 : minutes);
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: every,
    initialDelay: every,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}
