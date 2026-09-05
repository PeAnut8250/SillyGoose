import 'package:dart_des/dart_des.dart';
import 'dart:convert';

void main() {
  String encryptedUrl = 'M9Gf6X0F6Gf36QJ9n3M5jV=='; // just a dummy
  try {
    String key = '38346591';
    DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
    
    // just test compile
    print('Compiled!');
  } catch(e) {
    print(e);
  }
}
