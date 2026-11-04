import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/pedido.dart';
import '../models/producto.dart';
import '../pages/clientes/cliente_page.dart';
import '../pages/clientes/clientes_page.dart';
import '../pages/clientes/editarcliente_page.dart';
import '../pages/clientes/nuevocliente_page.dart';
import '../pages/home_page.dart';
import '../pages/pedidos/editarpedido_page.dart';
import '../pages/pedidos/nuevopedido_page.dart';
import '../pages/pedidos/pedido_page.dart';
import '../pages/productos/editarproducto_page.dart';
import '../pages/productos/nuevoproducto_page.dart';
import '../pages/productos/producto_page.dart';
import '../pages/productos/productos_page.dart';
import '../pages/pedidos/pedidos_page.dart';

Map<String, WidgetBuilder> getApplicationRoutes() {
  return {
    '/': (context) => const HomePage(),
    '/productos': (context) => const ProductosPage(),
    '/nuevo_producto': (context) => const NuevoProductoPage(),
    '/producto': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Producto) {
        return DetalleProductoPage(producto: args);
      } else {
        return const Scaffold(
          body: Center(
            child: Text('Error: No se proporcionó un producto para mostrar.'),
          ),
        );
      }
    },
    '/editar_producto': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Producto) {
        return EditarProductoPage(producto: args);
      } else {
        return const Scaffold(
          body: Center(
            child: Text('Error: No se proporcionó un producto para editar.'),
          ),
        );
      }
    },
    '/pedidos': (context) => const PedidosPage(),
    '/nuevo_pedido': (context) => const NuevoPedidoPage(),
    '/pedido': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Pedido) {
        return DetallePedidoPage(pedido: args);
      } else {
        return const Scaffold(
          body: Center(
            child: Text('Error: No se proporcionó un pedido para mostrar.'),
          ),
        );
      }
    },
    '/editar_pedido': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Pedido) {
        return EditarPedidoPage(pedido: args);
      } else {
        return const Scaffold(
          body: Center(
            child: Text('Error: No se proporcionó un pedido para editar.'),
          ),
        );
      }
    },
    '/clientes': (context) => const ClientesPage(),
    '/nuevo_cliente': (context) => const NuevoClientePage(),
    '/cliente': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Cliente) {
        return DetalleClientePage(cliente: args);
      } else {
        return DetalleClientePage(
          cliente: Cliente(nombre: 'Cliente 1', telefono: '1111111111'),
        );
        // Descomentar una vez implementado el CRUD de Cleinte
        /*
        return const Scaffold(
          body: Center(
            child: Text('Error: No se proporcionó una ruta válida.'),
          ),
        );
        */
      }
    },
    '/editar_cliente': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Cliente) {
        return EditarClientePage(cliente: args);
      } else {
        return EditarClientePage(
          cliente: Cliente(nombre: 'Cliente 1', telefono: '1111111111'),
        );
        // Descomentar una vez implementado el CRUD de Cleinte
        /*return const Scaffold(
          body: Center(
            child: Text('Error: No se proporcionó un cliente para editar.'),
          ),
        );*/
      }
    },
  };
}
