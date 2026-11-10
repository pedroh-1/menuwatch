import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuwatch/models/models.dart';
import 'package:menuwatch/routes/router.dart';

import 'support/fixture.dart';

const _url = 'https://sabordacasa.exemplo.com.br/cardapio';

String _page(Map<String, List<String>> sections) =>
    menuPage('Cardápio | Sabor da Casa', sections);

final _firstReading = _page({
  'Pratos do dia': [
    'Feijoada completa R\$ 32,90',
    'Frango grelhado com legumes R\$ 24,00',
    'Lasanha à bolonhesa R\$ 28,50',
  ],
  'Sobremesas': ['Pudim de leite R\$ 9,00', 'Salada de frutas R\$ 7,50'],
});

Future<void> _readLink(WidgetTester tester, String url) async {
  await tester.enterText(find.byType(TextField), url);
  await tester.pump();
  await tester.tap(find.text('Ler cardápio'));
  await settle(tester, 10);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('adiciona um cardápio a partir do link', (tester) async {
    usePhone(tester);
    final app = TestApp(
      data: const AppData(),
      reader: readerFor({_url: _firstReading}),
      alerts: FakeAlerts()..enabled = false,
    );
    await tester.pumpWidget(app.build(initial: Routes.add));
    await settle(tester);

    await _readLink(tester, _url);
    expect(find.text('5 pratos encontrados'), findsOneWidget);
    expect(app.data.menus, isEmpty, reason: 'a prévia ainda não salva nada');

    await tester.tap(find.text('Acompanhar cardápio'));
    await settle(tester);

    final menu = app.data.menus.single;
    expect(menu.name, 'Sabor da Casa');
    expect(menu.url, _url);
    expect(menu.sourceType, SourceType.html);
    expect(menu.dishes.map((d) => d.name), contains('Lasanha à bolonhesa'));
    expect(menu.dishes, hasLength(5));
    // Sem data no cardápio, nenhum prato é dado como servido hoje.
    expect(
      menu.dishes.every((d) => d.availability == Availability.unknown),
      isTrue,
    );
    // A primeira leitura não é uma mudança.
    expect(app.data.history, isEmpty);
    expect(app.data.notifications, isEmpty);

    expect(find.text('Agora não'), findsOneWidget);
    await tester.tap(find.text('Agora não'));
    await settle(tester);
    expect(find.text('Sabor da Casa'), findsOneWidget);
  });

  testWidgets('explica por que um link protegido não foi lido', (tester) async {
    usePhone(tester);
    final app = TestApp(
      data: const AppData(),
      reader: readerFor({'https://fechado.exemplo.com.br/': 403}),
    );
    await tester.pumpWidget(app.build(initial: Routes.add));
    await settle(tester);

    await _readLink(tester, 'https://fechado.exemplo.com.br/');
    expect(find.textContaining('exige login'), findsOneWidget);
    expect(find.textContaining('não contorna'), findsOneWidget);
    expect(app.data.menus, isEmpty);
  });

  testWidgets('página sem pratos não vira cardápio', (tester) async {
    usePhone(tester);
    const url = 'https://blog.exemplo.com.br/';
    final app = TestApp(
      data: const AppData(),
      reader: readerFor({
        url: '<html><body><h1>Blog</h1><p>Texto qualquer.</p></body></html>',
      }),
    );
    await tester.pumpWidget(app.build(initial: Routes.add));
    await settle(tester);

    await _readLink(tester, url);
    expect(find.text('Acompanhar cardápio'), findsNothing);
    expect(find.text('Ler cardápio'), findsOneWidget);
    expect(app.data.menus, isEmpty);
  });

  testWidgets('não aceita o mesmo link duas vezes', (tester) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build(initial: Routes.add));
    await settle(tester);

    await _readLink(tester, 'cantina.exemplo.com.br/cardapio-do-dia');
    expect(find.textContaining('Você já acompanha este link'), findsOneWidget);
    expect(app.data.menus, hasLength(4));
  });

  testWidgets('verificar agora registra as mudanças sem notificar', (
    tester,
  ) async {
    usePhone(tester);
    final pages = <String, Object>{_url: _firstReading};
    final app = TestApp(data: const AppData(), reader: readerFor(pages));
    await tester.pumpWidget(app.build(initial: Routes.add));
    await settle(tester);
    await _readLink(tester, _url);
    await tester.tap(find.text('Acompanhar cardápio'));
    await settle(tester);
    if (find.text('Agora não').evaluate().isNotEmpty) {
      await tester.tap(find.text('Agora não'));
      await settle(tester);
    }

    // O site muda: a lasanha sai, o pudim fica mais caro, entra um prato.
    pages[_url] = _page({
      'Pratos do dia': [
        'Feijoada completa R\$ 32,90',
        'Frango grelhado com legumes R\$ 24,00',
        'Moqueca de banana-da-terra R\$ 34,00',
      ],
      'Sobremesas': ['Pudim de leite R\$ 11,00', 'Salada de frutas R\$ 7,50'],
    });
    await tester.tap(find.byTooltip('Verificar agora'));
    await settle(tester, 10);

    final types = app.data.history.map((h) => (h.dishName, h.type)).toSet();
    expect(types, {
      ('Lasanha à bolonhesa', ChangeType.removed),
      ('Pudim de leite', ChangeType.price),
      ('Moqueca de banana-da-terra', ChangeType.added),
    });
    expect(find.text('3 mudanças encontradas.'), findsOneWidget);
    expect(app.alerts.shown, isEmpty, reason: 'o usuário já está olhando');
    final menu = app.data.menus.single;
    expect(
      menu.dishes.where((d) => d.present).map((d) => d.name),
      isNot(contains('Lasanha à bolonhesa')),
    );

    // Verificar de novo sem mudança não cria registros repetidos.
    await tester.tap(find.byTooltip('Verificar agora'));
    await settle(tester, 10);
    expect(app.data.history, hasLength(3));
  });

  testWidgets('ao abrir o app, avisa que um favorito voltou', (tester) async {
    usePhone(tester);
    final old = DateTime.now().subtract(const Duration(hours: 5));
    final app = TestApp(
      reader: readerFor({_url: _firstReading}),
      data: AppData(
        settings: const AppSettings(onboarded: true),
        menus: [
          Menu(
            id: 'm1',
            name: 'Sabor da Casa',
            url: _url,
            sourceType: SourceType.html,
            createdAt: old,
            lastCheckedAt: old,
            dishes: [
              for (final (i, name) in [
                'Feijoada completa',
                'Frango grelhado com legumes',
                'Pudim de leite',
                'Salada de frutas',
              ].indexed)
                Dish(
                  id: 'd$i',
                  name: name,
                  category: 'Pratos do dia',
                  firstSeenAt: old,
                  lastSeenAt: old,
                ),
              Dish(
                id: 'fav',
                name: 'Lasanha à bolonhesa',
                price: 28.5,
                category: 'Pratos do dia',
                favorite: true,
                present: false,
                firstSeenAt: old,
                lastSeenAt: old,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpWidget(app.build());
    await settle(tester, 10);

    final lasanha = app.data.menus.single.dishes.firstWhere(
      (d) => d.name == 'Lasanha à bolonhesa',
    );
    expect(lasanha.present, isTrue);
    expect(lasanha.favorite, isTrue);
    final favorites = app.alerts.shown.where(
      (n) => n.kind == NotificationKind.favorite,
    );
    expect(favorites, hasLength(1));
    expect(
      '${favorites.single.title} ${favorites.single.message}',
      contains('Lasanha à bolonhesa'),
    );
    expect(
      app.data.notifications.where((n) => n.kind == NotificationKind.favorite),
      hasLength(1),
    );
  });

  testWidgets('favoritar um prato fica guardado', (tester) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build());
    await settle(tester);

    await tester.tap(find.text('Cantina da Praça'));
    await settle(tester);
    await tester.tap(find.byTooltip('Favoritar Frango grelhado com legumes'));
    await settle(tester);

    Dish frango() => app.data.menus
        .firstWhere((m) => m.id == 'cantina')
        .dishes
        .firstWhere((d) => d.id == 'c2');
    expect(frango().favorite, isTrue);

    await tester.tap(
      find.byTooltip('Tirar Frango grelhado com legumes dos favoritos'),
    );
    await settle(tester);
    expect(frango().favorite, isFalse);
  });

  testWidgets('remover um cardápio pede confirmação', (tester) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build());
    await settle(tester);

    await tester.tap(find.text('Bistrô Aurora'));
    await settle(tester);
    await tester.tap(find.byTooltip('Mais opções'));
    await settle(tester);
    await tester.tap(find.text('Remover'));
    await settle(tester);
    expect(find.text('Remover Bistrô Aurora?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(app.data.menus.any((m) => m.id == 'bistro'), isTrue);

    await tester.tap(find.byTooltip('Mais opções'));
    await settle(tester);
    await tester.tap(find.text('Remover'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Remover'));
    await settle(tester);

    expect(app.data.menus.any((m) => m.id == 'bistro'), isFalse);
    expect(app.data.history.any((h) => h.menuId == 'bistro'), isFalse);
    // De volta ao início, com um cardápio a menos.
    expect(find.text('Seus cardápios  3'), findsOneWidget);
    expect(find.text('Bistrô Aurora removido.'), findsOneWidget);
  });

  testWidgets('abrir um aviso marca como lido e leva ao cardápio', (
    tester,
  ) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build());
    await settle(tester);
    expect(app.data.unreadCount, 2);

    await tester.tap(find.text('Avisos'));
    await settle(tester);
    await tester.tap(find.text('Cantina da Praça mudou'));
    await settle(tester);

    expect(app.data.unreadCount, 1);
    expect(find.text('Cantina da Praça'), findsOneWidget);
    expect(find.text('Bife acebolado'), findsOneWidget);
  });

  testWidgets('ajustes de frequência e tema são guardados', (tester) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build());
    await settle(tester);

    await tester.tap(find.text('Ajustes'));
    await settle(tester);
    await tester.tap(find.text('Verificar os cardápios'));
    await settle(tester);
    await tester.tap(find.text('A cada 3 horas'));
    await settle(tester);

    expect(app.data.settings.frequencyMinutes, 180);
    expect(app.scheduled, [180]);

    await tester.tap(find.text('Escuro'));
    await settle(tester);
    expect(app.data.settings.themeMode, AppThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Aparência'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('sem permissão, os avisos ficam só dentro do app', (
    tester,
  ) async {
    usePhone(tester);
    final app = TestApp(
      alerts: FakeAlerts()
        ..enabled = false
        ..grantOnRequest = false,
    );
    await tester.pumpWidget(app.build());
    await settle(tester);

    await tester.tap(find.text('Avisos'));
    await settle(tester);
    expect(find.textContaining('estão desativadas'), findsOneWidget);

    await tester.tap(find.text('Ativar notificações'));
    await settle(tester);
    expect(find.textContaining('O Android não liberou'), findsOneWidget);
  });
}
