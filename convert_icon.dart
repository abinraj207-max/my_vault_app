import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  final pngFile = File('assets/image/iconn.png');
  if (!pngFile.existsSync()) {
    print('Error: assets/image/iconn.png does not exist.');
    return;
  }

  print('Reading PNG icon...');
  final pngBytes = pngFile.readAsBytesSync();
  final decodedImage = img.decodeImage(pngBytes);
  if (decodedImage == null) {
    print('Error: Failed to decode PNG image.');
    return;
  }

  // 48x48 is the standard and most compatible size for Inno Setup compiler icon packaging.
  const int size = 48;
  print('Resizing icon to ${size}x${size}...');
  final resized = img.copyResize(decodedImage, width: size, height: size);

  print('Encoding to uncompressed 32-bit BGRA BMP-based ICO...');
  final builder = BytesBuilder();

  // 1. ICO Header (6 bytes)
  builder.add([0, 0]); // Reserved
  builder.add([1, 0]); // Type: 1 (Icon)
  builder.add([1, 0]); // Count of images: 1

  // 2. Icon Directory Entry (16 bytes)
  builder.add([size]); // Width
  builder.add([size]); // Height
  builder.add([0]);    // Color count (0 = no palette)
  builder.add([0]);    // Reserved
  builder.add([1, 0]); // Planes (1)
  builder.add([32, 0]); // Bits per pixel (32)
  
  // Image data size = 40 (BitmapInfoHeader) + (size * size * 4) + (size * size / 8)
  final int xorSize = size * size * 4;
  final int andSize = (size * size) ~/ 8;
  final int totalImageDataSize = 40 + xorSize + andSize;
  
  final sizeData = ByteData(4)..setUint32(0, totalImageDataSize, Endian.little);
  builder.add(sizeData.buffer.asUint8List());
  
  // Offset of image data is 22 (header + 1 entry)
  final offsetData = ByteData(4)..setUint32(0, 22, Endian.little);
  builder.add(offsetData.buffer.asUint8List());

  // 3. BitmapInfoHeader (40 bytes)
  final bih = ByteData(40);
  bih.setUint32(0, 40, Endian.little); // biSize
  bih.setInt32(4, size, Endian.little); // biWidth
  bih.setInt32(8, size * 2, Endian.little); // biHeight (must be double height for ICO)
  bih.setUint16(12, 1, Endian.little); // biPlanes
  bih.setUint16(14, 32, Endian.little); // biBitCount (32-bit BGRA)
  bih.setUint32(16, 0, Endian.little); // biCompression (0 = BI_RGB, uncompressed)
  bih.setUint32(20, xorSize + andSize, Endian.little); // biSizeImage
  bih.setInt32(24, 0, Endian.little); // biXPelsPerMeter
  bih.setInt32(28, 0, Endian.little); // biYPelsPerMeter
  bih.setUint32(32, 0, Endian.little); // biClrUsed
  bih.setUint32(36, 0, Endian.little); // biClrImportant
  builder.add(bih.buffer.asUint8List());

  // 4. XOR Pixel Data (BGRA format, bottom-to-top)
  final xorBytes = Uint8List(xorSize);
  int offset = 0;
  for (int y = size - 1; y >= 0; y--) {
    for (int x = 0; x < size; x++) {
      final pixel = resized.getPixel(x, y);
      
      // Extract color channels using package:image 4.x getters
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final a = pixel.a.toInt();

      xorBytes[offset++] = b; // Blue
      xorBytes[offset++] = g; // Green
      xorBytes[offset++] = r; // Red
      xorBytes[offset++] = a; // Alpha
    }
  }
  builder.add(xorBytes);

  // 5. AND Mask (1 bit per pixel, bottom-to-top)
  // Writing 0s means all pixels are processed, relying on the 32-bit Alpha channel for transparency.
  final andBytes = Uint8List(andSize);
  builder.add(andBytes);

  final icoFile = File('windows/runner/resources/app_icon.ico');
  icoFile.writeAsBytesSync(builder.toBytes());
  print('SUCCESS: Created standard uncompressed 48x48 BGRA ICO!');
}
