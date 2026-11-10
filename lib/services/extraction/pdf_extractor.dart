import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../parser/menu_parser.dart';
import 'bmp.dart';
import 'fetcher.dart';
import 'ocr.dart';

const _maxTextPages = 15;
const _maxOcrPages = 6;

/// Extrai o texto de um PDF. Quando o PDF é só imagem (escaneado ou
/// exportado como figura), as páginas são renderizadas e lidas por OCR.
Future<List<SourceLine>> extractPdf(
  Uint8List bytes,
  OcrService ocr, {
  void Function()? onOcrStart,
}) async {
  await pdfrxFlutterInitialize();

  final PdfDocument doc;
  try {
    doc = await PdfDocument.openData(bytes);
  } on PdfPasswordException {
    throw const ReadFailure(
      'O PDF é protegido por senha e não pode ser lido.',
    );
  } catch (_) {
    throw const ReadFailure(
      'O arquivo PDF está danificado ou em um formato que o app não abre.',
    );
  }

  try {
    final lines = <SourceLine>[];
    var letters = 0;
    for (final page in doc.pages.take(_maxTextPages)) {
      final text = (await page.loadText())?.fullText ?? '';
      for (final line in text.split(RegExp(r'[\r\n]+'))) {
        if (line.trim().isEmpty) continue;
        lines.add(SourceLine(line));
        letters += line.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length;
      }
    }
    if (letters >= 40) return lines;

    onOcrStart?.call();
    final scanned = <SourceLine>[];
    for (final page in doc.pages.take(_maxOcrPages)) {
      final scale = 1600 / page.width;
      final width = (page.width * scale).round();
      final height = (page.height * scale).round();
      final rendered = await page.render(
        width: width,
        height: height,
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xffffffff,
      );
      if (rendered == null) continue;
      try {
        scanned.addAll(
          await ocr.readBytes(
            bmpFromBgra(rendered.pixels, rendered.width, rendered.height),
          ),
        );
      } finally {
        rendered.dispose();
      }
    }
    return scanned;
  } finally {
    await doc.dispose();
  }
}
