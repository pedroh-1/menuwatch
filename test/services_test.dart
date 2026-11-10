import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:menuwatch/models/models.dart';
import 'package:menuwatch/services/differ.dart';
import 'package:menuwatch/services/extraction/bmp.dart';
import 'package:menuwatch/services/extraction/fetcher.dart';
import 'package:menuwatch/services/extraction/html_extractor.dart';
import 'package:menuwatch/services/extraction/ocr.dart';
import 'package:menuwatch/services/monitor.dart';
import 'package:menuwatch/services/parser/menu_parser.dart';

final now = DateTime(2026, 11, 10, 12);

ParsedMenu parsed(List<ParsedDish> dishes, {DateTime? date}) =>
    ParsedMenu(dishes: dishes, referenceDate: date);

ParsedDish dish(
  String name, {
  double? price,
  Availability availability = Availability.unknown,
}) => ParsedDish(
  name: name,
  category: 'Cardápio',
  price: price,
  availability: availability,
);

Menu menuWith(List<Dish> dishes, {DateTime? date}) => Menu(
  id: 'm1',
  name: 'Sabor da Casa',
  url: 'https://exemplo.com.br/cardapio',
  sourceType: SourceType.html,
  dishes: dishes,
  referenceDate: date,
);

void main() {
  group('comparação de leituras', () {
    final base = menuWith([
      Dish(id: 'a', name: 'Feijoada', price: 30),
      Dish(id: 'b', name: 'Lasanha', price: 28, favorite: true),
      Dish(id: 'c', name: 'Pudim', price: 9),
    ]);

    test('sem mudança, nada é registrado', () {
      final diff = diffMenu(
        base,
        parsed([
          dish('FEIJOADA', price: 30),
          dish('lasanha', price: 28),
          dish('Pudím', price: 9),
        ]),
        now: now,
      );
      expect(diff.changes, isEmpty);
      expect(diff.dishes.map((d) => d.id), ['a', 'b', 'c']);
      expect(diff.dishes[1].favorite, isTrue);
    });

    test('prato novo, removido e preço alterado', () {
      final diff = diffMenu(
        base,
        parsed([
          dish('Feijoada', price: 34),
          dish('Lasanha', price: 28),
          dish('Moqueca', price: 45),
        ]),
        now: now,
      );
      expect(diff.changes.map((c) => c.type), [
        ChangeType.price,
        ChangeType.added,
        ChangeType.removed,
      ]);
      expect(diff.changes.first.description, 'De R\$ 30,00 para R\$ 34,00');
      expect(diff.dishes.map((d) => d.name), ['Feijoada', 'Lasanha', 'Moqueca']);
    });

    test('favorito removido é guardado e sua volta é registrada', () {
      final gone = diffMenu(base, parsed([dish('Feijoada', price: 30)]), now: now);
      final kept = gone.dishes.firstWhere((d) => d.id == 'b');
      expect(kept.present, isFalse);
      expect(gone.dishes.any((d) => d.id == 'c'), isFalse);

      final back = diffMenu(
        menuWith(gone.dishes),
        parsed([dish('Feijoada', price: 30), dish('Lasanha', price: 29)]),
        now: now,
      );
      expect(back.changes.single.type, ChangeType.returned);
      expect(back.dishes.firstWhere((d) => d.id == 'b').present, isTrue);
    });
  });

  group('avisos', () {
    const settings = AppSettings();

    List<AppNotification> check(Menu before, ParsedMenu read, {AppSettings s = settings}) {
      final diff = diffMenu(before, read, now: now);
      final after = before.copyWith(
        dishes: diff.dishes,
        referenceDate: read.referenceDate,
      );
      return buildNotifications(
        before: before,
        after: after,
        changes: diff.changes,
        settings: s,
        now: now,
      );
    }

    test('favorito confirmado para hoje avisa uma vez só', () {
      final before = menuWith([
        Dish(id: 'a', name: 'Feijoada', favorite: true),
        Dish(id: 'b', name: 'Arroz'),
      ]);
      final read = parsed([
        dish('Feijoada', availability: Availability.confirmed),
        dish('Arroz', availability: Availability.confirmed),
      ], date: now);

      final first = check(before, read);
      expect(first, hasLength(1));
      expect(first.single.title, 'Seu prato favorito está disponível!');
      expect(first.single.kind, NotificationKind.favorite);

      // Segunda verificação do mesmo cardápio: nenhum aviso repetido.
      final diff = diffMenu(before, read, now: now);
      final after = before.copyWith(dishes: diff.dishes, referenceDate: now);
      expect(check(after, read), isEmpty);
    });

    test('favorito em cardápio permanente não é dado como disponível', () {
      final before = menuWith([
        Dish(id: 'a', name: 'Feijoada', favorite: true, present: false),
        Dish(id: 'b', name: 'Arroz'),
      ]);
      final result = check(before, parsed([dish('Feijoada'), dish('Arroz')]));
      expect(result.single.title, 'Seu prato favorito voltou ao cardápio');
      expect(result.single.message, contains('não informa se o prato é servido hoje'));
    });

    test('mudanças comuns viram um único resumo', () {
      final before = menuWith([
        Dish(id: 'a', name: 'Feijoada', price: 30),
        Dish(id: 'b', name: 'Pudim', price: 9),
      ]);
      final result = check(
        before,
        parsed([dish('Feijoada', price: 33), dish('Moqueca', price: 45)]),
      );
      expect(result, hasLength(1));
      expect(result.single.title, 'Sabor da Casa mudou');
      expect(
        result.single.message,
        '1 prato novo (Moqueca), 1 prato saiu (Pudim), 1 preço mudou.',
      );
    });

    test('preferências desligadas silenciam os avisos', () {
      final before = menuWith([Dish(id: 'a', name: 'Feijoada', price: 30)]);
      final read = parsed([dish('Feijoada', price: 33), dish('Moqueca')]);
      const off = AppSettings(
        notifyMenuChanges: false,
        notifyPriceChanges: false,
      );
      expect(check(before, read, s: off), isEmpty);
      final onlyPrice = check(
        before,
        read,
        s: const AppSettings(notifyMenuChanges: false),
      );
      expect(onlyPrice.single.title, 'Preço alterado em Sabor da Casa');
    });
  });

  group('robots.txt', () {
    const canva = '''
User-agent: *
Disallow:
Disallow: /media/*
Disallow: *utm_source=
Disallow: /privado/
Allow: /privado/cardapio
Disallow: /*.json\$
''';

    test('regras com curinga e a mais específica vence', () {
      expect(robotsAllows(canva, '/design/abc/view'), isTrue);
      expect(robotsAllows(canva, '/media/foto.png'), isFalse);
      expect(robotsAllows(canva, '/x?utm_source=insta'), isFalse);
      expect(robotsAllows(canva, '/privado/area'), isFalse);
      expect(robotsAllows(canva, '/privado/cardapio'), isTrue);
      expect(robotsAllows(canva, '/dados.json'), isFalse);
      expect(robotsAllows(canva, '/dados.json?x=1'), isTrue);
    });

    test('grupo próprio do app tem prioridade', () {
      const txt = 'User-agent: *\nAllow: /\n\nUser-agent: MenuWatch\nDisallow: /';
      expect(robotsAllows(txt, '/cardapio'), isFalse);
    });

    test('sem regras, tudo é permitido', () {
      expect(robotsAllows('', '/cardapio'), isTrue);
    });
  });

  group('endereços', () {
    test('aceita link sem https e recusa texto solto', () {
      expect(normalizeUrl('exemplo.com.br/cardapio').toString(),
          'https://exemplo.com.br/cardapio');
      expect(() => normalizeUrl('cardápio do dia'), throwsA(isA<ReadFailure>()));
      expect(() => normalizeUrl('  '), throwsA(isA<ReadFailure>()));
    });

    test('link de visualização do Google Drive vira link do arquivo', () {
      final uri = normalizeUrl(
        'https://drive.google.com/file/d/ABC123/view?usp=sharing',
      );
      expect(uri.path, '/uc');
      expect(uri.queryParameters['id'], 'ABC123');
    });

    test('reconhece Canva', () {
      expect(isCanva(Uri.parse('https://www.canva.com/design/x/view')), isTrue);
      expect(isCanva(Uri.parse('https://bistro.my.canva.site/')), isTrue);
      expect(isCanva(Uri.parse('https://exemplo.com/canva')), isFalse);
    });
  });

  group('HTML', () {
    test('lê linhas na ordem, ignora menu e rodapé, acha imagens', () {
      final content = extractHtml('''
<html><head><title>Cardápio | Cantina Bella</title></head><body>
<nav><a href="/">Home</a><a href="/contato">Contato</a></nav>
<h2>Massas</h2>
<ul>
  <li><span>Lasanha à bolonhesa</span> <b>R\$ 38,00</b></li>
  <li><span>Nhoque ao sugo</span> <b>R\$ 34,00</b></li>
</ul>
<img src="/img/cardapio-novembro.jpg" width="1200" height="1800">
<img src="/img/logo.png">
<footer>Rua A, 10</footer>
</body></html>''', Uri.parse('https://cantina.example/cardapio'));

      expect(content.siteName, 'Cantina Bella');
      expect(content.lines.map((l) => l.text), [
        'Massas',
        'Lasanha à bolonhesa R\$ 38,00',
        'Nhoque ao sugo R\$ 34,00',
      ]);
      expect(content.lines.first.heading, 2);
      expect(content.imageUrls.single.toString(),
          'https://cantina.example/img/cardapio-novembro.jpg');
    });

    test('tabela semanal vira seções por dia', () {
      final content = extractHtml('''
<table>
<tr><th></th><th>Segunda</th><th>Terça</th><th>Quarta</th></tr>
<tr><td>Prato principal</td><td>Frango</td><td>Carne de panela</td><td>Peixe</td></tr>
<tr><td>Sobremesa</td><td>Maçã</td><td>Gelatina</td><td>Pudim</td></tr>
</table>''', Uri.parse('https://ru.example/'));
      final menu = parseMenu(content.lines, now: now); // terça-feira
      expect(menu.dishes.map((d) => '${d.category}: ${d.name}'), [
        'Prato principal: Carne de panela',
        'Sobremesa: Gelatina',
      ]);
      expect(menu.dishes.first.availability, Availability.confirmed);
    });

    test('dados estruturados schema.org', () {
      final json = jsonEncode({
        '@type': 'Menu',
        'hasMenuSection': {
          '@type': 'MenuSection',
          'name': 'Entradas',
          'hasMenuItem': [
            {
              '@type': 'MenuItem',
              'name': 'Bruschetta',
              'description': 'Tomate e manjericão',
              'offers': {'@type': 'Offer', 'price': '22.00'},
            },
          ],
        },
      });
      final content = extractHtml(
        '<html><body><script type="application/ld+json">$json</script></body></html>',
        Uri.parse('https://a.example/'),
      );
      expect(content.structured.single.name, 'Bruschetta');
      expect(content.structured.single.category, 'Entradas');
      expect(content.structured.single.price, 22.0);
    });

    test('decodifica latin1 declarado na página', () {
      final bytes = Uint8List.fromList(
        latin1.encode('<meta charset="iso-8859-1"><p>Feijão</p>'),
      );
      expect(decodeHtml(bytes, null), contains('Feijão'));
    });
  });

  group('OCR', () {
    test('junta nome e preço da mesma linha e separa colunas', () {
      final rows = mergeOcrRows(const [
        OcrPiece('R\$ 32,90', 400, 102, 470, 122),
        OcrPiece('Feijoada completa', 20, 100, 220, 120),
        OcrPiece('Suco de laranja', 520, 101, 660, 121),
        OcrPiece('R\$ 9,00', 900, 100, 960, 120),
        OcrPiece('Lasanha', 20, 140, 110, 160),
        OcrPiece('R\$ 28,00', 400, 141, 470, 161),
      ]);
      expect(rows.map((r) => r.text), [
        'Feijoada completa R\$ 32,90',
        'Suco de laranja R\$ 9,00',
        'Lasanha R\$ 28,00',
      ]);
    });
  });

  test('BMP tem cabeçalho e pixels de baixo para cima', () {
    // 2x2: linha de cima azul e verde, linha de baixo vermelho e branco.
    final bgra = Uint8List.fromList([
      255, 0, 0, 255, 0, 255, 0, 255, //
      0, 0, 255, 255, 255, 255, 255, 255,
    ]);
    final bmp = bmpFromBgra(bgra, 2, 2);
    expect(bmp.sublist(0, 2), [0x42, 0x4D]);
    expect(bmp.length, 54 + 16);
    expect(bmp.sublist(54, 60), [0, 0, 255, 255, 255, 255]);
    expect(bmp.sublist(62, 68), [255, 0, 0, 0, 255, 0]);
  });
}
