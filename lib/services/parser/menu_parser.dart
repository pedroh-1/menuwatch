import '../../models/models.dart';
import '../../utils/text_utils.dart';

/// Uma linha de texto extraída da fonte, na ordem de leitura.
class SourceLine {
  const SourceLine(this.text, {this.heading = 0});

  final String text;

  /// Nível do título em HTML (1 a 6), ou 0 quando é texto comum.
  final int heading;
}

class ParsedDish {
  ParsedDish({
    required this.name,
    required this.category,
    this.description,
    this.price,
    this.availability = Availability.unknown,
  });

  final String name;
  final String category;
  String? description;
  final double? price;
  final Availability availability;
}

class ParsedMenu {
  const ParsedMenu({required this.dishes, this.referenceDate});

  final List<ParsedDish> dishes;
  final DateTime? referenceDate;
}

const defaultCategory = 'Cardápio';

const _categoryWords = {
  'entradas', 'entrada', 'petiscos', 'porcoes', 'aperitivos', 'tira gosto',
  'pratos principais', 'prato principal', 'principais', 'pratos',
  'pratos executivos', 'executivos', 'executivo', 'pratos do dia',
  'prato do dia', 'carnes', 'carne', 'aves', 'frango', 'peixes', 'peixe',
  'frutos do mar', 'massas', 'massa', 'risotos', 'pizzas', 'pizzas salgadas',
  'pizzas doces', 'esfihas', 'lanches', 'lanche', 'sanduiches',
  'hamburgueres', 'burgers', 'hot dogs', 'saladas', 'salada',
  'acompanhamentos', 'acompanhamento', 'guarnicoes', 'guarnicao',
  'sobremesas', 'sobremesa', 'doces', 'bebidas', 'bebida', 'sucos', 'suco',
  'refrigerantes', 'cervejas', 'vinhos', 'drinks', 'drinques', 'coqueteis',
  'cafes', 'cafe', 'cafeteria', 'cafe da manha', 'almoco', 'jantar', 'ceia',
  'sopas', 'sopa', 'caldos', 'combos', 'promocoes', 'kids', 'infantil',
  'vegetariano', 'vegetarianos', 'vegano', 'veganos', 'opcao vegetariana',
  'opcao vegana', 'prato base', 'proteina', 'proteinas', 'molhos',
  'adicionais', 'extras', 'pasteis', 'salgados', 'tapiocas', 'crepes',
  'acai', 'sorvetes', 'sushi', 'sashimi', 'temaki', 'especiais',
  'especial do dia', 'sugestao do chef', 'grelhados', 'churrasco',
  'espetos', 'omeletes', 'marmitas', 'marmitex', 'refeicoes', 'fruta',
  'frutas', 'paes', 'tortas', 'bolos', 'porcao', 'bebidas quentes',
  'bebidas geladas', 'opcao', 'opcoes',
};

const _weekdayIndex = {
  'segunda': 1, 'terca': 2, 'quarta': 3, 'quinta': 4,
  'sexta': 5, 'sabado': 6, 'domingo': 7,
};

const _monthIndex = {
  'janeiro': 1, 'fevereiro': 2, 'marco': 3, 'abril': 4, 'maio': 5,
  'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9, 'outubro': 10,
  'novembro': 11, 'dezembro': 12,
};

// "R$ 32,90", "32,90", "1.250,00", "R$ 25", "R$ 25.90"
final _price = RegExp(
  r'R\$\s?(\d{1,3}(?:\.\d{3})+|\d+)(?:[.,](\d{1,2}))?(?!\d)'
  r'|(?<![\d/:])(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})(?![\d/])',
);
// "32.90" sem cifrão só vale como preço no fim da linha.
final _trailingDotPrice = RegExp(r'(?<![\d/:.,])(\d{1,4})\.(\d{2})\s*$');

final _unavailable = RegExp(
  r'\(?\b(esgotad[oa]s?|indispon[ií]ve(l|is)|em falta|sold out)\b\)?',
  caseSensitive: false,
);

