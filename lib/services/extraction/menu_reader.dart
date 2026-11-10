import '../../models/models.dart';
import '../../utils/text_utils.dart';
import '../parser/menu_parser.dart';
import 'fetcher.dart';
import 'html_extractor.dart';
import 'ocr.dart';
import 'pdf_extractor.dart';

/// Etapas da leitura, para mostrar o andamento ao usuário.
enum ReadStage {
  fetching('Abrindo o link'),
  rendering('Carregando a página no navegador'),
  ocr('Lendo o texto das imagens'),
  interpreting('Identificando os pratos');

  const ReadStage(this.label);
  final String label;
}

class ReadResult {
  const ReadResult({
    required this.parsed,
    required this.sourceType,
    required this.url,
    this.suggestedName,
  });

  final ParsedMenu parsed;
  final SourceType sourceType;

  /// Endereço normalizado, que é o que fica guardado.
  final String url;
  final String? suggestedName;
}

typedef RenderPage = Future<String> Function(Uri uri);

/// Lê um link de cardápio, do endereço até a lista de pratos.
///
/// A mesma fonte é sempre lida pelo mesmo caminho: um cardápio que precisou
/// de navegador nunca é comparado com uma leitura feita sem ele, porque isso
/// faria pratos "sumirem" sem terem saído do cardápio.
class MenuReader {
  MenuReader({Fetcher? fetcher, OcrService? ocr, this.render})
    : _fetcher = fetcher ?? Fetcher(),
      _ocr = ocr ?? OcrService();

  final Fetcher _fetcher;
  final OcrService _ocr;

  /// Navegador embutido. Nulo na verificação em segundo plano.
  final RenderPage? render;

  static const _enough = 3;
  static const _maxImages = 4;

  Future<void> close() async {
    _fetcher.close();
    await _ocr.close();
  }

