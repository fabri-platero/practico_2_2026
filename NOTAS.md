# Notas de estudio – Práctico 2: Persistencia con Firebase Firestore

> Mi parte: **CRUD de Clientes**. Grupo: Firestore (persistencia en la nube).

---

## 1. ¿Qué es "persistencia"?

Guardar los datos de forma que **sobrevivan** al cierre de la app.
Antes, los clientes estaban en una lista escrita en el código (`return [Cliente(...), ...]`):
cada vez que se abría la app aparecían los mismos 3 y lo que se agregaba se perdía.

| Tipo | Dónde viven los datos | Tecnologías del práctico |
|---|---|---|
| Local | En el celular | Drift (SQL), Hive (clave-valor) |
| Nube | En un servidor | **Firestore**, Supabase (PostgreSQL) |

Ventaja de la nube: varios dispositivos ven los mismos datos, y en tiempo real.
Desventaja: se necesita internet (aunque Firestore tiene caché offline) y una cuenta/proyecto.

---

## 2. Conceptos de Firestore

Firestore es una base de datos **NoSQL de documentos**. No hay tablas ni filas:

```
Firestore
 └── colección "clientes"            ← como una "tabla"
      ├── documento "aB3xK9..."       ← como una "fila"; el id lo genera Firestore
      │     ├── nombre: "Juan"        ← campos (clave: valor)
      │     └── telefono: "264..."
      └── documento "Zq81Lm..."
            ├── nombre: "Ana"
            └── telefono: "264..."
```

- **Colección**: grupo de documentos. Se crea sola al guardar el primer documento.
- **Documento**: un objeto con campos. Tiene un **id único**.
- No hay esquema fijo: dos documentos podrían tener campos distintos (por eso
  `fromMap` usa `?? ''` como valor por defecto).

Comparación con SQL (para explicar en la presentación):

| SQL | Firestore |
|---|---|
| tabla | colección |
| fila | documento |
| columna | campo |
| `id INT AUTO_INCREMENT` | id de documento generado (`add()`) |
| JOIN | no existe → se guardan datos duplicados (ej: `Pedido` guarda `nombreCliente`) |

---

## 3. Configuración (la hace UNA persona del grupo)

```bash
# 1. Paquetes
flutter pub add firebase_core cloud_firestore

# 2. CLI de FlutterFire (una vez en la PC)
dart pub global activate flutterfire_cli
firebase login              # requiere tener instalado Firebase CLI (npm i -g firebase-tools)

# 3. Conecta el proyecto Flutter con el proyecto de Firebase
flutterfire configure       # genera lib/firebase_options.dart
```

En la consola de Firebase: **Firestore Database → Crear base de datos** (modo prueba para el práctico).

Y en `main.dart` hay que inicializar Firebase **antes** de `runApp`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();          // necesario antes de usar plugins
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(DimeelprecioApp());
}
```

> `ensureInitialized()` asegura que el "puente" entre Flutter y el código nativo
> (Android/iOS) esté listo, porque Firebase es un plugin nativo.

---

## 4. Patrón usado: una clase "servicio"

Archivo: `lib/src/services/cliente_service.dart`

Toda la lógica de Firestore está en `ClienteService`. Las páginas solo llaman métodos
como `crearCliente(...)`. Ventajas:

- Si cambiamos de base de datos, se modifica **un solo archivo**.
- Las páginas quedan más limpias (solo UI).
- Otros compañeros reutilizan el servicio (ej: el formulario de **Pedidos** necesita la
  lista de clientes → `ClienteService().getClientes()`).

```dart
final _coleccion = FirebaseFirestore.instance.collection('clientes');
```

`FirebaseFirestore.instance` = la conexión a la base. `.collection('clientes')` = referencia
a la colección (todavía no trae datos, solo "apunta").

---

## 5. Las queries del CRUD (esto se explica en la presentación)

### CREATE – `add()`
```dart
final doc = await _coleccion.add(datos);   // Firestore genera el id
return doc.id;
```
- `add` crea un documento nuevo con **id automático**.
- Alternativa: `_coleccion.doc('miId').set(datos)` si quisiera elegir yo el id.

### READ – `snapshots()` (tiempo real)
```dart
_coleccion
  .orderBy('nombre')                 // ordena alfabéticamente (query)
  .snapshots()                       // Stream<QuerySnapshot>: emite en cada cambio
  .map((snapshot) => snapshot.docs
      .map((doc) => Cliente.fromMap(doc.data(), documentId: doc.id))
      .toList());
