import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/visorimagen_page.dart';
import '../../models/itemproducto.dart';
import '../../models/pedido.dart';
import '../../models/cliente.dart';
import '../../models/producto.dart';
import '../../services/cliente_service.dart';
import '../../services/pedido_service.dart';
import '../../services/producto_service.dart';
import '../../utils/imagen_utils.dart';
import '../../utils/responsive.dart';

class EditarPedidoPage extends StatefulWidget {
  final Pedido pedido;

  const EditarPedidoPage({super.key, required this.pedido});

  @override
  State<EditarPedidoPage> createState() => _EditarPedidoPageState();
}

class _EditarPedidoPageState extends State<EditarPedidoPage> {
  final _clienteService = ClienteService();
  final _productoService = ProductoService();
  final _pedidoService = PedidoService();

  Cliente? _clienteSeleccionado;
  List<ItemProducto> _items = [];
  bool _isLoading = false;
  bool _inicializado = false;

  late DateTime _fechaEncargo;
  late DateTime _fechaEntrega;
  final TextEditingController _senaController = TextEditingController();

  String _imagenActualPath = '';
  File? _nuevaImagenFile;
  final ImagePicker _picker = ImagePicker();

  late final Stream<List<Cliente>> _streamClientes;
  late final Stream<List<Producto>> _streamProductos;

  @override
  void initState() {
    super.initState();

    _streamClientes = _clienteService.escucharClientes();
    _streamProductos = _productoService.escucharProductos();

    _items = widget.pedido.items
        .map(
          (i) => ItemProducto(
            idProducto: i.idProducto,
            nombreProducto: i.nombreProducto,
            precioUnitario: i.precioUnitario,
            cantidad: i.cantidad,
          ),
        )
        .toList();

    _fechaEncargo = widget.pedido.fechaEncargo;
    _fechaEntrega = widget.pedido.fechaEntrega;
    _senaController.text = widget.pedido.sena > 0
        ? widget.pedido.sena.toString()
        : '';
    _imagenActualPath = widget.pedido.imagen;

    _senaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _senaController.dispose();
    super.dispose();
  }

  double get _totalPedido => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _sena => double.tryParse(_senaController.text.trim()) ?? 0.0;
  double get _diferencia => _totalPedido - _sena;

  void _agregarProducto(Producto producto) {
    setState(() {
      final index = _items.indexWhere((item) => item.idProducto == producto.id);
      if (index != -1) {
        _items[index].cantidad++;
      } else {
        _items.add(
          ItemProducto(
            idProducto: producto.id!,
            nombreProducto: producto.nombre,
            precioUnitario: producto.precio,
            cantidad: 1,
          ),
        );
      }
    });
  }

