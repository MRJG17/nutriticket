import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart'; // Importamos la siguiente pantalla

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _dobController =
      TextEditingController(); // Date of Birth

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _lastnameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // ✅ NUEVA FUNCIÓN PARA MOSTRAR EL CALENDARIO
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1920), // El usuario más viejo que permitimos
      lastDate: DateTime.now(), // No se pueden seleccionar fechas futuras
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      setState(() {
        // Formateamos la fecha a DD/MM/AAAA
        _dobController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _registerUser() async {
    // --- La lógica de registro no cambia ---
    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Las contraseñas no coinciden."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Cuenta creada. ¡Ahora completa tu perfil!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserProfileScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Ocurrió un error al registrar.";
      if (e.code == 'weak-password') {
        errorMessage =
            'La contraseña es demasiado débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Ya existe una cuenta con ese correo electrónico.';
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
    final screenSize = MediaQuery.of(context).size;
    final double logoSize = screenSize.width * 0.3;
    final double socialIconRadius = screenSize.width * 0.06;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 150,
                  maxWidth: 150,
                ),
                child: Image.asset('assets/images/logo.png', height: logoSize),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                  label: 'Nombre',
                  prefixIcon:
                      const Icon(Icons.person_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _lastnameController,
                decoration: _buildInputDecoration(
                  label: 'Apellido',
                  prefixIcon:
                      const Icon(Icons.person_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),
              // ✅ CAMPO DE CORREO CON ICONO
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  label: 'Correo Electrónico',
                  prefixIcon:
                      const Icon(Icons.email_outlined, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _dobController,
                decoration: _buildInputDecoration(
                  label: 'Fecha de Nacimiento',
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.grey,
                  ),
                ),
                readOnly: true, // Para evitar que se abra el teclado
                onTap: _selectDate, // Llama a nuestra función al tocar
              ),
              const SizedBox(height: 15),
              // ✅ CAMPO DE CONTRASEÑA CON ICONO
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _buildInputDecoration(
                  label: 'Contraseña',
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),
              // ✅ CAMPO DE CONFIRMAR CONTRASEÑA CON ICONO
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: _buildInputDecoration(
                  label: 'Confirmar Contraseña',
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Crear Cuenta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '— O regístrate con —',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: CircleAvatar(
                      radius: socialIconRadius.clamp(25.0, 35.0),
                      backgroundColor: Colors.transparent,
                      child: Image.asset('assets/images/google.png'),
                    ),
                  ),
                  const SizedBox(width: 30),
                  GestureDetector(
                    onTap: () {},
                    child: CircleAvatar(
                      radius: socialIconRadius.clamp(25.0, 35.0),
                      backgroundColor: Colors.transparent,
                      child: Image.asset('assets/images/facebook.png'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FUNCIÓN DE AYUDA MODIFICADA PARA ACEPTAR ICONOS PREFIJO Y SUFIJO
  InputDecoration _buildInputDecoration({
    required String label,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[200],
      suffixIcon: suffixIcon,
    );
  }
}
