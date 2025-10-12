import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // Controladores de valores numéricos
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Variables de estado para los selectores
  String? _selectedGender; // null, 'Hombre', o 'Mujer'
  String _heightUnit = 'cm'; // 'cm' o 'ft'
  String _weightUnit = 'kg'; // 'kg' o 'lbs'

  // --- Lógica de Conversión de Unidades (Sin cambios) ---
  double _convertToCm(double value, String unit) {
    if (unit == 'cm') return value;
    return value * 30.48;
  }

  double _convertToKg(double value, String unit) {
    if (unit == 'kg') return value;
    return value * 0.453592;
  }
  // ----------------------------------------

  // Función para guardar los datos en Cloud Firestore
  Future<void> _saveProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Manejar error si el usuario no está logueado
      return;
    }

    if (_selectedGender == null ||
        _heightController.text.trim().isEmpty ||
        _weightController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Por favor, completa todos los campos."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final double rawHeight =
        double.tryParse(_heightController.text.trim()) ?? 0.0;
    final double rawWeight =
        double.tryParse(_weightController.text.trim()) ?? 0.0;

    final double heightInCm = _convertToCm(rawHeight, _heightUnit);
    final double weightInKg = _convertToKg(rawWeight, _weightUnit);

    Map<String, dynamic> userData = {
      'uid': user.uid,
      'gender': _selectedGender,
      'heightCm': heightInCm,
      'weightKg': weightInKg,
      'heightUnitPreference': _heightUnit,
      'weightUnitPreference': _weightUnit,
      'hasCompletedProfile': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      _navigateToHome();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Error al guardar los datos."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se añade para el tamaño responsivo del logo
    final screenSize = MediaQuery.of(context).size;
    final double logoSize = screenSize.width * 0.3;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ INICIO DE LA MODIFICACIÓN: Logo y Título en el cuerpo
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 150,
                  maxWidth: 150,
                ),
                child: Image.asset('assets/images/logo.png', height: logoSize),
              ),
              const SizedBox(height: 20),
              const Text(
                'Completa tu Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 10),
              // ✅ FIN DE LA MODIFICACIÓN

              const Text(
                '¡Casi listo! Dinos un poco más sobre ti para personalizar tu experiencia.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Selector de Sexo
              DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  label: 'Sexo',
                  prefixIcon: const Icon(Icons.wc, color: Colors.grey),
                ),
                value: _selectedGender,
                hint: const Text('Selecciona tu sexo'),
                items: ['Hombre', 'Mujer']
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Estatura con Selector de Unidades
              TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: 'Estatura',
                  prefixIcon:
                      const Icon(Icons.straighten_outlined, color: Colors.grey),
                  suffixIcon:
                      _buildUnitSelector(['cm', 'ft'], _heightUnit, (val) {
                    setState(() => _heightUnit = val);
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // Peso con Selector de Unidades
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: 'Peso',
                  prefixIcon: const Icon(Icons.monitor_weight_outlined,
                      color: Colors.grey),
                  suffixIcon:
                      _buildUnitSelector(['kg', 'lbs'], _weightUnit, (val) {
                    setState(() => _weightUnit = val);
                  }),
                ),
              ),
              const SizedBox(height: 40),

              // Botón para Guardar y Continuar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfileData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Guardar y Continuar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botón para Omitir / Saltar
              TextButton(
                onPressed: _navigateToHome,
                child: const Text(
                  'Omitir por ahora',
                  style: TextStyle(
                      color: Color(0xFF4CAF50),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget de ayuda para construir la decoración de los inputs
  InputDecoration _buildInputDecoration(
      {required String label, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[200],
    );
  }

  // Widget de ayuda para el selector de unidades
  Widget _buildUnitSelector(
      List<String> units, String currentValue, ValueChanged<String> onChanged) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: currentValue,
        items: units
            .map((String unit) =>
                DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }
}
