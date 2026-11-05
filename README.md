# Práctico N.º 2 — Persistencia de Datos con Firebase Firestore

Programación para Móviles · Tecnicatura Universitaria en Programación Web

Aplicación de gestión de productos, clientes y pedidos, construida sobre la base de
`dime_el_precio`. Este grupo implementó la **persistencia en la nube con Firebase
Firestore**.

## Integrantes

- Gonzalo Flores
- Fabrizio Platero
- Ramiro Platero

## Tecnología utilizada

- **Flutter** como framework de la aplicación.
- **Firebase Firestore** (`cloud_firestore`) como base de datos NoSQL en la nube.
- **Firebase Core** (`firebase_core`) para inicializar la conexión con el proyecto.
- `image_picker` para seleccionar fotos de la cámara o la galería.

## Funcionalidades

- CRUD completo (crear, leer, actualizar, eliminar) de **Productos**, **Clientes** y
  **Pedidos**, con los datos obtenidos en tiempo real desde Firestore.
- Las listas se actualizan solas ante cualquier cambio en la base, sin necesidad de
  recargar la pantalla.
- Gestión de pedidos con seña, fecha de entrega y cálculo automático de deuda.
- Las imágenes de productos y pedidos se guardan como texto en base64 dentro del
  documento (ver [Imágenes](#imágenes)).

## Estructura del proyecto

```
lib/
├── main.dart                   # Inicializa Firebase y arranca la app
├── firebase_options.dart       # Configuración del proyecto (generado por FlutterFire)
└── src/
    ├── models/                 # Cliente, Producto, Pedido, ItemProducto
    ├── services/                # ClienteService, ProductoService, PedidoService
    ├── pages/                   # Pantallas de cada módulo
    ├── routes/                  # Definición de rutas de la app
    └── utils/                   # Helpers (responsive, tema, imagen a base64)
```

Cada modelo tiene su propio servicio, que concentra todas las operaciones contra
Firestore de ese modelo. Las pantallas no llaman a Firestore directamente: siempre
pasan por el servicio correspondiente.

## Modelo de datos

Firestore es una base NoSQL: no hay tablas ni esquema fijo, sino **colecciones** de
**documentos**. Cada documento tiene un id que genera Firestore automáticamente y que
no se repite como campo dentro de los datos.

### Colección `clientes`

| Campo      | Tipo   | Descripción          |
| ---------- | ------ | --------------------- |
| `nombre`   | string | Nombre del cliente     |
| `telefono` | string | Teléfono de contacto   |

### Colección `productos`

| Campo    | Tipo   | Descripción                          |
| -------- | ------ | ------------------------------------- |
| `nombre` | string | Nombre del producto                   |
| `precio` | number | Precio del producto                   |
| `imagen` | string | Imagen del producto en base64          |

### Colección `pedidos`

| Campo          | Tipo    | Descripción                                             |
| -------------- | ------- | -------------------------------------------------------- |
| `idCliente`    | string  | Id del cliente del pedido                                 |
| `nombreCliente`| string  | Nombre del cliente al momento del pedido                  |
| `items`        | array   | Lista de productos pedidos (ver abajo)                    |
| `imagen`       | string  | Imagen de referencia del pedido, en base64                |
| `sena`         | number  | Monto entregado como seña                                  |
| `fechaEncargo` | string  | Fecha en que se hizo el pedido (ISO 8601)                  |
| `fechaEntrega` | string  | Fecha pactada de entrega (ISO 8601)                        |
| `pagoRealizado`| boolean | Si el pedido ya está pagado por completo                   |

Cada elemento de `items` guarda una copia del nombre y precio del producto en el
momento del pedido:

```json
{
  "idProducto": "...",
  "nombreProducto": "...",
  "precioUnitario": 0,
  "cantidad": 1
}
```

Esta duplicación es intencional: si después se edita o elimina un producto, los
pedidos ya hechos conservan el precio y el nombre con los que se vendieron.

## Operaciones y queries por servicio

### `ClienteService`

| Operación            | Método                | Query                               |
| --------------------- | --------------------- | ------------------------------------ |
| Leer (tiempo real)     | `escucharClientes()`   | `orderBy('nombre').snapshots()`       |
| Leer (una vez)         | `getClientes()`        | `orderBy('nombre').get()`             |
| Leer uno               | `getCliente(id)`       | `doc(id).get()`                       |
| Crear                  | `crearCliente(c)`      | `add(datos)`                          |
| Actualizar             | `actualizarCliente(c)` | `doc(id).update(datos)`               |
| Eliminar               | `eliminarCliente(id)`  | `doc(id).delete()`                    |

### `ProductoService`

| Operación            | Método                   | Query                            |
| --------------------- | ------------------------ | --------------------------------- |
| Leer (tiempo real)     | `escucharProductos()`     | `orderBy('nombre').snapshots()`   |
| Leer (una vez)         | `getProductos()`          | `orderBy('nombre').get()`         |
| Leer uno               | `getProducto(id)`         | `doc(id).get()`                   |
| Crear                  | `crearProducto(p)`        | `add(datos)`                      |
| Actualizar             | `actualizarProducto(p)`   | `doc(id).update(datos)`           |
| Eliminar               | `eliminarProducto(id)`    | `doc(id).delete()`                |

### `PedidoService`

| Operación            | Método                 | Query                                 |
| --------------------- | ----------------------- | --------------------------------------- |
| Leer (tiempo real)     | `escucharPedidos()`      | `orderBy('fechaEntrega').snapshots()`   |
| Leer uno               | `getPedido(id)`          | `doc(id).get()`                         |
| Crear                  | `crearPedido(p)`         | `add(datos)`                            |
| Actualizar             | `actualizarPedido(p)`    | `doc(id).update(datos)`                 |
| Eliminar               | `eliminarPedido(id)`     | `doc(id).delete()`                      |

`escucharXs()` deja una suscripción abierta: cada cambio en la colección hace que la
pantalla reciba la lista actualizada sola, sin recargar. `getXs()` trae los datos una
sola vez y no se entera de cambios posteriores; se usa donde no hace falta tiempo
real, como al llenar un listado desplegable.

## Imágenes

Firestore guarda texto y números, no archivos. Por eso las imágenes elegidas con
`image_picker` se convierten a texto en **base64** antes de guardarlas
(`lib/src/utils/imagen_utils.dart`), y se decodifican al mostrarlas
(`lib/src/components/visorimagen_page.dart`).

Se eligió esta forma en lugar de Firebase Storage porque Storage requiere el plan de
pago (Blaze), mientras que base64 dentro del documento funciona en el plan gratuito.
Como contrapartida, cada documento de Firestore tiene un límite de 1 MiB; por eso
`image_picker` comprime las fotos (`imageQuality: 70`, `maxWidth: 800`) antes de
convertirlas.

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
```

El proyecto ya incluye `lib/firebase_options.dart` y
`android/app/google-services.json`, generados con `flutterfire configure`, así que no
hace falta volver a configurar Firebase para ejecutarlo.

Elegir imágenes usa `File` de `dart:io`, que no funciona en la versión web de
Flutter. Para crear o editar productos y pedidos con imágenes nuevas, correr la app en
un emulador o celular Android.

## Reglas de Firestore

La base está configurada en **modo de prueba**, que permite leer y escribir sin
autenticación durante 30 días desde su creación. Pasado ese plazo, las operaciones
contra Firestore van a fallar por permisos hasta actualizar las reglas.
