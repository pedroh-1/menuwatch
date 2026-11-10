import 'dart:typed_data';

/// Monta um arquivo BMP de 24 bits a partir de pixels BGRA. É o caminho
/// mais simples para entregar uma página renderizada ao OCR sem depender
/// de codificadores que só existem com a interface gráfica ativa.
Uint8List bmpFromBgra(Uint8List bgra, int width, int height) {
  const headerSize = 54;
  final rowSize = (width * 3 + 3) & ~3;
  final dataSize = rowSize * height;
  final out = Uint8List(headerSize + dataSize);
  final header = ByteData.sublistView(out, 0, headerSize);
  out[0] = 0x42; // B
  out[1] = 0x4D; // M
  header.setUint32(2, out.length, Endian.little);
  header.setUint32(10, headerSize, Endian.little);
  header.setUint32(14, 40, Endian.little);
  header.setInt32(18, width, Endian.little);
  header.setInt32(22, height, Endian.little); // positivo: de baixo para cima
  header.setUint16(26, 1, Endian.little);
  header.setUint16(28, 24, Endian.little);
  header.setUint32(34, dataSize, Endian.little);
  header.setInt32(38, 2835, Endian.little);
  header.setInt32(42, 2835, Endian.little);

  for (var y = 0; y < height; y++) {
    var src = (height - 1 - y) * width * 4;
    var dst = headerSize + y * rowSize;
    for (var x = 0; x < width; x++) {
      out[dst++] = bgra[src];
      out[dst++] = bgra[src + 1];
      out[dst++] = bgra[src + 2];
      src += 4;
    }
  }
  return out;
}