```
- `snapshots()` **escucha** la colección: cada vez que alguien agrega, edita o borra,
  emite la lista nueva → la pantalla se actualiza sola, sin `setState`.
- `doc.data()` = el `Map` con los campos; `doc.id` = el id del documento.
- `Cliente.fromMap` convierte el Map en objeto Dart.

### READ una sola vez – `get()`
```dart
final snapshot = await _coleccion.orderBy('nombre').get();
```
- Trae los datos **una vez** (Future), no escucha cambios.

### UPDATE – `update()`
```dart
await _coleccion.doc(cliente.id).update(datos);
```
- `doc(id)` apunta a un documento puntual. `update` cambia esos campos.
- Si el documento no existe, `update` **falla** (a diferencia de `set`, que lo crearía).

### DELETE – `delete()`
```dart
await _coleccion.doc(id).delete();
```

### Otras queries útiles (por si preguntan)
```dart
_coleccion.where('nombre', isEqualTo: 'Juan')             // filtrar
_coleccion.where('telefono', isGreaterThanOrEqualTo: '264')
_coleccion.orderBy('nombre').limit(10)                    // primeros 10
```

---

## 6. `toMap()` / `fromMap()` – serialización

Firestore guarda `Map<String, dynamic>`, no objetos Dart. Por eso el modelo tiene:

- `toMap()`: objeto → Map (para **guardar**)
- `fromMap(map, documentId: id)`: Map → objeto (para **leer**)

Detalle: en `_datosSinId` saco el campo `'id'` del Map antes de guardar, porque el id
**ya es el nombre del documento**; guardarlo adentro sería duplicado (y al crear vale `null`).

---

## 7. Future vs Stream

| | `Future<T>` | `Stream<T>` |
|---|---|---|
| Valores | **uno** (en el futuro) | **muchos** a lo largo del tiempo |
| Widget | `FutureBuilder` | `StreamBuilder` |
| Firestore | `get()`, `add()`, `update()`, `delete()` | `snapshots()` |

`await` espera un Future. Por eso los métodos que escriben son `async` y devuelven `Future`.

---

## 8. Cambios en cada página

| Página | Operación | Qué cambié |
|---|---|---|
| `clientes_page.dart` | READ | Saqué la lista fija. El `StreamBuilder` usa `ClienteService().escucharClientes()` |
| `nuevocliente_page.dart` | CREATE | Armo un `Cliente` con los controllers y llamo `crearCliente` |
| `editarcliente_page.dart` | UPDATE | Armo un `Cliente` **con el mismo id**, llamo `actualizarCliente` y lo devuelvo con `Navigator.pop(context, clienteEditado)` |
| `cliente_page.dart` | DELETE | Llamo `eliminarCliente(id)` dentro de `try/catch` |

### ¿Por qué el Stream se crea en `initState` y no en `build`?
`build()` se ejecuta muchas veces (cada `setState`, al rotar la pantalla, etc.).
Si escribiera `stream: _clienteService.escucharClientes()` dentro de `build`, cada vez se
crearía una **suscripción nueva** a Firestore y el `StreamBuilder` volvería al estado
"cargando". En `initState` se crea **una sola vez** por pantalla.

### `if (mounted)`
Después de un `await`, el usuario pudo haber salido de la pantalla. `mounted` indica si
el widget sigue en pantalla; si no, usar `context` da error.

### `try / catch / finally`
- `try`: la operación que puede fallar (sin internet, permisos, etc.).
- `catch`: mostrar el error en un `SnackBar`.
- `finally`: se ejecuta siempre → apagar el `_isLoading`.
En borrar agregué `try/catch` porque, si fallaba, el diálogo de carga quedaba abierto.

---

## 9. Reglas de seguridad (posible pregunta)

En "modo prueba" Firestore permite leer/escribir a cualquiera por 30 días:
```
allow read, write: if request.time < timestamp.date(2026, 12, 2);
```
En una app real se usaría Firebase Auth: `allow read, write: if request.auth != null;`

---

## 10. Para la presentación (mi parte)

1. Mostrar la colección `clientes` en la consola de Firebase.
2. Crear un cliente desde la app → aparece en la consola al instante.
3. Editarlo desde la **consola** → la app se actualiza sola (gracias a `snapshots()`).
4. Explicar las 4 queries (`add`, `snapshots/orderBy`, `update`, `delete`).
5. Desafíos: configuración de Firebase, entender Stream vs Future, que el id no va
   dentro del documento.
