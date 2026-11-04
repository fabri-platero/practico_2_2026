import 'package:flutter/material.dart';

import '../../models/pedido.dart';
import '../../services/pedido_service.dart';
import '../../utils/responsive.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  final _pedidoService = PedidoService();

  // Se crea UNA vez. Si lo creáramos dentro de build(), cada setState
  // abriría una suscripción nueva a Firestore.
  late final Stream<List<Pedido>> _streamPedidos;

  @override
  void initState() {
    super.initState();
    _streamPedidos = _pedidoService.escucharPedidos();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Pedidos'), elevation: 0),
      body: SafeArea(
        child: StreamBuilder<List<Pedido>>(
          stream: _streamPedidos,
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (asyncSnapshot.hasError) {
              return _hasError(responsive, theme);
            } else if (!asyncSnapshot.hasData || asyncSnapshot.data!.isEmpty) {
              return _sinPedidos(responsive, theme);
            }

            // --- LÓGICA DE CATEGORIZACIÓN ---
            final todosLosPedidos = asyncSnapshot.data!;

            final List<Pedido> vencidosImpagos = [];
            final List<Pedido> proximos = [];
            final List<Pedido> pendientes = [];
            final List<Pedido> historial = [];

            // Obtenemos la fecha de "hoy" a las 00:00 para comparar días exactos sin horas
            final now = DateTime.now();
            final hoy = DateTime(now.year, now.month, now.day);
            final int diasParaProximos = 3;

            for (var p in todosLosPedidos) {
              final fechaE = DateTime(
                p.fechaEntrega.year,
                p.fechaEntrega.month,
                p.fechaEntrega.day,
              );
              final estaPagado = p.pagoRealizado || p.diferencia <= 0;

              if (fechaE.isBefore(hoy)) {
                if (estaPagado) {
                  historial.add(p);
                } else {
                  vencidosImpagos.add(p);
                }
              } else {
                final diferenciaDias = fechaE.difference(hoy).inDays;
                if (diferenciaDias <= diasParaProximos) {
                  proximos.add(p);
                } else {
                  pendientes.add(p);
                }
              }
            }

            // Urgentes y futuros: Los más cercanos primero
            vencidosImpagos.sort(
              (a, b) => a.fechaEntrega.compareTo(b.fechaEntrega),
            );
            proximos.sort((a, b) => a.fechaEntrega.compareTo(b.fechaEntrega));
            pendientes.sort((a, b) => a.fechaEntrega.compareTo(b.fechaEntrega));
            historial.sort((a, b) => b.fechaEntrega.compareTo(a.fechaEntrega));

            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.wp(4),
                vertical: responsive.hp(2),
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                _SeccionPedidos(
                  titulo: '¡Vencidos y con Deuda!',
                  icono: Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  pedidos: vencidosImpagos,
                  responsive: responsive,
                  alVolver: () => setState(() {}),
                ),
                _SeccionPedidos(
                  titulo: 'Próximos a Entregar',
                  icono: Icons.schedule_send_rounded,
                  color: Colors.orange.shade700,
                  pedidos: proximos,
                  responsive: responsive,
                  alVolver: () => setState(() {}),
                ),
                _SeccionPedidos(
                  titulo: 'Pedidos Pendientes',
                  icono: Icons.pending_actions_rounded,
                  color: theme.colorScheme.primary,
                  pedidos: pendientes,
                  responsive: responsive,
                  alVolver: () => setState(() {}),
                ),
                _SeccionPedidos(
                  titulo: 'Historial Completado',
                  icono: Icons.inventory_rounded,
                  color: Colors.green.shade700,
                  pedidos: historial,
                  responsive: responsive,
                  alVolver: () => setState(() {}),
                ),
                SizedBox(height: responsive.hp(8)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/nuevo_pedido');
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Nuevo Pedido'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _hasError(Responsive responsive, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: responsive.dp(5),
            color: theme.colorScheme.error,
          ),
          SizedBox(height: responsive.hp(2)),
          Text(
            'Error al cargar pedidos',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }

  Widget _sinPedidos(Responsive responsive, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: responsive.dp(8),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          SizedBox(height: responsive.hp(2)),
          Text(
            'No hay pedidos registrados',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET PARA DIBUJAR UNA SECCIÓN COMPLETA ---
class _SeccionPedidos extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color color;
  final List<Pedido> pedidos;
  final Responsive responsive;
  final VoidCallback alVolver;

  const _SeccionPedidos({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.pedidos,
    required this.responsive,
    required this.alVolver,
  });

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return const SizedBox.shrink(); // Si no hay pedidos, no dibuja nada
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_cabecera(), ..._pedidos()],
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: EdgeInsets.only(
        top: responsive.hp(2),
        bottom: responsive.hp(1),
        left: 4,
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: responsive.dp(2.2)),
          SizedBox(width: responsive.wp(2)),
          Text(
            titulo,
            style: TextStyle(
              fontSize: responsive.dp(1.8),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(width: responsive.wp(2)),
          // Globo con la cantidad
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${pedidos.length}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: responsive.dp(1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Iterable<_PedidoTile> _pedidos() => pedidos.map(
    (pedido) =>
        _PedidoTile(pedido: pedido, responsive: responsive, alVolver: alVolver),
  );
}

// --- WIDGET DE LA TARJETA DEL PEDIDO ---
class _PedidoTile extends StatelessWidget {
  final Pedido pedido;
  final Responsive responsive;
  final VoidCallback alVolver;

  const _PedidoTile({
    required this.pedido,
    required this.responsive,
    required this.alVolver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String fechaEntrega =
        '${pedido.fechaEntrega.day.toString().padLeft(2, '0')}/${pedido.fechaEntrega.month.toString().padLeft(2, '0')}/${pedido.fechaEntrega.year}';
    final bool estaPagado = pedido.pagoRealizado || pedido.diferencia <= 0;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: responsive.hp(1.5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.dp(1.5)),
        side: BorderSide(
          color: estaPagado ? Colors.green.shade400 : Colors.orange.shade400,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(responsive.dp(1.5)),
        onTap: () async {
          await Navigator.pushNamed(context, '/pedido', arguments: pedido);
          alVolver();
        },
        child: Padding(
          padding: EdgeInsets.all(responsive.wp(3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pedido.nombreCliente,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: responsive.dp(1.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pedido.imagen.isNotEmpty)
                    Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.primary,
                      size: responsive.dp(2.2),
                    ),
                ],
              ),
              SizedBox(height: responsive.hp(1)),

              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: responsive.dp(1.6),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: responsive.wp(1)),
                  Text(
                    'Entrega: $fechaEntrega',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: responsive.dp(1.4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: \$${pedido.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: responsive.dp(1.4),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.wp(2),
                      vertical: responsive.hp(0.5),
                    ),
                    decoration: BoxDecoration(
                      color: estaPagado
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(responsive.dp(1)),
                    ),
                    child: Text(
                      estaPagado
                          ? 'PAGADO'
                          : 'DEBE: \$${pedido.diferencia.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: estaPagado
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: responsive.dp(1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
