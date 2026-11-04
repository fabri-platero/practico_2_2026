import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pedido.dart';

/// Servicio que concentra TODAS las operaciones de Firestore para Pedidos.
/// Las páginas no hablan con Firestore directamente: llaman a este servicio.
class PedidoService {
  // Referencia a la colección "pedidos" en Firestore.
  // Si la colección no existe, Firestore la crea con el primer documento.
  final CollectionReference<Map<String, dynamic>> _coleccion =
      FirebaseFirestore.instance.collection('pedidos');

  /// Firestore genera el id del documento; no lo guardamos dentro de los datos.
  Map<String, dynamic> _datosSinId(Pedido pedido) {
    final datos = pedido.toMap();
    datos.remove('id');
    return datos;
  }

  /// READ: escucha la colección en tiempo real, ordenada por fecha de entrega.
  /// Cada vez que alguien crea, edita o borra un pedido, el Stream emite
  /// la lista nueva y la pantalla se actualiza sola.
  Stream<List<Pedido>> escucharPedidos() {
    return _coleccion
        .orderBy('fechaEntrega')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Pedido.fromMap(doc.data(), documentId: doc.id))
              .toList(),
        );
  }

  /// READ (uno): busca un pedido por su id.
  Future<Pedido?> getPedido(String id) async {
    final doc = await _coleccion.doc(id).get();
    if (!doc.exists) return null;
    return Pedido.fromMap(doc.data()!, documentId: doc.id);
  }

  /// CREATE: agrega un documento con id automático y devuelve ese id.
  Future<String> crearPedido(Pedido pedido) async {
    final doc = await _coleccion.add(_datosSinId(pedido));
    return doc.id;
  }

  /// UPDATE: reemplaza los campos del documento con ese id.
  Future<void> actualizarPedido(Pedido pedido) async {
    if (pedido.id == null) {
      throw ArgumentError('No se puede actualizar un pedido sin id');
    }
    await _coleccion.doc(pedido.id).update(_datosSinId(pedido));
  }

  /// DELETE: borra el documento con ese id.
  Future<void> eliminarPedido(String id) async {
    await _coleccion.doc(id).delete();
  }
}
