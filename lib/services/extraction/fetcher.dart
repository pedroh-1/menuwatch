import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Falha de leitura com uma explicação que pode ser mostrada ao usuário.
class ReadFailure implements Exception {
  const ReadFailure(
    this.message, {
    this.needsApp = false,
    this.transient = false,
  });

  final String message;

  /// A fonte só pode ser lida com o app aberto (precisa de navegador).
  final bool needsApp;

  /// Falha passageira (sem internet, site fora do ar). Não vira aviso.
  final bool transient;

  @override
  String toString() => message;
}

enum ContentKind { html, pdf, image }

class FetchedResource {
  const FetchedResource({
    required this.uri,
    required this.kind,
    required this.bytes,
    this.charset,
  });

  final Uri uri;
  final ContentKind kind;
  final Uint8List bytes;
  final String? charset;
}

const userAgent = 'MenuWatch/1.0 (Android; leitor de cardapios)';
const _timeout = Duration(seconds: 25);
const _maxBytes = 20 * 1024 * 1024;

/// Aceita o que o usuário colou e devolve um endereço http(s) válido.
Uri normalizeUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) throw const ReadFailure('Cole o link do cardápio.');
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.host.contains('.')) {
    throw const ReadFailure(
      'Esse texto não é um link válido. Um link começa com https:// e tem o '
      'endereço do site.',
    );
  }
  return _directDownload(uri);
}

/// Links de visualização do Google Drive viram links do arquivo em si.
Uri _directDownload(Uri uri) {
  if (uri.host == 'drive.google.com') {
    final m = RegExp(r'/file/d/([^/]+)').firstMatch(uri.path);
    final id = m?.group(1) ?? uri.queryParameters['id'];
    if (id != null) {
      return Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'id': id,
      });
    }
  }
  return uri;
}

bool isCanva(Uri uri) =>
    uri.host.endsWith('canva.com') ||
    uri.host.endsWith('canva.site') ||
    uri.host.endsWith('canva.me');

class Fetcher {
  Fetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _robots = <String, _Robots>{};

  void close() => _client.close();

  /// Falha se o robots.txt do site proíbe a leitura automática do endereço.
  Future<void> ensureAllowed(Uri uri) async {
    if (!await _allowed(uri)) {
      throw const ReadFailure(
        'O site não permite a leitura automática desta página (regra no '
        'robots.txt). O MenuWatch respeita essa restrição.',
      );
    }
  }

  Future<FetchedResource> fetch(Uri uri) async {
    await ensureAllowed(uri);

    final http.StreamedResponse response;
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll({
          'User-Agent': userAgent,
          'Accept': 'text/html,application/pdf,image/*;q=0.9,*/*;q=0.5',
          'Accept-Language': 'pt-BR,pt;q=0.9',
          'Cache-Control': 'no-cache',
        });
      response = await _client.send(request).timeout(_timeout);
    } on TimeoutException {
      throw const ReadFailure(
        'O site demorou demais para responder.',
        transient: true,
      );
    } on SocketException {
      throw const ReadFailure(
        'Não foi possível conectar. Confira a internet e se o endereço existe.',
        transient: true,
      );
    } on HandshakeException {
      throw const ReadFailure(
        'O site tem um problema no certificado de segurança e não pôde ser '
        'aberto.',
      );
    } on http.ClientException {
      throw const ReadFailure(
        'Não foi possível conectar. Confira a internet e se o endereço existe.',
        transient: true,
      );
    }

