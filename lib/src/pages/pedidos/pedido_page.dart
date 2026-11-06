import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Ajusta estas rutas a tu proyecto
import '../../components/visorimagen_page.dart';
import '../../models/pedido.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../services/pedido_service.dart';
import '../../utils/responsive.dart';

class DetallePedidoPage extends StatefulWidget {
  final Pedido pedido;

  const DetallePedidoPage({super.key, required this.pedido});

  @override
  State<DetallePedidoPage> createState() => _DetallePedidoPageState();
}

class _DetallePedidoPageState extends State<DetallePedidoPage> {
  final _clienteService = ClienteService();
  final _pedidoService = PedidoService();

  late Pedido _pedidoActual;
  Cliente? _clienteCompleto;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pedidoActual = widget.pedido;
    _cargarDatosCliente();
  }

  Future<void> _cargarDatosCliente() async {
    try {
      final cliente = await _clienteService.getCliente(_pedidoActual.idCliente);
      setState(() {
        _clienteCompleto =
            cliente ??
            Cliente(
              id: _pedidoActual.idCliente,
              nombre: _pedidoActual.nombreCliente,
              telefono: '',
            );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error al cargar cliente: $e');
    }
  }

  // Botón para registrar pagos (totales o parciales)
  Future<void> _registrarPago() async {
    final TextEditingController pagoController = TextEditingController();

    // Por comodidad, pre-llenamos el campo con la deuda restante
    pagoController.text = _pedidoActual.diferencia.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resta pagar: \$${_pedidoActual.diferencia.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pagoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto a ingresar',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Capturamos y limpiamos el monto
              final montoIngresado =
                  double.tryParse(pagoController.text.replaceAll(',', '.')) ??
                  0.0;

              // Validaciones de negocio
              if (montoIngresado <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un monto válido mayor a 0'),
                  ),
                );
                return;
              }

              if (montoIngresado > _pedidoActual.diferencia) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El monto no puede superar la deuda actual'),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);

              // 3. Actualizamos el estado
              setState(() {
                // Le sumamos el nuevo pago a la seña que ya existía
                _pedidoActual.sena += montoIngresado;

                // Si con este pago la diferencia llega a 0, marcamos el flag de finalizado
                if (_pedidoActual.diferencia <= 0) {
                  _pedidoActual.pagoRealizado = true;
                }
              });

              // Guardamos el pago en Firestore
              try {
                await _pedidoService.actualizarPedido(_pedidoActual);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pago registrado con éxito',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al registrar el pago: $e')),
                  );
                }
              }
            },
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );
  }

  // Eliminar Pedido
  Future<void> _confirmarEliminacion() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Pedido'),
          ],
        ),
        content: const Text('¿Eliminar este pedido permanentemente?'),
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
              Navigator.pop(ctx); // cierra el alerta
              try {
                if (_pedidoActual.id != null) {
                  await _pedidoService.eliminarPedido(_pedidoActual.id!);
                }
                if (mounted) {
                  Navigator.pop(context); // Vuelve a la lista
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar el pedido: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // WhatsApp
  Future<void> _enviarWhatsApp() async {
    if (_clienteCompleto == null || _clienteCompleto!.telefono.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'Hola *${_pedidoActual.nombreCliente}*, te confirmo los detalles de tu pedido:\n',
    );

    for (var item in _pedidoActual.items) {
      buffer.writeln('▪️ ${item.cantidad}x ${item.nombreProducto}');
    }

    final String fechaE =
        '${_pedidoActual.fechaEntrega.day}/${_pedidoActual.fechaEntrega.month}/${_pedidoActual.fechaEntrega.year}';
    buffer.writeln('\n📅 *Fecha de entrega acordada:* $fechaE');
    buffer.writeln('💰 *Total:* \$${_pedidoActual.total.toStringAsFixed(2)}');

    if (_pedidoActual.diferencia > 0) {
      buffer.writeln(
        '⚠️ *Resta abonar:* \$${_pedidoActual.diferencia.toStringAsFixed(2)}',
      );
    } else {
      buffer.writeln('✅ *Estado:* Totalmente abonado.');
    }

    String numeroLimpio = _clienteCompleto!.telefono.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (!numeroLimpio.startsWith('54')) numeroLimpio = '549$numeroLimpio';

    final Uri url = Uri.parse(
      'https://wa.me/$numeroLimpio?text=${Uri.encodeComponent(buffer.toString())}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // Visualizador de Imagen a Pantalla Completa
  void _verImagenCompleta() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              // Permite hacer zoom pellizcando
              panEnabled: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.5,
              maxScale: 3,
              child: VisorImagen(imagen: _pedidoActual.imagen),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String fechaEncargo =
        '${_pedidoActual.fechaEncargo.day}/${_pedidoActual.fechaEncargo.month}/${_pedidoActual.fechaEncargo.year}';
    final String fechaEntrega =
        '${_pedidoActual.fechaEntrega.day}/${_pedidoActual.fechaEntrega.month}/${_pedidoActual.fechaEntrega.year}';
    final bool estaPagado =
        _pedidoActual.pagoRealizado || _pedidoActual.diferencia <= 0;

    // Comparamos solo por día (sin hora): un pedido que entrega hoy sigue
    // siendo editable durante todo el día de hoy, no solo hasta la medianoche.
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final fechaEntregaSinHora = DateTime(
      _pedidoActual.fechaEntrega.year,
      _pedidoActual.fechaEntrega.month,
      _pedidoActual.fechaEntrega.day,
    );
    final bool puedeEditar = !fechaEntregaSinHora.isBefore(hoy);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Pedido'),
        actions: puedeEditar
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded),
                  onPressed: () async {
                    final pedidoEditado = await Navigator.pushNamed(
                      context,
                      '/editar_pedido',
                      arguments: _pedidoActual,
                    );

                    // Si el usuario guardó cambios y la pantalla devolvió el objeto nuevo
                    if (pedidoEditado != null && pedidoEditado is Pedido) {
                      setState(() {
                        _pedidoActual = pedidoEditado;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: _confirmarEliminacion,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _cabecera(responsive, theme, fechaEntrega, fechaEncargo),
                    _listaItems(responsive, theme),
                  ],
                ),
              ),
            ),
            _footer(responsive, theme, estaPagado),
          ],
        ),
      ),
    );
  }

  Widget _cabecera(
    Responsive responsive,
    ThemeData theme,
    String fechaEntrega,
    String fechaEncargo,
  ) {
    return Container(
      padding: EdgeInsets.all(responsive.wp(5)),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente',
                    style: TextStyle(
                      fontSize: responsive.dp(1.4),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _pedidoActual.nombreCliente,
                    style: TextStyle(
                      fontSize: responsive.dp(2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_pedidoActual.imagen.isNotEmpty)
                InkWell(
                  onTap: _verImagenCompleta,
                  child: Container(
                    width: responsive.dp(6),
                    height: responsive.dp(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: VisorImagen(imagen: _pedidoActual.imagen),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: responsive.hp(2)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Encargado: $fechaEncargo',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Entrega: $fechaEntrega',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaItems(Responsive responsive, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(responsive.wp(4)),
      itemCount: _pedidoActual.items.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final item = _pedidoActual.items[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text('${item.cantidad}'),
          ),
          title: Text(
            item.nombreProducto,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('\$${item.precioUnitario.toStringAsFixed(2)} c/u'),
          trailing: Text(
            '\$${item.subtotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: responsive.dp(1.8),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(Responsive responsive, ThemeData theme, bool estaPagado) {
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
          _total(responsive, theme),
          const SizedBox(height: 4),
          _senia(responsive, theme),
          const Divider(),
          _pagado(responsive, theme, estaPagado),
          SizedBox(height: responsive.hp(2)),
          _acciones(responsive, theme, estaPagado),
        ],
      ),
    );
  }

  Widget _total(Responsive responsive, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Total:', style: TextStyle(fontSize: 16)),
        Text(
          '\$${_pedidoActual.total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _senia(Responsive responsive, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Seña abonada:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          '\$${_pedidoActual.sena.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _pagado(Responsive responsive, ThemeData theme, bool estaPagado) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          estaPagado ? 'ESTADO:' : 'RESTA PAGAR:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: estaPagado ? Colors.green : Colors.orange.shade700,
          ),
        ),
        Text(
          estaPagado
              ? 'PAGADO'
              : '\$${_pedidoActual.diferencia.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: estaPagado ? Colors.green : Colors.orange.shade700,
          ),
        ),
      ],
    );
  }

  Widget _acciones(Responsive responsive, ThemeData theme, bool estaPagado) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: responsive.hp(1.5)),
              foregroundColor: Colors.green,
            ),
            onPressed: _enviarWhatsApp,
            child: const Icon(Icons.wechat_rounded),
          ),
        ),
        if (!estaPagado) ...[
          SizedBox(width: responsive.wp(3)),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: responsive.hp(1.5)),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text(
                'Registrar Pago',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _registrarPago,
            ),
          ),
        ],
      ],
    );
  }
}
