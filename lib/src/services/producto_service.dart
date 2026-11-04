import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/producto.dart';

class ProductoService {
  final CollectionReference<Map<String, dynamic>> _coleccion =
      FirebaseFirestore.instance.collection('productos');

  // Prepara los datos para guardar: el id ya es el nombre del documento.
  Map<String, dynamic> _datosSinId(Producto producto) {
    final datos = producto.toMap();
    datos.remove('id');
    return datos;
  }

  // READ: lista en tiempo real, ordenada por nombre.
  Stream<List<Producto>> escucharProductos() {
    return _coleccion
        .orderBy('nombre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Producto.fromMap(doc.data(), documentId: doc.id))
              .toList(),
        );
  }

  // READ: lista de una sola vez, sin escuchar cambios.
  Future<List<Producto>> getProductos() async {
    final snapshot = await _coleccion.orderBy('nombre').get();
    return snapshot.docs
        .map((doc) => Producto.fromMap(doc.data(), documentId: doc.id))
        .toList();
  }

  // READ: un producto por id; devuelve null si no existe.
  Future<Producto?> getProducto(String id) async {
    final doc = await _coleccion.doc(id).get();
    if (!doc.exists) return null;
    return Producto.fromMap(doc.data()!, documentId: doc.id);
  }

  // CREATE: Firestore genera el id automáticamente y se devuelve.
  Future<String> crearProducto(Producto producto) async {
    final doc = await _coleccion.add(_datosSinId(producto));
    return doc.id;
  }

  // UPDATE: modifica un producto existente; requiere que tenga id.
  Future<void> actualizarProducto(Producto producto) async {
    if (producto.id == null) {
      throw ArgumentError('No se puede actualizar un producto sin id');
    }
    await _coleccion.doc(producto.id).update(_datosSinId(producto));
  }

  // DELETE: borra el producto con ese id.
  Future<void> eliminarProducto(String id) async {
    await _coleccion.doc(id).delete();
  }
}