  Future<void> _seleccionarFecha(bool esEntrega) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: esEntrega ? _fechaEntrega : _fechaEncargo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (esEntrega) {
          _fechaEntrega = picked;
        } else {
          _fechaEncargo = picked;
        }
      });
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
                  _seleccionarNuevaImagen(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarNuevaImagen(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _seleccionarNuevaImagen(ImageSource origen) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: origen,
        imageQuality: 60,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _nuevaImagenFile = File(pickedFile.path);
          _imagenActualPath = '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar imagen')),
      );
    }
  }

  void _quitarImagen() {
    setState(() {
      _nuevaImagenFile = null;
      _imagenActualPath = '';
    });
  }

  // --- GUARDADO ---
  Future<void> _actualizarPedido() async {
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El pedido no puede estar vacío')),
      );
      return;
    }
    if (_sena > _totalPedido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La seña no puede superar el total')),
      );
      return;
    }
    if (_fechaEntrega.isBefore(_fechaEncargo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha de entrega no puede ser anterior a la de encargo',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String imagen = _nuevaImagenFile != null
          ? await imagenABase64(_nuevaImagenFile!)
          : _imagenActualPath;

      final pedidoEditado = Pedido(
        id: widget.pedido.id,
        idCliente: _clienteSeleccionado!.id!,
        nombreCliente: _clienteSeleccionado!.nombre,
        items: _items,
        imagen: imagen,
        sena: _sena,
        fechaEntrega: _fechaEntrega,
        fechaEncargo: _fechaEncargo,
        pagoRealizado: _diferencia <= 0,
      );

      await _pedidoService.actualizarPedido(pedidoEditado);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, pedidoEditado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar los cambios: $e')),
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
      appBar: AppBar(title: const Text('Editar Pedido'), elevation: 0),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(responsive.wp(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. SELECCIÓN DE CLIENTE
                    // dropdown_search usa el InkWell de material_ui (no el
                    // de package:flutter/material.dart), así que necesita
                    // un ancestro mui.Material propio para no tirar
                    // "No Material widget found".
                    mui.Material(
                      type: mui.MaterialType.transparency,
                      child: StreamBuilder<List<Cliente>>(
                      stream: _streamClientes,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        final clientes = snapshot.data!;

                        if (!_inicializado) {
                          try {
                            _clienteSeleccionado = clientes.firstWhere(
                              (c) => c.id == widget.pedido.idCliente,
                            );
                          } catch (_) {}
                          _inicializado = true;
                        }

                        return DropdownSearch<Cliente>(
                          items: (filter, s) => clientes,
                          compareFn: (item1, item2) => item1.id == item2.id,
                          selectedItem: _clienteSeleccionado,
                          // Le decimos al paquete qué atributo del objeto debe mostrar en pantalla
                          itemAsString: (Cliente c) => c.nombre,
                          // Qué pasa cuando el usuario elige uno
                          onSelected: (Cliente? item) {
                            setState(() {
                              _clienteSeleccionado = item;
                            });
                          },
                          // Configuración de la ventana de búsqueda (Menú desplegable)
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: const TextFieldProps(
                              decoration: mui.InputDecoration(
                                hintText: "Buscar cliente...",
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            // Mensaje por si busca un cliente que no existe
                            emptyBuilder: (context, searchEntry) => Center(
                              child: Text('No se encontró a "$searchEntry"'),
                            ),
                          ),
                          // Configuración visual del botón principal
                          decoratorProps: DropDownDecoratorProps(
                            decoration: mui.InputDecoration(
                              labelText: 'Cliente seleccionado',
                              prefixIcon: Icon(
                                Icons.person_search_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                      ),
                    ),
                    SizedBox(height: responsive.hp(2)),

                    // 2. FECHAS (Ambas son editables)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _seleccionarFecha(false),
                            child: Container(
                              padding: EdgeInsets.all(responsive.wp(3)),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fecha de Encargo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${_fechaEncargo.day}/${_fechaEncargo.month}/${_fechaEncargo.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: responsive.wp(3)),
                        Expanded(
                          child: InkWell(
                            onTap: () => _seleccionarFecha(true),
                            child: Container(
                              padding: EdgeInsets.all(responsive.wp(3)),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha de Entrega',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '${_fechaEntrega.day}/${_fechaEntrega.month}/${_fechaEntrega.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: responsive.hp(3)),

                    // 3. PRODUCTOS Y BOTÓN AGREGAR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Productos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _mostrarSelectorProductos(responsive, theme),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              item.nombreProducto,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '\$${item.precioUnitario} x ${item.cantidad}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () => setState(() {
                                    if (item.cantidad > 1) {
                                      item.cantidad--;
                                    } else {
                                      _items.removeAt(i);
                                    }
                                  }),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.green,
                                  ),
                                  onPressed: () =>
                                      setState(() => item.cantidad++),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: responsive.hp(3)),
                    const Divider(),
                    SizedBox(height: responsive.hp(2)),

                    // 4. FINANZAS E IMAGEN DE REFERENCIA
                    // 4. FINANZAS E IMAGEN DE REFERENCIA (Reorganizado)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección Seña (Arriba)
                        const Text(
                          'Adelanto / Seña',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _senaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                            hintText: '0.00',
                          ),
                        ),

                        SizedBox(height: responsive.hp(3)),

                        // Sección Imagen Compleja (Abajo)
                        const Text(
                          'Boceto/Ref.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _mostrarOpcionesDeImagen,
                          child: Container(
                            height: responsive.dp(
                              18,
                            ), // Más alto para aprovechar el ancho completo
                            width: double
                                .infinity, // Ocupa todo el ancho disponible
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // Lógica para mostrar la nueva foto, o la vieja
                            // (base64 desde Firestore, vía VisorImagen), o nada.
                            child: _nuevaImagenFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _nuevaImagenFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : _imagenActualPath.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: VisorImagen(
                                        imagen: _imagenActualPath,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_a_photo,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                          ),
                        ),

                        // Botón de eliminar alineado a la derecha
                        if (_nuevaImagenFile != null ||
                            _imagenActualPath.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _quitarImagen,
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 16,
                              ),
                              label: const Text(
                                'Quitar foto',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 5. FOOTER DE TOTALES Y GUARDAR
            Container(
              padding: EdgeInsets.all(responsive.wp(5)),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Actualizado:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '\$${_totalPedido.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nuevo saldo a pagar:',
                        style: TextStyle(
                          fontSize: 16,
                          color: _diferencia > 0
                              ? Colors.orange.shade700
                              : Colors.green,
                        ),
                      ),
                      Text(
                        '\$${_diferencia.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _diferencia > 0
                              ? Colors.orange.shade700
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.hp(2)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.hp(1.8),
                        ),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: _isLoading ? null : _actualizarPedido,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.save_rounded),
                      label: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL PARA AGREGAR PRODUCTOS ---
  void _mostrarSelectorProductos(Responsive responsive, ThemeData theme) {
    FocusScope.of(context).unfocus();

    final streamAislado = _streamProductos;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => StreamBuilder<List<Producto>>(
          stream: streamAislado,
          builder: (context, snapshot) {
            final productos = snapshot.data ?? [];
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Catálogo de Productos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: productos.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => ListTile(
                      title: Text(productos[i].nombre),
                      trailing: Text('\$${productos[i].precio}'),
                      onTap: () {
                        _agregarProducto(productos[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(responsive.wp(4)),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.hp(1.8),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/nuevo_producto');
                      setState(() {});
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Crear Nuevo Producto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
