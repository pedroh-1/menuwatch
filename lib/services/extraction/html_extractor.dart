import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../../models/models.dart';
import '../../utils/text_utils.dart';
import '../parser/menu_parser.dart';

class HtmlContent {
  const HtmlContent({
    required this.lines,
    required this.imageUrls,
    required this.structured,
    this.siteName,
  });

  /// Texto visível da página, na ordem de leitura.
  final List<SourceLine> lines;

  /// Imagens grandes da página, candidatas a conter o cardápio.
  final List<Uri> imageUrls;

  /// Pratos declarados pela própria página em dados estruturados
  /// (schema.org), quando existem.
  final List<ParsedDish> structured;

  final String? siteName;

  int get textLength => lines.fold(0, (sum, l) => sum + l.text.length);
}

String decodeHtml(Uint8List bytes, String? charset) {
  var cs = charset?.toLowerCase();
  if (cs == null) {
    final head = latin1.decode(
      bytes.sublist(0, bytes.length < 2048 ? bytes.length : 2048),
    );
    cs = RegExp(
      r'charset=["\x27]?([\w-]+)',
      caseSensitive: false,
    ).firstMatch(head)?.group(1)?.toLowerCase();
  }
  if (cs == 'iso-8859-1' || cs == 'latin1' || cs == 'windows-1252') {
    return latin1.decode(bytes);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

const _skip = {
  'script', 'style', 'noscript', 'svg', 'nav', 'footer', 'form', 'iframe',
  'template', 'head', 'select', 'button', 'canvas', 'video', 'audio',
};

const _block = {
  'div', 'p', 'li', 'ul', 'ol', 'section', 'article', 'tr', 'table', 'tbody',
  'thead', 'dd', 'dt', 'dl', 'header', 'main', 'aside', 'blockquote',
  'figure', 'figcaption', 'hr', 'address', 'details', 'summary', 'br',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'caption',
};

const _weekdayWords = [
  'segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo',
];

bool _isWeekday(String text) {
  final f = fold(text);
  return _weekdayWords.any((w) => f == w || f.startsWith('$w '));
}

HtmlContent extractHtml(String source, Uri base) {
  final doc = html.parse(source);

  String? meta(String property) {
    final el = doc.querySelector(
      'meta[property="$property"], meta[name="$property"]',
    );
    final v = el?.attributes['content']?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  final siteName = meta('og:site_name') ?? _cleanTitle(doc.querySelector('title')?.text);

  final structured = <ParsedDish>[];
  for (final s in doc.querySelectorAll('script[type="application/ld+json"]')) {
    try {
      _collectJsonLd(jsonDecode(s.text), defaultCategory, structured);
    } catch (_) {
      // JSON-LD inválido não impede a leitura do restante da página.
    }
  }

  final images = <Uri>[];
  for (final img in doc.querySelectorAll('img')) {
    final src =
        img.attributes['src'] ??
        img.attributes['data-src'] ??
        img.attributes['data-lazy-src'];
    if (src == null || src.startsWith('data:')) continue;
    final w = int.tryParse(img.attributes['width'] ?? '');
    final h = int.tryParse(img.attributes['height'] ?? '');
    if ((w != null && w < 300) || (h != null && h < 300)) continue;
    final hint = '${src.toLowerCase()} ${(img.attributes['alt'] ?? '').toLowerCase()} '
        '${img.className.toLowerCase()}';
    if (RegExp(r'logo|icon|sprite|avatar|banner|favicon|\.svg|\.gif').hasMatch(hint)) {
      continue;
    }
    final uri = base.resolve(src);
    if (uri.scheme.startsWith('http') && !images.contains(uri)) images.add(uri);
  }

  final lines = <SourceLine>[];
  final current = StringBuffer();
  var heading = 0;

  void flush() {
    final text = collapseSpaces(current.toString());
    current.clear();
    if (text.isNotEmpty) lines.add(SourceLine(text, heading: heading));
  }

  void walk(Node node) {
    if (node is Text) {
      current.write(node.text);
      return;
    }
    if (node is! Element) return;
    final tag = node.localName ?? '';
    if (_skip.contains(tag)) return;
    if (node.attributes['aria-hidden'] == 'true' ||
        node.attributes.containsKey('hidden')) {
      return;
    }
    if (tag == 'table' && _walkWeeklyTable(node, lines, flush)) return;

    final isBlock = _block.contains(tag);
    final level = RegExp(r'^h([1-6])$').firstMatch(tag)?.group(1);
    if (isBlock) flush();
    final outer = heading;
    if (level != null) heading = int.parse(level);
    for (final child in node.nodes) {
      walk(child);
    }
    if (isBlock) {
      flush();
    } else {
      current.write(' ');
    }
    heading = outer;
  }

  final body = doc.body;
  if (body != null) walk(body);
  flush();

  return HtmlContent(
    lines: lines,
    imageUrls: images.length > 6 ? images.sublist(0, 6) : images,
    structured: structured,
    siteName: siteName,
  );
}

/// Tabelas de cardápio semanal têm os dias em uma linha ou em uma coluna.
/// Elas são reescritas como seções ("Segunda", pratos, "Terça", pratos…),
/// que é a forma que o interpretador entende.
bool _walkWeeklyTable(Element table, List<SourceLine> out, void Function() flush) {
  final rows = [
    for (final tr in table.querySelectorAll('tr'))
      [
        for (final c in tr.children.where(
          (c) => c.localName == 'td' || c.localName == 'th',
        ))
          c,
      ],
  ].where((r) => r.isNotEmpty).toList();
  if (rows.length < 2) return false;

  List<String> cellLines(Element cell) => cell.innerHtml
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>|</div>', caseSensitive: false), '\n')
      .split('\n')
      .map((s) => collapseSpaces(html.parseFragment(s).text ?? ''))
      .where((s) => s.isNotEmpty)
      .toList();

  String cellText(Element cell) => collapseSpaces(cell.text);

  final header = rows.first.map(cellText).toList();
  final dayColumns = [
    for (var i = 0; i < header.length; i++)
      if (_isWeekday(header[i])) i,
  ];

  if (dayColumns.length >= 3) {
    flush();
    for (final col in dayColumns) {
      out.add(SourceLine(header[col]));
      for (final row in rows.skip(1)) {
        if (col >= row.length) continue;
        final label = dayColumns.first > 0 ? cellText(row.first) : '';
        if (label.isNotEmpty) out.add(SourceLine(label, heading: 3));
        for (final line in cellLines(row[col])) {
          out.add(SourceLine(line));
        }
      }
    }
    return true;
  }

  final dayRows = rows.where((r) => _isWeekday(cellText(r.first))).length;
  if (dayRows >= 3) {
    flush();
    final headerIsLabels = !_isWeekday(header.first);
    for (final row in rows) {
      if (!_isWeekday(cellText(row.first))) continue;
      out.add(SourceLine(cellText(row.first)));
      for (var i = 1; i < row.length; i++) {
        if (headerIsLabels && i < header.length && header[i].isNotEmpty) {
          out.add(SourceLine(header[i], heading: 3));
        }
        for (final line in cellLines(row[i])) {
          out.add(SourceLine(line));
        }
      }
    }
    return true;
  }
  return false;
}

String? _cleanTitle(String? title) {
  if (title == null) return null;
  final parts = title
      .split(RegExp(r'\s[|\-–—•]\s'))
      .map(collapseSpaces)
      .where((p) => p.isNotEmpty && !RegExp(r'^(card[aá]pio|menu|home|in[ií]cio)( digital| online)?$', caseSensitive: false).hasMatch(p))
      .toList();
  if (parts.isEmpty) return null;
  final name = parts.first.replaceFirst(
    RegExp(r'^(card[aá]pio|menu)( digital| online)?( d[oae])?\s+', caseSensitive: false),
    '',
  );
  return name.length > 60 ? name.substring(0, 60).trim() : name;
}

void _collectJsonLd(Object? node, String category, List<ParsedDish> out) {
  if (node is List) {
    for (final n in node) {
      _collectJsonLd(n, category, out);
    }
    return;
  }
  if (node is! Map) return;
  final type = node['@type'];
  final types = type is List ? type.map((t) => '$t').toList() : ['$type'];
  var current = category;

  if (types.contains('MenuSection') && node['name'] is String) {
    current = sentenceCase(collapseSpaces(node['name'] as String));
  }
  if (types.contains('MenuItem') && node['name'] is String) {
    final offers = node['offers'];
    final offer = offers is List && offers.isNotEmpty ? offers.first : offers;
    double? price;
    Availability availability = Availability.unknown;
    if (offer is Map) {
      final raw = '${offer['price'] ?? ''}'.replaceAll(',', '.');
      price = double.tryParse(raw);
      if ('${offer['availability'] ?? ''}'.contains('OutOfStock')) {
        availability = Availability.unavailable;
      }
    }
    final description = node['description'];
    out.add(
      ParsedDish(
        name: sentenceCase(collapseSpaces(node['name'] as String)),
        category: current,
        description: description is String && description.trim().isNotEmpty
            ? collapseSpaces(description)
            : null,
        price: price != null && price > 0 ? price : null,
        availability: availability,
      ),
    );
    return;
  }
  for (final value in node.values) {
    if (value is Map || value is List) _collectJsonLd(value, current, out);
  }
}
