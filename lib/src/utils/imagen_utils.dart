import 'dart:convert';
import 'dart:io';

// Convierte una imagen a texto base64 para guardarla en Firestore.
Future<String> imagenABase64(File archivo) async {
  final bytes = await archivo.readAsBytes();
  return base64Encode(bytes);
}
