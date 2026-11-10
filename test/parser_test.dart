import 'package:flutter_test/flutter_test.dart';
import 'package:menuwatch/models/models.dart';
import 'package:menuwatch/services/parser/menu_parser.dart';

List<SourceLine> lines(String text) => [
  for (final l in text.trim().split('\n')) SourceLine(l),
];

// Uma terça-feira.
final today = DateTime(2026, 11, 10);

void main() {
  group('cardápio com preços', () {
    test('nome e preço na mesma linha, com categorias', () {
      final menu = parseMenu(lines('''
RESTAURANTE SABOR DA CASA
Rua das Flores, 120 - Centro
(11) 99999-0000
ENTRADAS
Bolinho de bacalhau (6 un) ........ R\$ 32,90
Caldo de feijão R\$ 18,00
PRATOS PRINCIPAIS
Strogonoff de frango - arroz e batata palha R\$ 42,50
Picanha na chapa 1.250,00
Bebidas
Suco de laranja 9,00
Refrigerante lata R\$ 7
'''), now: today);

      expect(menu.dishes.map((d) => d.name), [
        'Bolinho de bacalhau (6 un)',
        'Caldo de feijão',
        'Strogonoff de frango',
        'Picanha na chapa',
        'Suco de laranja',
        'Refrigerante lata',
      ]);
      expect(menu.dishes[0].price, 32.90);
      expect(menu.dishes[0].category, 'Entradas');
      expect(menu.dishes[2].description, 'arroz e batata palha');
      expect(menu.dishes[2].category, 'Pratos principais');
      expect(menu.dishes[3].price, 1250.00);
      expect(menu.dishes[4].category, 'Bebidas');
      expect(menu.dishes[5].price, 7);
      // Cardápio permanente: nada confirma que os pratos são servidos hoje.
      expect(
        menu.dishes.every((d) => d.availability == Availability.unknown),
        isTrue,
      );
      expect(menu.referenceDate, isNull);
    });

    test('preço em linha separada, com descrição', () {
      final menu = parseMenu(lines('''
Lanches
X-Burger
Pão, hambúrguer 150g, queijo e molho da casa
R\$ 24,90
X-Salada
Pão, hambúrguer 150g, queijo, alface e tomate
R\$ 27,90
Batata frita
R\$ 15,00
'''), now: today);

      expect(menu.dishes.map((d) => d.name), [
        'X-Burger',
        'X-Salada',
        'Batata frita',
      ]);
      expect(menu.dishes[0].description, contains('hambúrguer 150g'));
      expect(menu.dishes[1].price, 27.90);
      expect(menu.dishes[2].category, 'Lanches');
    });

    test('título seguido de preço é prato, não categoria', () {
      final menu = parseMenu([
        const SourceLine('Pizzas', heading: 2),
        const SourceLine('Margherita', heading: 3),
        const SourceLine('Molho de tomate, muçarela e manjericão'),
        const SourceLine('R\$ 49,00'),
        const SourceLine('Calabresa', heading: 3),
        const SourceLine('Calabresa fatiada e cebola'),
        const SourceLine('R\$ 52,00'),
        const SourceLine('Portuguesa', heading: 3),
        const SourceLine('R\$ 55,00'),
      ], now: today);

      expect(menu.dishes.map((d) => d.name), [
        'Margherita',
        'Calabresa',
        'Portuguesa',
      ]);
      expect(menu.dishes.every((d) => d.category == 'Pizzas'), isTrue);
    });

    test('prato esgotado e meia porção', () {
      final menu = parseMenu(lines('''
Porções
Frango a passarinho 1/2 porção R\$ 28,00
Isca de peixe (esgotado) R\$ 39,00
Mandioca frita R\$ 22,00
'''), now: today);

      expect(menu.referenceDate, isNull, reason: '"1/2" não é data');
      expect(menu.dishes[1].name, 'Isca de peixe');
      expect(menu.dishes[1].availability, Availability.unavailable);
    });

    test('pratos repetidos entram uma vez só', () {
      final menu = parseMenu(lines('''
Coxinha R\$ 8,00
COXINHA R\$ 8,00
Empada R\$ 7,00
Kibe R\$ 7,50
'''), now: today);
      expect(menu.dishes, hasLength(3));
    });
  });

  group('cardápio do dia, sem preços', () {
    test('com a data de hoje, a disponibilidade é confirmada', () {
      final menu = parseMenu(lines('''
CARDÁPIO DO DIA - 10/11/2026
Prato principal: Strogonoff de frango
Opção vegetariana: Quibe de abóbora
Guarnição: Arroz branco; Feijão carioca; Batata palha
Salada: Alface e tomate
Sobremesa: Gelatina
'''), now: today);

      expect(menu.referenceDate, DateTime(2026, 11, 10));
      expect(menu.dishes.map((d) => d.name), [
        'Strogonoff de frango',
        'Quibe de abóbora',
        'Arroz branco',
        'Feijão carioca',
        'Batata palha',
        'Alface e tomate',
        'Gelatina',
      ]);
      expect(menu.dishes.first.category, 'Prato principal');
      expect(
        menu.dishes.every((d) => d.availability == Availability.confirmed),
        isTrue,
      );
    });

    test('com data de outro dia, a disponibilidade não é afirmada', () {
      final menu = parseMenu(lines('''
Cardápio de 9 de novembro
Almoço
Feijoada completa
Couve refogada
Laranja
'''), now: today);

      expect(menu.referenceDate, DateTime(2026, 11, 9));
      expect(menu.dishes, hasLength(3));
      expect(
        menu.dishes.every((d) => d.availability == Availability.unknown),
        isTrue,
      );
    });

    test('cardápio semanal: só a seção de hoje vira prato', () {
      final menu = parseMenu(lines('''
CARDÁPIO DA SEMANA
Segunda-feira
Frango assado
Purê de batata
Terça-feira
Carne de panela
Macarrão ao sugo
Quarta-feira
Peixe empanado
'''), now: today);

      expect(menu.dishes.map((d) => d.name), [
        'Carne de panela',
        'Macarrão ao sugo',
      ]);
      expect(menu.dishes.first.availability, Availability.confirmed);
    });

    test('texto comum de site não vira prato', () {
      final menu = parseMenu([
        const SourceLine('Nossa história', heading: 2),
        const SourceLine('Desde 1998 servindo a melhor comida caseira'),
        const SourceLine('Venha nos visitar com a família'),
        const SourceLine('Ambiente climatizado'),
        const SourceLine('Trabalhe conosco', heading: 2),
        const SourceLine('Envie seu currículo'),
      ], now: today);
      expect(menu.dishes, isEmpty);
    });

    test('seção de comida sem data lista pratos sem afirmar disponibilidade', () {
      final menu = parseMenu([
        const SourceLine('Sobremesas', heading: 2),
        const SourceLine('Pudim de leite'),
        const SourceLine('Mousse de maracujá'),
        const SourceLine('Sobre nós', heading: 2),
        const SourceLine('Uma casa de família'),
      ], now: today);
      expect(menu.dishes.map((d) => d.name), [
        'Pudim de leite',
        'Mousse de maracujá',
      ]);
      expect(menu.dishes.first.availability, Availability.unknown);
    });
  });

  test('texto vazio não gera pratos', () {
    expect(parseMenu(const [], now: today).dishes, isEmpty);
    expect(parseMenu(lines('Olá\nBem-vindo'), now: today).dishes, isEmpty);
  });
}
