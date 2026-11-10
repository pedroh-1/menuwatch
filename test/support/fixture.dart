import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menuwatch/main.dart';
import 'package:menuwatch/models/models.dart';
import 'package:menuwatch/providers/providers.dart';
import 'package:menuwatch/routes/router.dart';
import 'package:menuwatch/services/alerts.dart';
import 'package:menuwatch/services/extraction/fetcher.dart';
import 'package:menuwatch/services/extraction/menu_reader.dart';
import 'package:menuwatch/services/storage.dart';

/// Armazenamento em memória, para os testes não dependerem de arquivo.
class MemoryStore implements Store {
  MemoryStore([this.data = const AppData()]);

  AppData data;

  @override
  Future<AppData> load() async => data;

  @override
  Future<AppData> update(AppData Function(AppData current) change) async =>
      data = change(data);
}

class FakeAlerts implements Alerts {
  FakeAlerts({this.enabled = true, this.grantOnRequest = true});

  bool enabled;
  bool grantOnRequest;
  final shown = <AppNotification>[];

  @override
  Future<void> init({void Function(String? menuId)? onOpen}) async {}

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async => enabled = grantOnRequest;

  @override
  Future<String?> launchMenuId() async => null;

  @override
  Future<void> show(AppNotification n) async => shown.add(n);
}

/// Leitor ligado a um "site" de mentira: cada endereço devolve o HTML dado.
/// Endereços fora do mapa respondem 404; valores inteiros viram o status.
/// [hold], quando informado, segura as respostas até ser concluído, para os
/// testes verem a tela de leitura.
MenuReader readerFor(Map<String, Object> pages, {Future<void>? hold}) =>
    MenuReader(
      fetcher: Fetcher(
        client: MockClient((request) async {
          if (hold != null && !request.url.path.endsWith('robots.txt')) {
            await hold;
          }
          final page = pages[request.url.toString()];
          if (page is int) return http.Response('', page);
          if (page is String) {
            return http.Response.bytes(
              utf8.encode(page),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
          return http.Response('', 404);
        }),
      ),
    );

String menuPage(String title, Map<String, List<String>> sections) =>
    '<html><head><title>$title</title></head><body><h1>$title</h1>'
    '${sections.entries.map((s) => '<h2>${s.key}</h2><ul>'
        '${s.value.map((d) => '<li>$d</li>').join()}</ul>').join()}'
    '</body></html>';

