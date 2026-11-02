import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cliente.dart';

/// Servicio que concentra TODAS las operaciones de Firestore para Clientes.
/// Las páginas no hablan con Firestore directamente: llaman a este servicio.
class ClienteService {
  // Referencia a la colección "clientes" en Firestore.
  // Si la colección no existe, Firestore la crea con el primer documento.
  final CollectionReference<Map<String, dynamic>> _coleccion =
      FirebaseFirestore.instance.collection('clientes');

  /// Firestore genera el id del documento; no lo guardamos dentro de los datos.
  Map<String, dynamic> _datosSinId(Cliente cliente) {
    final datos = cliente.toMap();
    datos.remove('id');
    return datos;
  }

  /// READ: escucha la colección en tiempo real, ordenada por nombre.
  /// Cada vez que alguien crea, edita o borra un cliente, el Stream emite
  /// la lista nueva y la pantalla se actualiza sola.
  Stream<List<Cliente>> escucharClientes() {
    return _coleccion
        .orderBy('nombre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Cliente.fromMap(doc.data(), documentId: doc.id))
              .toList(),
        );
  }

  /// READ (una vez): lista de clientes sin escuchar cambios.
  /// Útil para los formularios de pedidos (dropdown de clientes).
  Future<List<Cliente>> getClientes() async {
    final snapshot = await _coleccion.orderBy('nombre').get();
    return snapshot.docs
        .map((doc) => Cliente.fromMap(doc.data(), documentId: doc.id))
        .toList();
  }

  /// READ (uno): busca un cliente por su id. Devuelve null si no existe
  /// (por ejemplo, si el cliente de un pedido fue borrado).
  /// Útil para el detalle del pedido (mostrar nombre y teléfono del cliente).
  Future<Cliente?> getCliente(String id) async {
    final doc = await _coleccion.doc(id).get();
    if (!doc.exists) return null;
    return Cliente.fromMap(doc.data()!, documentId: doc.id);
  }

  /// CREATE: agrega un documento con id automático y devuelve ese id.
  Future<String> crearCliente(Cliente cliente) async {
    final doc = await _coleccion.add(_datosSinId(cliente));
    return doc.id;
  }

  /// UPDATE: reemplaza los campos del documento con ese id.
  Future<void> actualizarCliente(Cliente cliente) async {
    if (cliente.id == null) {
      throw ArgumentError('No se puede actualizar un cliente sin id');
    }
    await _coleccion.doc(cliente.id).update(_datosSinId(cliente));
  }

  /// DELETE: borra el documento con ese id.
  Future<void> eliminarCliente(String id) async {
    await _coleccion.doc(id).delete();
  }
}
