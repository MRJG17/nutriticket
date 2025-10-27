import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. Importar Firestore
import 'package:intl/intl.dart'; // 2. Importar Intl para fechas
import 'edit_profile_screen.dart'; // 3. Importar la nueva pantalla de edición

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 4. Añadir FormKey, isLoading y selectedDate
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  DateTime? _selectedDateOfBirth;

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

  /// 5. Actualizar _selectDate para que guarde el objeto DateTime
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 20), // Fecha inicial sugerida
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked; // Guardar el DateTime
        _dobController.text =
            DateFormat('dd/MM/yyyy').format(picked); // Formatear texto
      });
    }
  }

  /// 6. Actualizar _registerUser para guardar en Firestore
  Future<void> _registerUser() async {
    // Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // No es necesario un check de contraseñas aquí, el validador del campo lo hace

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Crear usuario en Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Guardar datos iniciales en Firestore
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;

        Map<String, dynamic> initialUserData = {
          'uid': uid,
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'lastName': _lastnameController.text.trim(),
          'dateOfBirth': _selectedDateOfBirth != null
              ? Timestamp.fromDate(_selectedDateOfBirth!)
              : null,
          'createdAt': FieldValue.serverTimestamp(),
          // Valores por defecto para el resto del perfil
          'gender': 'No especificar',
          'heightCm': 0.0,
          'weightKg': 0.0,
          'dietaryPreferences': 'Ninguna',
          'householdSize': 1,
          'photoUrl': '',
          'hasCompletedProfile': false, // Importante
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(initialUserData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Cuenta creada. ¡Ahora completa tu perfil!"),
            backgroundColor: Colors.green,
          ),
        );

        // 3. Navegar a EditProfileScreen para completar el perfil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Ocurrió un error al registrar.";
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Ya existe una cuenta con ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El correo electrónico no es válido.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
          // 7. Envolver la Columna en un Form
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 150,
                    maxWidth: 150,
                  ),
                  child:
                      Image.asset('assets/images/logo.png', height: logoSize),
                ),
                const SizedBox(height: 30),
                // 8. Convertir TextFields a TextFormField y añadir validadores
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration(
                    label: 'Nombre',
                    prefixIcon:
                        const Icon(Icons.person_outline, color: Colors.grey),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Campo requerido'
                      : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _lastnameController,
                  decoration: _buildInputDecoration(
                    label: 'Apellido',
                    prefixIcon:
                        const Icon(Icons.person_outline, color: Colors.grey),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Campo requerido'
                      : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration(
                    label: 'Correo Electrónico',
                    prefixIcon:
                        const Icon(Icons.email_outlined, color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _dobController,
                  decoration: _buildInputDecoration(
                    label: 'Fecha de Nacimiento',
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.grey,
                    ),
                  ),
                  readOnly: true,
                  onTap: _selectDate,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Campo requerido'
                      : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _buildInputDecoration(
                    label: 'Contraseña',
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: _buildInputDecoration(
                    label: 'Confirmar Contraseña',
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  // 9. Manejar el estado de carga del botón
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Crear Cuenta',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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
                      onTap: () {
                        // TODO: Implementar Google Sign-In
                      },
                      child: CircleAvatar(
                        radius: socialIconRadius.clamp(25.0, 35.0),
                        backgroundColor: Colors.transparent,
                        child: Image.asset('assets/images/google.png'),
                      ),
                    ),
                    const SizedBox(width: 30),
                    GestureDetector(
                      onTap: () {
                        // TODO: Implementar Facebook Sign-In
                      },
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
      ),
    );
  }

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
      // Añadir bordes de error y foco para la validación
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
    );
  }
}
