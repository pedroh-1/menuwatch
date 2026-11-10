import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../parser/menu_parser.dart';

/// Um trecho de texto reconhecido na imagem e onde ele está.
class OcrPiece {
  const OcrPiece(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left, top, right, bottom;

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

final _endsWithPrice = RegExp(r'(R\$\s?\d+|\d,\d{2})\s*$');
final _startsWithPrice = RegExp(r'^\s*(R\$|\d+[.,]\d{2})');

/// Junta os trechos que estão na mesma altura em uma linha só, para que o
/// nome do prato e o preço (que o OCR devolve separados) fiquem juntos.
/// Em cardápios de duas colunas, um espaço largo ou um preço encerram a linha.
List<SourceLine> mergeOcrRows(List<OcrPiece> pieces) {
  final sorted = [...pieces]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrPiece>>[];
  for (final p in sorted) {
    if (rows.isNotEmpty) {
      final row = rows.last;
      final rowCenter =
          row.map((r) => r.centerY).reduce((a, b) => a + b) / row.length;
      final rowHeight =
          row.map((r) => r.height).reduce((a, b) => a + b) / row.length;
      final tolerance = 0.55 * (p.height < rowHeight ? p.height : rowHeight);
      if ((p.centerY - rowCenter).abs() <= tolerance) {
        row.add(p);
        continue;
      }
    }
    rows.add([p]);
  }

  final lines = <SourceLine>[];
  for (final row in rows) {
    row.sort((a, b) => a.left.compareTo(b.left));
    final current = <String>[];
    for (var i = 0; i < row.length; i++) {
      final p = row[i];
      if (current.isNotEmpty) {
        final gap = p.left - row[i - 1].right;
        final wideGap = gap > 3 * p.height;
        if (wideGap && !_startsWithPrice.hasMatch(p.text)) {
          lines.add(SourceLine(current.join(' ')));
          current.clear();
        }
      }
      current.add(p.text.trim());
      if (_endsWithPrice.hasMatch(p.text) && i < row.length - 1) {
        lines.add(SourceLine(current.join(' ')));
        current.clear();
      }
    }
    if (current.isNotEmpty) lines.add(SourceLine(current.join(' ')));
  }
  return lines;
}

/// Reconhecimento de texto em imagens, feito no próprio aparelho.
class OcrService {
  TextRecognizer? _recognizer;

  Future<List<SourceLine>> readFile(String path) async {
    final recognizer = _recognizer ??= TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    final pieces = [
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrPiece(
            line.text,
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.right,
            line.boundingBox.bottom,
          ),
    ];
    return mergeOcrRows(pieces);
  }

  Future<List<SourceLine>> readBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.img',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      return await readFile(file.path);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> close() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
