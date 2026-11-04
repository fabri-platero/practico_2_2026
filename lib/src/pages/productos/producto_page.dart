import 'package:flutter/material.dart';

import '../../components/visorimagen_page.dart';
import '../../models/producto.dart';
import '../../services/producto_service.dart';
import '../../utils/responsive.dart';

class DetalleProductoPage extends StatefulWidget {
  final Producto producto;
  const DetalleProductoPage({super.key, required this.producto});

  @override
  State<DetalleProductoPage> createState() => _DetalleProductoPageState();
}

class _DetalleProductoPageState extends State<DetalleProductoPage> {
  late Producto _productoActual;

  @override
  void initState() {
    super.initState();
    _productoActual = widget.producto;
  }

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Eliminar Producto'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${_productoActual.nombre}"?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _ejecutarBorrado();
            },
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarBorrado() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ProductoService().eliminarProducto(_productoActual.id!);

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Editar',
            onPressed: () async {
              final productoModificado = await Navigator.pushNamed(
                context,
                '/editar_producto',
                arguments: _productoActual,
              );

              if (productoModificado != null &&
                  productoModificado is Producto) {
                setState(() {
                  _productoActual = productoModificado;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.redAccent,
            tooltip: 'Eliminar',
            onPressed: () => _confirmarEliminacion(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _imagen(responsive, theme),
            _informacion(responsive, theme),
          ],
        ),
      ),
    );
  }

  Widget _imagen(Responsive responsive, ThemeData theme) {
    return Container(
      height: responsive.hp(40),
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: VisorImagen(imagen: _productoActual.imagen),
    );
  }

  Widget _informacion(Responsive responsive, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(responsive.wp(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _productoActual.nombre,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: responsive.hp(1)),

          Text(
            '\$${_productoActual.precio.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: responsive.hp(4)),

          // --- PANEL DE ACCIONES INFERIOR  ---
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: responsive.hp(1.5)),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar'),
                  onPressed: () => _confirmarEliminacion(context),
                ),
              ),
              SizedBox(width: responsive.wp(4)),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: responsive.hp(1.5)),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  onPressed: () async {
                    final productoModificado = await Navigator.pushNamed(
                      context,
                      '/editar_producto',
                      arguments: _productoActual,
                    );

                    if (productoModificado != null &&
                        productoModificado is Producto) {
                      setState(() {
                        _productoActual = productoModificado;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
