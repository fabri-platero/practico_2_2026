import 'package:flutter/material.dart';

import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../utils/responsive.dart';

class NuevoClientePage extends StatefulWidget {
  const NuevoClientePage({super.key});

  @override
  State<NuevoClientePage> createState() => _NuevoClientePageState();
}

class _NuevoClientePageState extends State<NuevoClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nuevoCliente = Cliente(
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );
      // CREATE: Firestore asigna el id automáticamente.
      await ClienteService().crearCliente(nuevoCliente);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
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
      appBar: AppBar(title: const Text('Nuevo Cliente'), elevation: 0),
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

                  Text(
                    'Información de Contacto',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: responsive.hp(3)),

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
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.person_add_alt_1_rounded,
          size: responsive.dp(5),
          color: theme.colorScheme.onPrimaryContainer,
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
        labelStyle: TextStyle(fontSize: responsive.dp(1.6)),
        prefixIcon: Icon(
          Icons.person_outline_rounded,
          color: theme.colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingresa el nombre del cliente';
        }
        if (value.trim().length < 3) {
          return 'El nombre debe tener al menos 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _campoTelefono(Responsive responsive, ThemeData theme) {
    return TextFormField(
      controller: _telefonoController,
      keyboardType: TextInputType.phone,
      style: TextStyle(fontSize: responsive.dp(1.6)),
      decoration: InputDecoration(
        labelText: 'Número de teléfono (Opcional)',
        labelStyle: TextStyle(fontSize: responsive.dp(1.6)),
        prefixIcon: Icon(
          Icons.phone_outlined,
          color: theme.colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      // Validación opcional
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          // Expresión regular simple para validar que solo haya números y símbolos de teléfono (+ o espacios)
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
            icon: const Icon(Icons.save_rounded),
            label: Text(
              'Guardar Cliente',
              style: TextStyle(
                fontSize: responsive.dp(1.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _guardarCliente,
          );
  }
}
