import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';

// Ajusta estas rutas a tu proyecto
import '../../models/itemproducto.dart';
import '../../models/cliente.dart';
import '../../models/pedido.dart';
import '../../models/producto.dart';
import '../../services/cliente_service.dart';
import '../../services/pedido_service.dart';
import '../../services/producto_service.dart';
import '../../utils/responsive.dart';

class NuevoPedidoPage extends StatefulWidget {
  const NuevoPedidoPage({super.key});

  @override
  State<NuevoPedidoPage> createState() => _NuevoPedidoPageState();
}

class _NuevoPedidoPageState extends State<NuevoPedidoPage> {
  final _clienteService = ClienteService();
  final _productoService = ProductoService();
  final _pedidoService = PedidoService();

  Cliente? _clienteSeleccionado;
  final List<ItemProducto> _items = [];
  bool _isLoading = false;

  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _senaController = TextEditingController();
  late DateTime _fechaEncargo;
  late DateTime _fechaEntrega;

  late final Stream<List<Cliente>> _streamClientes;
  late final Stream<List<Producto>> _streamProductos;

  @override
  void initState() {
    super.initState();
    _fechaEncargo = DateTime.now();
    _fechaEntrega = DateTime.now().add(const Duration(days: 7));

    _streamClientes = _clienteService.escucharClientes();
    _streamProductos = _productoService.escucharProductos();

    // Escuchamos los cambios en la seña para repintar la "Diferencia"
    _senaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _senaController.dispose();
    super.dispose();
  }

  // --- CÁLCULOS DINÁMICOS ---
  double get _totalPedido => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _sena => double.tryParse(_senaController.text.trim()) ?? 0.0;
  double get _diferencia => _totalPedido - _sena;

  // --- MÉTODOS DE UI ---
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

  Future<void> _seleccionarFechaEntrega() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega,
      firstDate: DateTime.now(), // No se puede entregar en el pasado
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _fechaEntrega) {
      setState(() => _fechaEntrega = picked);
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

  Future<void> _seleccionarImagen(ImageSource origen) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: origen,
        imageQuality: 60, // Comprimimos al 60% de calidad
        maxWidth: 800, // Reducimos el tamaño para que no pese megabytes
      );

      if (pickedFile != null) {
        setState(() => _imagenSeleccionada = File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar imagen')),
      );
    }
  }

  // --- GUARDADO ---
  Future<void> _guardarPedido() async {
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    if (_sena > _totalPedido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La seña no puede ser mayor al total')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nuevoPedido = Pedido(
        idCliente: _clienteSeleccionado!.id!,
        nombreCliente: _clienteSeleccionado!.nombre,
        items: _items,
        imagen: _imagenSeleccionada?.path ?? '',
        sena: _sena,
        fechaEntrega: _fechaEntrega,
        fechaEncargo: _fechaEncargo,
        pagoRealizado: _diferencia <= 0,
      );

      await _pedidoService.crearPedido(nuevoPedido);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido creado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear el pedido: $e')),
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
      appBar: AppBar(title: const Text('Nuevo Pedido'), elevation: 0),
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
                    const Text(
                      'Cliente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    _cliente(responsive, theme),
                    SizedBox(height: responsive.hp(2)),

                    _fechas(responsive, theme),
                    SizedBox(height: responsive.hp(3)),

                    ..._productos(responsive, theme),
                    SizedBox(height: responsive.hp(3)),
                    const Divider(),

                    SizedBox(height: responsive.hp(2)),
                    _senia(responsive, theme),
                  ],
                ),
              ),
            ),
            _footer(responsive, theme),
          ],
        ),
      ),
    );
  }

  Widget _cliente(Responsive responsive, ThemeData theme) {
    // dropdown_search construye su InkWell interno con los widgets de
    // material_ui (no los de package:flutter/material.dart), así que
    // necesita un ancestro mui.Material propio para no tirar
    // "No Material widget found".
    return mui.Material(
      type: mui.MaterialType.transparency,
      child: StreamBuilder<List<Cliente>>(
        stream: _streamClientes,
        builder: (context, snapshot) {
          final clientes = snapshot.data ?? [];
          return DropdownSearch<Cliente>(
            items: (filter, s) => clientes,
            compareFn: (item1, item2) => item1.id == item2.id,
            selectedItem: _clienteSeleccionado,
            // Le decimos al paquete qué atributo del objeto debe mostrar en pantalla
            itemAsString: (Cliente c) => c.nombre,
            onSelected: (Cliente? item) {
              setState(() {
                _clienteSeleccionado = item;
              });
            },
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: const TextFieldProps(
                decoration: mui.InputDecoration(
                  hintText: "Buscar cliente...",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              emptyBuilder: (context, searchEntry) =>
                  Center(child: Text('No se encontró a "$searchEntry"')),
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
    );
  }

  Widget _fechas(Responsive responsive, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(responsive.wp(3)),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fecha de Encargo',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${_fechaEncargo.day}/${_fechaEncargo.month}/${_fechaEncargo.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: responsive.wp(3)),
        Expanded(
          child: InkWell(
            onTap: _seleccionarFechaEntrega,
            child: Container(
              padding: EdgeInsets.all(responsive.wp(3)),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_fechaEntrega.day}/${_fechaEntrega.month}/${_fechaEntrega.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        Icons.edit_calendar,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _productos(Responsive responsive, ThemeData theme) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Productos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton.icon(
            onPressed: () => _mostrarSelectorProductos(responsive, theme),
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ],
      ),
      _items.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: responsive.hp(2)),
              child: const Center(child: Text('Sin productos agregados')),
            )
          : ListView.builder(
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '\$${item.precioUnitario} x ${item.cantidad} = \$${item.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
                        Text(
                          '${item.cantidad}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.green,
                          ),
                          onPressed: () => setState(() => item.cantidad++),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    ];
  }

  Widget _senia(Responsive responsive, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sección Seña
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

        // Sección Imagen
        const Text(
          'Boceto/Ref.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _mostrarOpcionesDeImagen,
          child: Container(
            height: responsive.dp(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              image: _imagenSeleccionada != null
                  ? DecorationImage(
                      image: FileImage(_imagenSeleccionada!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _imagenSeleccionada == null
                ? const Center(
                    child: Icon(
                      Icons.add_a_photo,
                      color: Colors.grey,
                      size: 40,
                    ),
                  )
                : null,
          ),
        ),
        if (_imagenSeleccionada != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _imagenSeleccionada = null),
              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
              label: const Text(
                'Quitar foto',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(Responsive responsive, ThemeData theme) {
    return Container(
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
              const Text('Total del Pedido:', style: TextStyle(fontSize: 16)),
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
                'Resta pagar:',
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
                padding: EdgeInsets.symmetric(vertical: responsive.hp(1.8)),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: _isLoading ? null : _guardarPedido,
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.check_circle),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Confirmar Pedido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // MODAL PARA SELECCIONAR PRODUCTOS
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
                Padding(padding: EdgeInsets.only(bottom: responsive.hp(2))),
              ],
            );
          },
        ),
      ),
    );
  }
}