    final status = response.statusCode;
    if (status == 401 || status == 403) {
      throw ReadFailure(
        'O site exige login ou bloqueou o acesso (erro $status). O MenuWatch '
        'não contorna esse tipo de proteção.',
      );
    }
    if (status == 404 || status == 410) {
      throw ReadFailure('Página não encontrada (erro $status). Confira o link.');
    }
    if (status == 429) {
      throw const ReadFailure(
        'O site pediu para reduzir os acessos. Tente de novo mais tarde.',
        transient: true,
      );
    }
    if (status >= 500) {
      throw ReadFailure(
        'O site está com problemas no momento (erro $status).',
        transient: true,
      );
    }
    if (status >= 400) {
      throw ReadFailure('O site recusou o acesso (erro $status).');
    }

    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream.timeout(_timeout)) {
        builder.add(chunk);
        if (builder.length > _maxBytes) {
          throw const ReadFailure(
            'O arquivo é grande demais para ser lido no celular (mais de 20 MB).',
          );
        }
      }
    } on TimeoutException {
      throw const ReadFailure(
        'O site parou de responder durante a leitura.',
        transient: true,
      );
    }
    final bytes = builder.takeBytes();
    final type = response.headers['content-type']?.toLowerCase() ?? '';
    final finalUri = response.request?.url ?? uri;

    return FetchedResource(
      uri: finalUri,
      kind: _detectKind(type, bytes, finalUri),
      bytes: bytes,
      charset: RegExp(r'charset=([\w-]+)').firstMatch(type)?.group(1),
    );
  }

  ContentKind _detectKind(String type, Uint8List b, Uri uri) {
    bool starts(List<int> magic) {
      if (b.length < magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (b[i] != magic[i]) return false;
      }
      return true;
    }

    if (starts([0x25, 0x50, 0x44, 0x46])) return ContentKind.pdf; // %PDF
    if (starts([0x89, 0x50, 0x4E, 0x47]) || // PNG
        starts([0xFF, 0xD8, 0xFF]) || // JPEG
        starts([0x47, 0x49, 0x46, 0x38]) || // GIF
        (starts([0x52, 0x49, 0x46, 0x46]) && b.length > 12 && b[8] == 0x57)) {
      return ContentKind.image; // inclui WEBP
    }
    if (type.contains('pdf')) return ContentKind.pdf;
    if (type.startsWith('image/')) {
      if (type.contains('svg')) {
        throw const ReadFailure(
          'O link aponta para um desenho vetorial (SVG), formato que o app '
          'não lê.',
        );
      }
      return ContentKind.image;
    }
    if (type.contains('html') || type.contains('text/') || type.isEmpty) {
      return ContentKind.html;
    }
    throw ReadFailure(
      'O link aponta para um tipo de arquivo que o app não lê ($type). '
      'São aceitos sites, PDFs e imagens.',
    );
  }

  Future<bool> _allowed(Uri uri) async {
    final origin = '${uri.scheme}://${uri.authority}';
    final rules = _robots[origin] ??= await _loadRobots(origin);
    final path = uri.path.isEmpty ? '/' : uri.path;
    return rules.allows(uri.hasQuery ? '$path?${uri.query}' : path);
  }

  Future<_Robots> _loadRobots(String origin) async {
    try {
      final res = await _client
          .get(
            Uri.parse('$origin/robots.txt'),
            headers: {'User-Agent': userAgent},
          )
          .timeout(const Duration(seconds: 8));
      final isText =
          res.statusCode == 200 &&
          !(res.headers['content-type'] ?? '').contains('html');
      if (isText) return _Robots.parse(res.body);
    } catch (_) {
      // Sem robots.txt acessível, não há restrição declarada.
    }
    return const _Robots([]);
  }
}

class _Rule {
  _Rule(this.path, this.allow)
    : _pattern = RegExp(
        '^${path.split('*').map((part) {
          final anchored = part.endsWith(r'$');
          final text = anchored ? part.substring(0, part.length - 1) : part;
          return RegExp.escape(text) + (anchored ? r'$' : '');
        }).join('.*')}',
      );

  final String path;
  final bool allow;
  final RegExp _pattern;

  bool matches(String target) => _pattern.hasMatch(target);
}

/// Leitura mínima do robots.txt: regras do grupo "menuwatch" ou, na falta
/// dele, do grupo "*". Vence a regra de caminho mais longo.
class _Robots {
  const _Robots(this.rules);

  final List<_Rule> rules;

  static _Robots parse(String body) {
    final groups = <String, List<_Rule>>{};
    var agents = <String>[];
    var lastWasAgent = false;
    for (final raw in body.split('\n')) {
      final line = raw.split('#').first.trim();
      final sep = line.indexOf(':');
      if (sep <= 0) continue;
      final key = line.substring(0, sep).trim().toLowerCase();
      final value = line.substring(sep + 1).trim();
      if (key == 'user-agent') {
        if (!lastWasAgent) agents = [];
        agents.add(value.toLowerCase());
        lastWasAgent = true;
        continue;
      }
      lastWasAgent = false;
      if ((key == 'disallow' || key == 'allow') && value.isNotEmpty) {
        for (final a in agents) {
          groups.putIfAbsent(a, () => []).add(_Rule(value, key == 'allow'));
        }
      }
    }
    return _Robots(groups['menuwatch'] ?? groups['*'] ?? const []);
  }

  /// [target] é o caminho com a query, como em "/cardapio?dia=1".
  bool allows(String target) {
    _Rule? best;
    for (final r in rules) {
      if (!r.matches(target)) continue;
      if (best == null ||
          r.path.length > best.path.length ||
          (r.path.length == best.path.length && r.allow)) {
        best = r;
      }
    }
    return best?.allow ?? true;
  }
}

/// Exposto para testes.
bool robotsAllows(String robotsTxt, String target) =>
    _Robots.parse(robotsTxt).allows(target);