/// Dados de exemplo, usados só nos testes e nas capturas de tela.
AppData sampleData({
  AppThemeMode theme = AppThemeMode.light,
  bool onboarded = true,
}) {
  final now = DateTime.now();
  DateTime ago(Duration d) => now.subtract(d);
  final today = DateTime(now.year, now.month, now.day);

  Dish dish(
    String id,
    String name, {
    double? price,
    String category = 'Cardápio',
    String? description,
    Availability availability = Availability.unknown,
    bool favorite = false,
    bool present = true,
  }) => Dish(
    id: id,
    name: name,
    price: price,
    category: category,
    description: description,
    availability: availability,
    favorite: favorite,
    present: present,
    firstSeenAt: ago(const Duration(days: 9)),
    lastSeenAt: ago(const Duration(minutes: 12)),
  );

  const ok = Availability.confirmed;
  return AppData(
    settings: AppSettings(
      userName: 'Pedro',
      themeMode: theme,
      onboarded: onboarded,
    ),
    menus: [
      Menu(
        id: 'cantina',
        name: 'Cantina da Praça',
        url: 'https://cantina.exemplo.com.br/cardapio-do-dia',
        sourceType: SourceType.html,
        favorite: true,
        referenceDate: today,
        createdAt: ago(const Duration(days: 9)),
        lastCheckedAt: ago(const Duration(minutes: 12)),
        lastChangedAt: ago(const Duration(hours: 2)),
        dishes: [
          dish(
            'c1',
            'Feijoada completa',
            price: 32.9,
            category: 'Pratos do dia',
            description: 'Arroz, couve refogada, farofa e laranja',
            availability: ok,
            favorite: true,
          ),
          dish(
            'c2',
            'Frango grelhado com legumes',
            price: 24,
            category: 'Pratos do dia',
            availability: ok,
          ),
          dish(
            'c3',
            'Lasanha à bolonhesa',
            price: 28.5,
            category: 'Pratos do dia',
            availability: ok,
          ),
          dish(
            'c4',
            'Peixe do dia ao molho de maracujá',
            price: 36,
            category: 'Pratos do dia',
            availability: Availability.unavailable,
          ),
          dish(
            'c5',
            'Arroz branco ou integral',
            category: 'Guarnições',
            availability: ok,
          ),
          dish(
            'c6',
            'Purê de mandioquinha',
            category: 'Guarnições',
            availability: ok,
          ),
          dish(
            'c7',
            'Pudim de leite',
            price: 9,
            category: 'Sobremesas',
            availability: ok,
            favorite: true,
          ),
          dish(
            'c8',
            'Salada de frutas',
            price: 7.5,
            category: 'Sobremesas',
            availability: ok,
          ),
        ],
      ),
      Menu(
        id: 'bistro',
        name: 'Bistrô Aurora',
        url: 'https://bistroaurora.exemplo.com.br/menu.pdf',
        sourceType: SourceType.pdf,
        createdAt: ago(const Duration(days: 30)),
        lastCheckedAt: ago(const Duration(minutes: 40)),
        dishes: [
          dish(
            'b1',
            'Burrata com tomates assados',
            price: 48,
            category: 'Entradas',
          ),
          dish(
            'b2',
            'Risoto de cogumelos',
            price: 62,
            category: 'Principais',
            description: 'Arroz arbóreo, shiitake, paris e parmesão',
            favorite: true,
          ),
          dish(
            'b3',
            'Nhoque de batata-doce',
            price: 54,
            category: 'Principais',
          ),
          dish('b4', 'Tarte tatin', price: 29, category: 'Sobremesas'),
          dish(
            'b5',
            'Polvo grelhado',
            price: 89,
            category: 'Principais',
            favorite: true,
            present: false,
          ),
        ],
      ),
      Menu(
        id: 'padaria',
        name: 'Padaria Trigo e Mel',
        url: 'https://www.canva.com/design/EXEMPLO/view',
        sourceType: SourceType.canva,
        createdAt: ago(const Duration(days: 4)),
        lastCheckedAt: ago(const Duration(minutes: 5)),
        dishes: [
          dish('p1', 'Pão de fermentação natural', price: 18),
          dish('p2', 'Croissant de amêndoas', price: 14),
          dish('p3', 'Bolo de fubá com goiabada', price: 9.5),
        ],
      ),
      Menu(
        id: 'ru',
        name: 'Restaurante Universitário',
        url: 'https://ru.exemplo.edu.br/cardapio.png',
        sourceType: SourceType.image,
        status: MenuStatus.error,
        lastError: 'Página não encontrada (erro 404). Confira o link.',
        createdAt: ago(const Duration(days: 12)),
        lastCheckedAt: ago(const Duration(minutes: 20)),
        dishes: [
          dish('r1', 'Estrogonofe de carne'),
          dish('r2', 'Escondidinho de abóbora'),
          dish('r3', 'Feijão carioca'),
        ],
      ),
    ],
    history: [
      ChangeEntry(
        id: 'h1',
        menuId: 'cantina',
        dishId: 'c1',
        dishName: 'Feijoada completa',
        type: ChangeType.returned,
        description: 'Voltou ao cardápio',
        detectedAt: ago(const Duration(hours: 2)),
      ),
      ChangeEntry(
        id: 'h2',
        menuId: 'cantina',
        dishId: 'c3',
        dishName: 'Lasanha à bolonhesa',
        type: ChangeType.price,
        description: 'De R\$ 26,00 para R\$ 28,50',
        detectedAt: ago(const Duration(hours: 2)),
      ),
      ChangeEntry(
        id: 'h3',
        menuId: 'cantina',
        dishName: 'Bife acebolado',
        type: ChangeType.removed,
        description: 'Saiu do cardápio',
        detectedAt: ago(const Duration(hours: 2)),
      ),
      ChangeEntry(
        id: 'h4',
        menuId: 'bistro',
        dishId: 'b5',
        dishName: 'Polvo grelhado',
        type: ChangeType.removed,
        description: 'Saiu do cardápio',
        detectedAt: ago(const Duration(days: 1, hours: 3)),
      ),
      ChangeEntry(
        id: 'h5',
        menuId: 'bistro',
        dishId: 'b3',
        dishName: 'Nhoque de batata-doce',
        type: ChangeType.added,
        description: 'Entrou no cardápio',
        detectedAt: ago(const Duration(days: 3)),
      ),
    ],
    notifications: [
      AppNotification(
        id: 'n1',
        kind: NotificationKind.favorite,
        menuId: 'cantina',
        title: 'Feijoada completa está disponível hoje',
        message: 'Seu favorito voltou ao cardápio de Cantina da Praça.',
        createdAt: ago(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n2',
        kind: NotificationKind.menuChanged,
        menuId: 'cantina',
        title: 'Cantina da Praça mudou',
        message: '1 prato saiu e 1 mudou de preço.',
        createdAt: ago(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n3',
        kind: NotificationKind.error,
        menuId: 'ru',
        read: true,
        title: 'Restaurante Universitário não pôde ser lido',
        message: 'Página não encontrada (erro 404). Confira o link.',
        createdAt: ago(const Duration(days: 1, hours: 1)),
      ),
      AppNotification(
        id: 'n4',
        kind: NotificationKind.favorite,
        menuId: 'bistro',
        read: true,
        title: 'Polvo grelhado saiu do cardápio',
        message: 'Seu favorito não está mais em Bistrô Aurora.',
        createdAt: ago(const Duration(days: 1, hours: 3)),
      ),
    ],
  );
}

var _fontsLoaded = false;

/// Carrega as fontes de verdade, para as capturas saírem como no aparelho.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> load(String family, String path) async {
    final bytes = await File(path).readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final packages = jsonDecode(
    await File('.dart_tool/package_config.json').readAsString(),
  ) as Map<String, dynamic>;
  final lucide = (packages['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'lucide_icons_flutter');
  final lucideRoot = Uri.parse(lucide['rootUri'] as String).toFilePath();

  await load('Bricolage', 'assets/fonts/BricolageGrotesque.ttf');
  await load('Hanken', 'assets/fonts/HankenGrotesk.ttf');
  await load(
    'MaterialIcons',
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await load(
    'packages/lucide_icons_flutter/Lucide',
    '$lucideRoot/assets/lucide.ttf',
  );
}

class TestApp {
  TestApp({AppData? data, MenuReader? reader, FakeAlerts? alerts})
    : store = MemoryStore(data ?? sampleData()),
      alerts = alerts ?? FakeAlerts(),
      reader = reader ?? readerFor(const {});

  final MemoryStore store;
  final FakeAlerts alerts;
  final MenuReader reader;
  final scheduled = <int>[];

  AppData get data => store.data;

  Widget build({String initial = Routes.home}) => ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(store),
      initialDataProvider.overrideWithValue(store.data),
      alertsProvider.overrideWithValue(alerts),
      readerProvider.overrideWithValue(reader),
      schedulerProvider.overrideWithValue((m) async => scheduled.add(m)),
      initialLocationProvider.overrideWithValue(initial),
    ],
    child: const MenuWatchApp(),
  );
}

/// Tela de celular comum: 412 x 915 pontos.
void usePhone(WidgetTester tester, {double ratio = 2}) {
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = Size(412 * ratio, 915 * ratio);
  addTearDown(tester.view.reset);
}

/// Avança o tempo o bastante para transições e folhas terminarem, sem
/// esperar por animações que se repetem.
///
/// A cada quadro o laço de eventos de verdade também gira: o fim da leitura
/// de uma resposta HTTP passa por ele, e sem isso a leitura de um cardápio
/// nunca terminaria dentro do relógio falso dos testes.
Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}
