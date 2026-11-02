import 'package:flutter/material.dart';

import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../utils/responsive.dart';

class EditarClientePage extends StatefulWidget {
  final Cliente cliente;
  const EditarClientePage({super.key, required this.cliente});

  @override
  State<EditarClientePage> createState() => _EditarClientePageState();
}

class _EditarClientePageState extends State<EditarClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Precargamos los datos del cliente actual en los campos de texto
    _nombreController.text = widget.cliente.nombre;
    _telefonoController.text = widget.cliente.telefono;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _actualizarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Mismo id, datos nuevos.
      final clienteEditado = Cliente(
        id: widget.cliente.id,
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );
      // UPDATE en Firestore.
      await ClienteService().actualizarCliente(clienteEditado);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente actualizado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        // Devolvemos el cliente editado para que la página de detalle se refresque.
        Navigator.pop(context, clienteEditado);
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
      appBar: AppBar(title: const Text('Editar Cliente'), elevation: 0),
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
                  _avatar(responsive, theme),
                  SizedBox(height: responsive.hp(4)),

                  _campoNombre(responsive, theme),
                  SizedBox(height: responsive.hp(2)),

                  _campoTelefono(responsive, theme),
                  SizedBox(height: responsive.hp(6)),

                  _boton(responsive, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(Responsive responsive, ThemeData theme) {
    return Center(
      child: CircleAvatar(
        radius: responsive.dp(5),
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(
          Icons.edit_note_rounded,
          size: responsive.dp(5),
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _campoNombre(Responsive responsive, ThemeData theme) {
    return TextFormField(
      controller: _nombreController,
      textCapitalization: TextCapitalization.words,
      keyboardType: TextInputType.name,
      style: TextStyle(fontSize: responsive.dp(1.6)),
      decoration: InputDecoration(
        labelText: 'Nombre completo',
        prefixIcon: Icon(
          Icons.person_outline_rounded,
          color: theme.colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Ingresa el nombre' : null,
    );
  }

  Widget _campoTelefono(Responsive responsive, ThemeData theme) {
    return TextFormField(
      controller: _telefonoController,
      keyboardType: TextInputType.phone,
      style: TextStyle(fontSize: responsive.dp(1.6)),
      decoration: InputDecoration(
        labelText: 'Número de teléfono (Opcional)',
        prefixIcon: Icon(
          Icons.phone_outlined,
          color: theme.colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          final phoneRegExp = RegExp(r'^[0-9\+\-\s]+$');
          if (!phoneRegExp.hasMatch(value)) {
            return 'Ingresa un número válido';
          }
          if (value.trim().length < 6) {
            return 'El número es demasiado corto';
          }
        }
        return null;
      },
    );
  }

  Widget _boton(Responsive responsive, ThemeData theme) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: responsive.hp(2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.dp(1.5)),
              ),
            ),
            icon: const Icon(Icons.save_as_rounded),
            label: Text(
              'Actualizar Cliente',
              style: TextStyle(
                fontSize: responsive.dp(1.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _actualizarCliente,
          );
  }
}