final _noise = RegExp(
  r'https?://|www\.|@|\b(cep|cnpj|whatsapp|instagram|facebook|tiktok|telefone|'
  r'fone|tel|todos os direitos|copyright|pol[ií]tica de privacidade|'
  r'termos de uso|cookies|hor[aá]rio|funcionamento|taxa de servi[cç]o|'
  r'couvert|fa[cç]a seu pedido|pe[cç]a (j[aá]|agora|pelo)|delivery|'
  r'entrar|cadastre-se|carrinho|endere[cç]o|imagens? (meramente )?ilustrativas?)\b'
  r'|\(?\d{2}\)?\s?9?\d{4}[-.\s]?\d{4}'
  r'|\b\d{1,2}\s?(h|hs|horas)\b|\b\d{1,2}[:h]\d{2}\b'
  r'|^(home|in[ií]cio|contato|sobre|sobre n[oó]s|menu|card[aá]pio|buscar|'
  r'pesquisar|login|sair|voltar|ver mais|saiba mais|compartilhar)$',
  caseSensitive: false,
);

final _address = RegExp(
  r'^(rua|r\.|av\.|avenida|travessa|rodovia|pra[cç]a|alameda)\s',
  caseSensitive: false,
);

// "10/11" ou "1/2/2026". Um "1/2" solto é meia porção, não uma data.
final _numericDate = RegExp(
  r'(?<![\d/])(?:(\d{2})/(\d{2})(?:/(\d{2,4}))?|(\d{1,2})/(\d{1,2})/(\d{2,4}))(?![\d/])',
);
final _writtenDate = RegExp(
  r'(?<!\d)(\d{1,2})\s+de\s+([a-zç]+)(?:\s+de\s+(\d{4}))?',
  caseSensitive: false,
);

final _leaders = RegExp(r'[\s.\-–—_·•…:|]+$');
final _bullet = RegExp(r'^\s*(?:[-–—•*·▪►>]+|\d{1,2}[.)])\s+');
final _labelValue = RegExp(r'^([^:]{2,40}):\s+(\S.*)$');
final _splitValue = RegExp(r'\s*(?:;|\s\|\s|\s/\s)\s*');

class _Price {
  _Price(this.value, this.start, this.end);
  final double value;
  final int start;
  final int end;
}

_Price? _findPrice(String line) {
  final m = _price.firstMatch(line);
  if (m != null) {
    final whole = (m.group(1) ?? m.group(3))!.replaceAll('.', '');
    final cents = m.group(2) ?? m.group(4) ?? '0';
    final value = double.parse('$whole.${cents.padRight(2, '0')}');
    if (value > 0 && value < 100000) return _Price(value, m.start, m.end);
  }
  final t = _trailingDotPrice.firstMatch(line);
  if (t != null) {
    final value = double.parse('${t.group(1)}.${t.group(2)}');
    if (value > 0) return _Price(value, t.start, t.end);
  }
  return null;
}

class _Line {
  _Line(this.text, this.heading) : folded = fold(text), price = _findPrice(text);

  final String text;
  final int heading;
  final String folded;
  final _Price? price;

  /// Texto da linha sem o preço e sem os pontos de ligação.
  late final String label = price == null
      ? text
      : text.substring(0, price!.start).replaceAll(_leaders, '').trim();

  bool get hasPrice => price != null;
  bool get priceOnly => hasPrice && _letters(label) < 2;
  int get words => folded.isEmpty ? 0 : folded.split(' ').length;
}

int _letters(String s) => s.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length;

int? _weekdayOf(String folded) {
  final m = RegExp(
    r'^(segunda|terca|quarta|quinta|sexta|sabado|domingo)( feira)?( \d{1,2} \d{1,2}( \d{2,4})?)?$',
  ).firstMatch(folded);
  return m == null ? null : _weekdayIndex[m.group(1)];
}

DateTime? _findDate(String text, DateTime now) {
  final n = _numericDate.firstMatch(text);
  if (n != null) {
    final d = int.parse((n.group(1) ?? n.group(4))!);
    final mo = int.parse((n.group(2) ?? n.group(5))!);
    final year = n.group(3) ?? n.group(6);
    var y = year == null ? now.year : int.parse(year);
    if (y < 100) y += 2000;
    if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12) return DateTime(y, mo, d);
  }
  final w = _writtenDate.firstMatch(text);
  if (w != null) {
    final mo = _monthIndex[fold(w.group(2)!)];
    final d = int.parse(w.group(1)!);
    if (mo != null && d >= 1 && d <= 31) {
      final y = w.group(3) == null ? now.year : int.parse(w.group(3)!);
      return DateTime(y, mo, d);
    }
  }
  return null;
}

