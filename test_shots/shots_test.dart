import 'dart:async';

// Capturas de tela para revisão visual. Não fazem parte da suíte de testes:
//   flutter test --update-goldens test_shots/shots_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuwatch/main.dart';
import 'package:menuwatch/models/models.dart';
import 'package:menuwatch/routes/router.dart';

import '../test/support/fixture.dart';

Future<void> shot(WidgetTester tester, String name) =>
    expectLater(find.byType(MenuWatchApp), matchesGoldenFile('out/$name.png'));

/// Nos testes o Flutter troca as sombras por contornos pretos. Aqui elas
/// voltam, para a captura ficar igual ao que aparece no aparelho.
void screen(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(loadAppFonts);

  for (final theme in [AppThemeMode.light, AppThemeMode.dark]) {
    final t = theme.name;

    screen('telas principais ($t)', (tester) async {
      usePhone(tester);
      final app = TestApp(data: sampleData(theme: theme));
      await tester.pumpWidget(app.build());
      await settle(tester);
      await shot(tester, 'inicio_$t');

      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await settle(tester);
      await shot(tester, 'inicio_rolado_$t');

      await tester.tap(find.text('Favoritos'));
      await settle(tester);
      await shot(tester, 'favoritos_$t');

      await tester.tap(find.text('Avisos'));
      await settle(tester);
      await shot(tester, 'avisos_$t');

      await tester.tap(find.text('Ajustes'));
      await settle(tester);
      await shot(tester, 'ajustes_$t');

      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await settle(tester);
      await shot(tester, 'ajustes_rolado_$t');
    });

    screen('cardápio ($t)', (tester) async {
      usePhone(tester);
      final app = TestApp(data: sampleData(theme: theme));
      await tester.pumpWidget(app.build(initial: Routes.menu('cantina')));
      await settle(tester);
      await shot(tester, 'cardapio_$t');

      await tester.tap(find.text('Feijoada completa'));
      await settle(tester);
      await shot(tester, 'prato_$t');
      await tester.tapAt(const Offset(200, 60));
      await settle(tester);

      await tester.tap(find.textContaining('Histórico'));
      await settle(tester);
      await shot(tester, 'historico_$t');

      await tester.tap(find.byTooltip('Mais opções'));
      await settle(tester);
      await shot(tester, 'opcoes_$t');
    });
  }

  screen('cardápio sem data e com erro', (tester) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build(initial: Routes.menu('bistro')));
    await settle(tester);
    await shot(tester, 'cardapio_sem_data');

    await tester.pumpWidget(const SizedBox());
    final other = TestApp();
    await tester.pumpWidget(other.build(initial: Routes.menu('ru')));
    await settle(tester);
    await shot(tester, 'cardapio_erro');
  });

  screen('vazios', (tester) async {
    usePhone(tester);
    final app = TestApp(
      data: const AppData(),
      alerts: FakeAlerts(enabled: false),
    );
    await tester.pumpWidget(app.build());
    await settle(tester);
    await shot(tester, 'vazio_inicio');
    await tester.tap(find.text('Favoritos'));
    await settle(tester);
    await shot(tester, 'vazio_favoritos');
    await tester.tap(find.text('Avisos'));
    await settle(tester);
    await shot(tester, 'vazio_avisos');
  });

  screen('adicionar cardápio', (tester) async {
    usePhone(tester);
    const url = 'https://sabordacasa.exemplo.com.br/cardapio';
    final hold = Completer<void>();
    final app = TestApp(
      data: const AppData(),
      reader: readerFor({
        url: menuPage('Cardápio | Sabor da Casa', {
          'Pratos do dia': [
            'Feijoada completa R\$ 32,90',
            'Frango grelhado com legumes R\$ 24,00',
            'Lasanha à bolonhesa R\$ 28,50',
          ],
          'Sobremesas': [
            'Pudim de leite R\$ 9,00',
            'Salada de frutas R\$ 7,50',
          ],
        }),
        'https://fechado.exemplo.com.br/': 403,
      }, hold: hold.future),
    );
    await tester.pumpWidget(app.build(initial: Routes.add));
    await settle(tester);
    await shot(tester, 'adicionar');

    await tester.enterText(
      find.byType(TextField),
      'https://fechado.exemplo.com.br/',
    );
    await tester.pump();
    await tester.tap(find.text('Ler cardápio'));
    await settle(tester, 5);
    await shot(tester, 'adicionar_lendo');
    hold.complete();
    await settle(tester);
    expect(find.textContaining('exige login'), findsOneWidget);
    await shot(tester, 'adicionar_erro');

    await tester.enterText(find.byType(TextField), url);
    await tester.pump();
    await tester.tap(find.text('Ler cardápio'));
    await settle(tester, 12);
    await shot(tester, 'adicionar_previa');

    await tester.tap(find.text('Acompanhar cardápio'));
    await settle(tester);
    await shot(tester, 'adicionar_notificacoes');
  });

  screen('abertura', (tester) async {
    usePhone(tester);
    final app = TestApp();
    await tester.pumpWidget(app.build(initial: Routes.splash));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await shot(tester, 'abertura');
    await settle(tester, 20);
  });
}
