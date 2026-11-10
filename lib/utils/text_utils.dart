const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

final _spaces = RegExp(r'\s+');
final _nonAlnum = RegExp(r'[^a-z0-9 ]');

String collapseSpaces(String s) => s.replaceAll(_spaces, ' ').trim();

/// Minúsculas, sem acentos e sem pontuação. Usado para comparar nomes de
/// pratos entre duas leituras do mesmo cardápio.
String fold(String s) {
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    b.write(_accents[ch] ?? ch);
  }
  return collapseSpaces(b.toString().replaceAll(_nonAlnum, ' '));
}

bool isAllCaps(String s) {
  final letters = s.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
  return letters.length >= 3 && letters == letters.toUpperCase();
}

/// "STROGONOFF DE FRANGO" vira "Strogonoff de frango". Textos que já usam
/// minúsculas são mantidos como estão.
String sentenceCase(String s) {
  if (!isAllCaps(s)) return s;
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String formatPrice(double value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final digits = fixed[0];
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  return 'R\$ $b,${fixed[1]}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _weekdays = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
const _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "agora", "há 12 min", "hoje às 09:30", "ontem às 18:02", "3 de nov".
String relativeTime(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(when);
  final time = '${_two(when.hour)}:${_two(when.minute)}';
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (sameDay(n, when)) return 'hoje às $time';
  if (sameDay(n.subtract(const Duration(days: 1)), when)) return 'ontem às $time';
  if (diff.inDays < 7) return '${_weekdays[when.weekday - 1]} às $time';
  return '${when.day} de ${_months[when.month - 1]}';
}

String shortDate(DateTime d) => '${d.day} de ${_months[d.month - 1]}';

String frequencyLabel(int minutes) {
  if (minutes < 60) return 'A cada $minutes minutos';
  final h = minutes ~/ 60;
  if (h == 1) return 'A cada hora';
  if (h == 24) return 'Uma vez por dia';
  return 'A cada $h horas';
}

String clockTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Hoje", "Ontem" ou "8 de nov", para agrupar listas por dia.
String dayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (sameDay(n, d)) return 'Hoje';
  if (sameDay(n.subtract(const Duration(days: 1)), d)) return 'Ontem';
  return d.year == n.year ? shortDate(d) : '${shortDate(d)} de ${d.year}';
}

String greeting(DateTime now) {
  if (now.hour < 5) return 'Boa noite';
  if (now.hour < 12) return 'Bom dia';
  if (now.hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

String plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

/// "restaurante.com.br" a partir do endereço completo.
String hostOf(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  return host.startsWith('www.') ? host.substring(4) : host;
}