bool _isNoise(_Line l) {
  if (_letters(l.text) < 2) return true;
  if (_noise.hasMatch(l.text) || _address.hasMatch(l.text)) return true;
  return false;
}

String _cleanName(String raw) {
  var s = raw.replaceFirst(_bullet, '').replaceAll(_leaders, '');
  s = s.replaceAll(_unavailable, '').replaceAll(RegExp(r'\(\s*\)'), '');
  return sentenceCase(collapseSpaces(s));
}

/// Interpreta linhas de texto como um cardápio, por regras. Nada é
/// inventado: o que não se parece com prato, preço ou categoria é ignorado,
/// e a disponibilidade só é confirmada quando o cardápio traz a data ou o
/// dia da semana de hoje.
ParsedMenu parseMenu(List<SourceLine> source, {DateTime? now}) {
  final today = now ?? DateTime.now();

  final lines = <_Line>[];
  for (final s in source) {
    final text = collapseSpaces(s.text);
    if (text.isNotEmpty) lines.add(_Line(text, s.heading));
  }
  if (lines.isEmpty) return const ParsedMenu(dishes: []);

  // Data de referência: a primeira encontrada, de preferência a de hoje.
  DateTime? referenceDate;
  for (final l in lines) {
    final d = _findDate(l.text, today);
    if (d == null) continue;
    referenceDate ??= d;
    if (sameDay(d, today)) {
      referenceDate = d;
      break;
    }
  }
  final datedToday = referenceDate != null && sameDay(referenceDate, today);

  final priced = lines.where((l) => l.hasPrice).length;
  final priceMode = priced >= 3 || (priced > 0 && priced / lines.length > 0.25);
  final capsRatio =
      lines.where((l) => isAllCaps(l.text)).length / lines.length;

  bool isKeywordCategory(_Line l) =>
      !l.hasPrice && _categoryWords.contains(l.folded);

  // "Guarnições do dia", "Opção 1" e "Cardápio de hoje" abrem seções de
  // comida; "Sobre nós" e "Trabalhe conosco", não.
  bool opensFoodSection(_Line l) =>
      l.folded.startsWith('cardapio') ||
      l.folded.startsWith('menu') ||
      _findDate(l.text, today) != null ||
      _categoryWords.any(
        (w) =>
            l.folded == w ||
            l.folded.startsWith('$w ') ||
            l.folded.endsWith(' $w') ||
            l.folded.contains(' $w '),
      );

  // Um título seguido de linha só com preço é nome de prato, não categoria.
  bool namesUpcomingPrice(int i) {
    for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
      final n = lines[j];
      if (n.priceOnly) return true;
      if (n.hasPrice || isKeywordCategory(n)) return false;
    }
    return false;
  }

  bool isCategory(int i) {
    final l = lines[i];
    if (l.hasPrice || l.words == 0 || l.words > 6) return false;
    if (isKeywordCategory(l)) return true;
    if (_isNoise(l) || _weekdayOf(l.folded) != null) return false;
    final looksLikeTitle =
        (l.heading >= 2) || (capsRatio < 0.4 && isAllCaps(l.text));
    if (!looksLikeTitle) return false;
    return priceMode ? !namesUpcomingPrice(i) : true;
  }

  final dishes = <ParsedDish>[];
  final seen = <String>{};
  var category = defaultCategory;
  int? section; // dia da semana da seção atual
  // Sem preços, só vale como prato o que está em uma seção reconhecível
  // (categoria de comida, dia da semana ou cardápio com data). Isso evita
  // tratar o texto comum de um site como se fosse cardápio.
  var trusted = referenceDate != null;
  final pending = <String>[];
  ParsedDish? last;

  Availability availabilityFor(String rawText) {
    if (_unavailable.hasMatch(rawText)) return Availability.unavailable;
    if (section != null) {
      return section == today.weekday
          ? Availability.confirmed
          : Availability.unknown;
    }
    return datedToday ? Availability.confirmed : Availability.unknown;
  }

  ParsedDish? add(String rawName, {double? price, String? description, String? raw}) {
    // Em cardápio semanal, só interessam os pratos da seção de hoje.
    if (section != null && section != today.weekday) return null;
    var name = _cleanName(rawName);
    String? desc = description;
    if (desc == null) {
      final cut = RegExp(r'\s[-–—]\s|:\s').firstMatch(name);
      if (cut != null && cut.start >= 3 && name.length - cut.end >= 3) {
        desc = name.substring(cut.end).trim();
        name = name.substring(0, cut.start).trim();
      }
    }
    if (_letters(name) < 2 || name.length > 90) return null;
    final key = fold(name);
    if (key.isEmpty || !seen.add(key)) return null;
    final dish = ParsedDish(
      name: name,
      category: category,
      description: desc == null || desc.isEmpty ? null : desc,
      price: price,
      availability: availabilityFor(raw ?? rawName),
    );
    dishes.add(dish);
    return dish;
  }

  void flushPendingAsDescription() {
    if (pending.isEmpty) return;
    final dish = last;
    if (dish != null && dish.description == null) {
      final text = pending.join(' ');
      if (text.length <= 220) dish.description = text;
    }
    pending.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];

    final day = _weekdayOf(l.folded);
    if (day != null) {
      flushPendingAsDescription();
      section = day;
      trusted = true;
      category = defaultCategory;
      last = null;
      continue;
    }

    // "Prato principal: Strogonoff de frango" ou "Segunda: Feijoada"
    final lv = l.hasPrice ? null : _labelValue.firstMatch(l.text);
    if (lv != null) {
      final labelFolded = fold(lv.group(1)!);
      final labelDay = _weekdayOf(labelFolded);
      final labelIsCategory = _categoryWords.contains(labelFolded);
      if (labelDay != null || labelIsCategory) {
        flushPendingAsDescription();
        final savedSection = section;
        final savedCategory = category;
        if (labelDay != null) {
          section = labelDay;
        } else {
          category = sentenceCase(collapseSpaces(lv.group(1)!));
        }
        for (final part in lv.group(2)!.split(_splitValue)) {
          if (part.trim().isEmpty) continue;
          final probe = _Line(part.trim(), 0);
          if (!_isNoise(probe)) last = add(part, raw: part) ?? last;
        }
        // Rótulo na mesma linha vale só para essa linha.
        if (labelDay != null) section = savedSection;
        if (labelIsCategory && labelDay == null) category = savedCategory;
        continue;
      }
    }

    if (isCategory(i)) {
      flushPendingAsDescription();
      category = sentenceCase(l.text.replaceAll(_leaders, ''));
      trusted = opensFoodSection(l);
      last = null;
      continue;
    }

    if (l.hasPrice) {
      if (!l.priceOnly) {
        flushPendingAsDescription();
        last = add(l.label, price: l.price!.value, raw: l.text) ?? last;
        continue;
      }
      // Linha só com o preço: o nome veio nas linhas anteriores.
      if (pending.isEmpty) continue;
      String name;
      String? description;
      if (pending.length == 1) {
        name = pending.first;
      } else if (pending.first.length <= pending.last.length) {
        name = pending.first;
        description = pending.sublist(1).join(' ');
      } else {
        // A primeira linha era a descrição do prato anterior.
        final previous = last;
        if (previous != null && previous.description == null) {
          previous.description = pending
              .sublist(0, pending.length - 1)
              .join(' ');
        }
        name = pending.last;
      }
      final raw = '${pending.join(' ')} ${l.text}';
      pending.clear();
      last = add(name, price: l.price!.value, description: description, raw: raw) ?? last;
      continue;
    }

    if (l.heading > 0 && !opensFoodSection(l)) trusted = false;
    if (_isNoise(l)) continue;

    if (priceMode) {
      if (pending.length < 3) pending.add(l.text);
      continue;
    }

    // Cardápio sem preços (comum em cardápio do dia): cada linha dentro de
    // uma categoria ou seção é um prato.
    if (!trusted || l.words > 14 || l.text.length > 90) continue;
    if (l.folded.startsWith('cardapio') || _findDate(l.text, today) != null) {
      continue;
    }
    last = add(l.text, raw: l.text) ?? last;
  }
  flushPendingAsDescription();

  return ParsedMenu(
    dishes: dishes.length > 400 ? dishes.sublist(0, 400) : dishes,
    referenceDate: referenceDate,
  );
}
