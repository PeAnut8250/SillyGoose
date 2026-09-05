import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/goose.jpg');
  final image = img.decodeImage(file.readAsBytesSync());
  if (image != null) {
    final pixel = image.getPixel(0, 0);
    print('#${pixel.r.toInt().toRadixString(16).padLeft(2, '0')}${pixel.g.toInt().toRadixString(16).padLeft(2, '0')}${pixel.b.toInt().toRadixString(16).padLeft(2, '0')}');
  }
}