  Future<ReadResult> read(
    String url, {
    SourceType? hint,
    void Function(ReadStage stage)? onStage,
  }) async {
    final uri = normalizeUrl(url);
    final browserType = isCanva(uri) ? SourceType.canva : SourceType.dynamicPage;
    void stage(ReadStage s) => onStage?.call(s);

    ReadResult result(ParsedMenu parsed, SourceType type, String? name) =>
        ReadResult(
          parsed: parsed,
          sourceType: type,
          url: uri.toString(),
          suggestedName: name ?? _nameFromHost(uri),
        );

    Future<ParsedMenu?> fromImages(Iterable<Uri> images) async {
      final lines = <SourceLine>[];
      var announced = false;
      for (final image in images.take(_maxImages)) {
        try {
          final res = await _fetcher.fetch(image);
          if (res.kind != ContentKind.image) continue;
          if (!announced) {
            stage(ReadStage.ocr);
            announced = true;
          }
          lines.addAll(await _ocr.readBytes(res.bytes));
        } on ReadFailure {
          // Uma imagem que não abre não impede a leitura das outras.
        }
      }
      if (lines.isEmpty) return null;
      final parsed = parseMenu(lines);
      return parsed.dishes.length >= _enough ? parsed : null;
    }

    Future<ReadResult> viaBrowser({
      HtmlContent? staticContent,
      ParsedMenu? staticParsed,
    }) async {
      final open = render;
      if (open == null) {
        throw const ReadFailure(
          'Este cardápio só pode ser lido com o app aberto, porque a página '
          'precisa de um navegador para montar o conteúdo.',
          needsApp: true,
        );
      }
      stage(ReadStage.rendering);
      final rendered = extractHtml(await open(uri), uri);
      stage(ReadStage.interpreting);
      final parsed = _interpret(rendered);
      final name = rendered.siteName ?? staticContent?.siteName;
      if (parsed.dishes.length >= _enough) {
        return result(parsed, browserType, name);
      }

      final known = staticContent?.imageUrls.toSet() ?? const <Uri>{};
      if (staticContent != null && hint != SourceType.image) {
        final fromStatic = await fromImages(staticContent.imageUrls);
        if (fromStatic != null) {
          return result(fromStatic, SourceType.image, name);
        }
      }
      final fromRendered = await fromImages(
        rendered.imageUrls.where((u) => !known.contains(u)),
      );
      if (fromRendered != null) return result(fromRendered, browserType, name);

      // O navegador só vira o caminho oficial se trouxer mais do que a
      // leitura simples; senão o cardápio continua verificável em segundo
      // plano.
      final staticCount = staticParsed?.dishes.length ?? 0;
      if (parsed.dishes.length > staticCount) {
        return result(parsed, browserType, name);
      }
      if (staticParsed != null && staticCount > 0) {
        return result(staticParsed, SourceType.html, name);
      }
      throw const ReadFailure(
        'A página abriu, mas o app não encontrou pratos nela. Isso acontece '
        'quando o cardápio está em um formato muito livre ou atrás de um '
        'botão. Tente o link direto do cardápio (a página, o PDF ou a '
        'imagem).',
      );
    }

    if (hint != null && hint.needsBrowser) {
      stage(ReadStage.fetching);
      await _fetcher.ensureAllowed(uri);
      return viaBrowser();
    }

    stage(ReadStage.fetching);
    final res = await _fetcher.fetch(uri);

    switch (res.kind) {
      case ContentKind.pdf:
        final lines = await extractPdf(
          res.bytes,
          _ocr,
          onOcrStart: () => stage(ReadStage.ocr),
        );
        stage(ReadStage.interpreting);
        final parsed = parseMenu(lines);
        if (parsed.dishes.isEmpty) {
          throw ReadFailure(
            lines.isEmpty
                ? 'O PDF abriu, mas não tem texto que o app consiga ler.'
                : 'O PDF abriu, mas o app não reconheceu pratos no texto dele.',
          );
        }
        return result(parsed, SourceType.pdf, null);

      case ContentKind.image:
        stage(ReadStage.ocr);
        final lines = await _ocr.readBytes(res.bytes);
        stage(ReadStage.interpreting);
        final parsed = parseMenu(lines);
        if (parsed.dishes.isEmpty) {
          throw ReadFailure(
            lines.isEmpty
                ? 'A imagem abriu, mas o app não encontrou texto nela.'
                : 'O app leu o texto da imagem, mas não reconheceu pratos '
                      'nele.',
          );
        }
        return result(parsed, SourceType.image, null);

      case ContentKind.html:
        stage(ReadStage.interpreting);
        final content = extractHtml(decodeHtml(res.bytes, res.charset), res.uri);
        final parsed = _interpret(content);
        if (parsed.dishes.length >= _enough) {
          return result(parsed, SourceType.html, content.siteName);
        }
        // Site que já era lido pela imagem continua sendo lido pela imagem.
        if (hint == SourceType.image || render == null) {
          final fromStatic = await fromImages(content.imageUrls);
          if (fromStatic != null) {
            return result(fromStatic, SourceType.image, content.siteName);
          }
        }
        if (render == null &&
            hint == SourceType.html &&
            parsed.dishes.isNotEmpty) {
          return result(parsed, SourceType.html, content.siteName);
        }
        return viaBrowser(staticContent: content, staticParsed: parsed);
    }
  }

  ParsedMenu _interpret(HtmlContent content) {
    final fromText = parseMenu(content.lines);
    if (content.structured.length < _enough) return fromText;
    final seen = <String>{};
    return ParsedMenu(
      dishes: [
        for (final d in content.structured)
          if (seen.add(fold(d.name))) d,
      ],
      referenceDate: fromText.referenceDate,
    );
  }

  String _nameFromHost(Uri uri) {
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final first = host.split('.').first;
    if (first.isEmpty) return host;
    return first[0].toUpperCase() + first.substring(1);
  }
}
