// lib/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart'; 

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores de texto existentes
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  
  // ⭐️ Nuevo: Variable para guardar la fecha seleccionada ⭐️
  DateTime? _selectedDate; 
  
  // ⭐️ Función para mostrar el selector de fecha ⭐️
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      // Inicia en el año 2000 si no hay fecha seleccionada
      initialDate: _selectedDate ?? DateTime(2000), 
      firstDate: DateTime(1900),
      // No se puede seleccionar una fecha futura
      lastDate: DateTime.now(), 
      // Si quieres forzar el español, asegúrate de que MaterialApp en main.dart lo soporte
      locale: const Locale('es', 'ES'), 
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  // Lógica de Registro con verificación de Fecha de Nacimiento
  Future<void> _registerUser() async {
    // Verificación de contraseñas
    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Las contraseñas no coinciden."), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    // ⭐️ NUEVA VERIFICACIÓN DE FECHA ⭐️
    if (_selectedDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Por favor, selecciona tu fecha de nacimiento."), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    
    try {
      // 1. Crear el usuario en Firebase Authentication
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      // 2. Si el registro es exitoso, navegar a la pantalla de Perfil
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Cuenta creada. ¡Ahora completa tu perfil!"), backgroundColor: Colors.green),
        );

        // 3. Navegar a la pantalla de información nutricional (UserProfileScreen)
        if (mounted) {
  // ⭐️ USAMOS PUSH AND REMOVE UNTIL ⭐️
  Navigator.pushAndRemoveUntil( 
    context,
    MaterialPageRoute(builder: (context) => const UserProfileScreen()),
    (Route<dynamic> route) => false, // Esta condición es la clave: siempre retorna false, eliminando todas las rutas anteriores.
  );
}
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Ocurrió un error al registrar.";
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Ya existe una cuenta con ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico es inválido.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 10),
            TextField(controller: _lastnameController, decoration: const InputDecoration(labelText: 'Apellido')),
            const SizedBox(height: 10),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Correo electrónico')),
            const SizedBox(height: 10),
            
            // ⭐️ CAMBIO: TextFormField con selector de fecha ⭐️
            TextFormField(
              // Muestra la fecha seleccionada o un texto por defecto
              controller: TextEditingController(
                text: _selectedDate == null 
                  ? '' 
                  // Formatea la fecha a dd/MM/yyyy
                  : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
              ),
              readOnly: true, // Evita que el usuario escriba
              onTap: () => _selectDate(context), // Llama al selector al hacer tap
              decoration: const InputDecoration(
                labelText: 'Fecha de Nacimiento',
                suffixIcon: Icon(Icons.calendar_today), // Ícono de calendario
              ),
            ),
            // FIN DEL CAMBIO
            
            const SizedBox(height: 10),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
            const SizedBox(height: 10),
            TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar Contraseña')),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _registerUser, child: const Text('Registrarse')),
          ],
        ),
      ),
    );
  }
}