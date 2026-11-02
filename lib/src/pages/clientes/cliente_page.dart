import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../utils/responsive.dart';

class DetalleClientePage extends StatefulWidget {
  final Cliente cliente;
  const DetalleClientePage({super.key, required this.cliente});

  @override
  State<DetalleClientePage> createState() => _DetalleClientePageState();
}

class _DetalleClientePageState extends State<DetalleClientePage> {
  late Cliente _clienteActual;

  @override
  void initState() {
    super.initState();
    _clienteActual = widget.cliente;
  }

  void _confirmarEliminacion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Cliente'),
          ],
        ),
        content: Text(
          '¿Eliminar a "${_clienteActual.nombre}" de tu directorio?',
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
      // DELETE en Firestore.
      await ClienteService().eliminarCliente(_clienteActual.id!);

      if (mounted) {
        Navigator.pop(context); // cierra el diálogo de carga

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // vuelve a la lista
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cierra el diálogo de carga aunque falle
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editar() async {
    final clienteModificado = await Navigator.pushNamed(
      context,
      '/editar_cliente',
      arguments: _clienteActual,
    );

    if (clienteModificado != null && clienteModificado is Cliente) {
      setState(() {
        _clienteActual = clienteModificado;
      });
    }
  }

  Future<void> _abrirWhatsApp(String telefono) async {
    String numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (!numeroLimpio.startsWith('54')) {
      numeroLimpio = '549$numeroLimpio';
    }

    final Uri url = Uri.parse('https://wa.me/$numeroLimpio');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Verifica que WhatsApp esté instalado.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    final String inicial = _clienteActual.nombre.isNotEmpty
        ? _clienteActual.nombre.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Cliente'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: _editar),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            onPressed: _confirmarEliminacion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsive.wp(6)),
        child: Column(
          children: [
            _avatar(responsive, theme, inicial),
            SizedBox(height: responsive.hp(3)),

            Text(
              _clienteActual.nombre,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.hp(4)),

            _informacion(responsive, theme, inicial),
          ],
        ),
      ),
    );
  }

  Widget _avatar(Responsive responsive, ThemeData theme, String inicial) {
    return CircleAvatar(
      radius: responsive.dp(8),
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(
        inicial,
        style: TextStyle(
          fontSize: responsive.dp(6),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _informacion(Responsive responsive, ThemeData theme, String inicial) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(responsive.wp(4)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(width: responsive.wp(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teléfono',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: responsive.dp(1.4),
                    ),
                  ),
                  Text(
                    _clienteActual.telefono.isNotEmpty
                        ? _clienteActual.telefono
                        : 'No registrado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: responsive.dp(1.8),
                    ),
                  ),
                ],
              ),
            ),

            if (_clienteActual.telefono.isNotEmpty)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.call_rounded, color: Colors.blue),
                    onPressed: () {
                      final Uri urlLlamada = Uri.parse(
                        "tel://${_clienteActual.telefono}",
                      );
                      launchUrl(urlLlamada);
                    },
                  ),
                  // Botón para WhatsApp
                  IconButton(
                    icon: const Icon(Icons.wechat_rounded, color: Colors.green),
                    tooltip: 'Mensaje de WhatsApp',
                    onPressed: () => _abrirWhatsApp(_clienteActual.telefono),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
