import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';

/// Notificações do próprio aparelho, sem servidor.
class Alerts {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// [onOpen] recebe o id do cardápio quando o usuário toca em um aviso.
  Future<void> init({void Function(String? menuId)? onOpen}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_menuwatch'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onOpen?.call(response.payload),
    );
  }

  Future<bool> isEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  /// Id do cardápio, quando o app foi aberto pelo toque em um aviso.
  Future<String?> launchMenuId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  Future<void> show(AppNotification n) async {
    final (id, name, description, importance, priority) = switch (n.kind) {
      NotificationKind.favorite => (
        'favoritos',
        'Pratos favoritos',
        'Quando um prato favorito aparece ou fica disponível',
        Importance.high,
        Priority.high,
      ),
      NotificationKind.menuChanged => (
        'alteracoes',
        'Alterações nos cardápios',
        'Pratos novos, removidos e mudanças de preço',
        Importance.defaultImportance,
        Priority.defaultPriority,
      ),
      NotificationKind.error => (
        'problemas',
        'Problemas de leitura',
        'Quando um cardápio deixa de poder ser lido',
        Importance.low,
        Priority.low,
      ),
    };
    await _plugin.show(
      id: n.id.hashCode & 0x7fffffff,
      title: n.title,
      body: n.message,
      payload: n.menuId,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          id,
          name,
          channelDescription: description,
          importance: importance,
          priority: priority,
          color: const Color(0xFF4A2462),
          styleInformation: BigTextStyleInformation(n.message),
        ),
      ),
    );
  }
}
