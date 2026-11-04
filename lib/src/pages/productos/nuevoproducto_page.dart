import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/producto.dart';
import '../../services/producto_service.dart';
import '../../utils/imagen_utils.dart';
import '../../utils/responsive.dart';

class NuevoProductoPage extends StatefulWidget {
  const NuevoProductoPage({super.key});

  @override
  State<NuevoProductoPage> createState() => _NuevoProductoPageState();
}

class _NuevoProductoPageState extends State<NuevoProductoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();

  File? _imagenSeleccionada;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource origen) async {
    final picker = ImagePicker();
    try {
      final XFile? imagen = await picker.pickImage(
        source: origen,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (imagen != null) {
        setState(() {
          _imagenSeleccionada = File(imagen.path);
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
    }
  }

  void _mostrarOpcionesDeImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de la Galería'),
                onTap: () {
                  Navigator.pop(context); // Cerramos el modal
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imagenSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una imagen para el producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String precioTexto = _precioController.text.replaceAll(',', '.');
      final double precio = double.parse(precioTexto);

      final String imagen = await imagenABase64(_imagenSeleccionada!);

      final nuevoProducto = Producto(
        nombre: _nombreController.text.trim(),
        precio: precio,
        imagen: imagen,
      );
      await ProductoService().crearProducto(nuevoProducto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto guardado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Producto'), elevation: 0),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.wp(6),
              vertical: responsive.hp(3),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _imagen(responsive, theme),
                  SizedBox(height: responsive.hp(4)),

                  _campoNombre(responsive, theme),
                  SizedBox(height: responsive.hp(2)),

                  _campoPrecio(responsive, theme),
                  SizedBox(height: responsive.hp(5)),

                  _boton(responsive, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagen(Responsive responsive, ThemeData theme) {
    return Center(
      child: GestureDetector(
        onTap: _mostrarOpcionesDeImagen,
        child: Container(
          height: responsive.wp(45),
          width: responsive.wp(45),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(responsive.dp(2)),
            border: Border.all(color: theme.colorScheme.outline, width: 2),
            image: _imagenSeleccionada != null
                ? DecorationImage(
                    image: FileImage(_imagenSeleccionada!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _imagenSeleccionada == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: responsive.dp(5),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(height: responsive.hp(1)),
                    Text(
                      'Toque para\nfoto',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: responsive.dp(1.4),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _campoNombre(Responsive responsive, ThemeData theme) {
    return TextFormField(
      controller: _nombreController,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: responsive.dp(1.6)),
      decoration: InputDecoration(
        labelText: 'Nombre del producto',
        labelStyle: TextStyle(fontSize: responsive.dp(1.6)),
        prefixIcon: Icon(
          Icons.shopping_bag_outlined,
          color: theme.colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Ingresa un nombre' : null,
    );
  }

  Widget _campoPrecio(Responsive responsive, ThemeData theme) {
    return TextFormField(
      controller: _precioController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontSize: responsive.dp(1.6)),
      decoration: InputDecoration(
        labelText: 'Precio',
        labelStyle: TextStyle(fontSize: responsive.dp(1.6)),
        prefixIcon: Icon(
          Icons.attach_money_rounded,
          color: theme.colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Ingresa un precio' : null,
    );
  }

  Widget _boton(Responsive responsive, ThemeData theme) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: responsive.hp(2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.dp(1.5)),
              ),
            ),
            onPressed: _guardarProducto,
            child: Text(
              'Guardar Producto',
              style: TextStyle(
                fontSize: responsive.dp(1.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          );
  }
}
