// lib/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  String? _selectedDietaryPreference;
  int? _selectedHouseholdSize;

  User? _currentUser;
  bool _isLoading = true;

  // 1. MODIFICACIÓN: Corregir las opciones de género para que coincidan con los datos
  final List<String> _genderOptions = [
    'Hombre',
    'Mujer',
    'Otro',
    'No especificar'
  ];
  final List<String> _dietaryOptions = [
    'Ninguna',
    'Vegetariana',
    'Vegana',
    'Sin Gluten',
    'Keto',
    'Paleo'
  ];
  final List<int> _householdSizes = [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
  }

  /// Carga los datos existentes del usuario desde Firestore
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        // Precargar los controladores de texto
        _nameController.text = data['name'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _heightController.text = data['heightCm']?.toStringAsFixed(0) ?? '';
        _weightController.text = data['weightKg']?.toStringAsFixed(1) ?? '';

        // Precargar la fecha de nacimiento
        if (data['dateOfBirth'] != null) {
          _selectedDateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
          _dateOfBirthController.text =
              DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!);
        }

        // Precargar los valores de los Dropdowns
        if (mounted) {
          setState(() {
            _selectedGender = data['gender'];
            _selectedDietaryPreference = data['dietaryPreferences'];
            _selectedHouseholdSize = data['householdSize'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar datos: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Muestra el selector de fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ??
          DateTime(
              DateTime.now().year - 20), // Fecha inicial (ej. 20 años atrás)
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  /// Guarda los datos actualizados del perfil en Firestore
  Future<void> _saveUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return; // Si el formulario no es válido, no hacer nada
    }
    if (_currentUser == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      double? heightCm = double.tryParse(_heightController.text.trim());
      double? weightKg = double.tryParse(_weightController.text.trim());

      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _selectedGender,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'dateOfBirth': _selectedDateOfBirth != null
            ? Timestamp.fromDate(_selectedDateOfBirth!)
            : null,
        'dietaryPreferences': _selectedDietaryPreference,
        'householdSize': _selectedHouseholdSize,
        'hasCompletedProfile': true, // Marcar el perfil como completado
      };

      // Usar .set con merge:true para crear o actualizar el documento
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perfil actualizado exitosamente.'),
              backgroundColor: Colors.green),
        );
        // Devolver 'true' para indicar éxito y refrescar la pantalla anterior
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar perfil: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Editar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(
            color: Colors.white), // Flecha de regreso blanca
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Sección Datos Personales ---
                    const Text('Datos Personales',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                        controller: _nameController,
                        label: 'Nombre',
                        icon: Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                        controller: _lastNameController,
                        label: 'Apellido',
                        icon: Icons.person_outline),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateOfBirthController,
                      readOnly: true, // Evita que se escriba manualmente
                      onTap: () => _selectDate(context),
                      decoration: _buildInputDecoration(
                          label: 'Fecha de Nacimiento',
                          icon: Icons.calendar_today_outlined),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Campo requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Sección Información de Salud ---
                    const Text('Información de Salud',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      // 2. MODIFICACIÓN: Usar initialValue para evitar warnings
                      initialValue: _selectedGender,
                      decoration: _buildInputDecoration(
                          label: 'Sexo', icon: Icons.wc_outlined),
                      items: _genderOptions
                          .map((gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                        controller: _heightController,
                        label: 'Estatura (cm)',
                        icon: Icons.straighten_outlined,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                        controller: _weightController,
                        label: 'Peso (kg)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 24),

                    // --- Sección Preferencias ---
                    const Text('Preferencias',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDietaryPreference,
                      decoration: _buildInputDecoration(
                          label: 'Tipo de Dieta',
                          icon: Icons.restaurant_menu_outlined),
                      items: _dietaryOptions
                          .map((diet) => DropdownMenuItem(
                                value: diet,
                                child: Text(diet),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDietaryPreference = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedHouseholdSize,
                      decoration: _buildInputDecoration(
                          label: 'Personas en Casa',
                          icon: Icons.groups_outlined),
                      items: _householdSizes
                          .map((size) => DropdownMenuItem(
                                value: size,
                                child: Text('$size persona(s)'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedHouseholdSize = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 30),

                    // --- Botón Guardar ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveUserProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar Cambios'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Helper para construir TextFormField estándar
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _buildInputDecoration(label: label, icon: icon),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Campo requerido';
        }
        if (keyboardType == TextInputType.number &&
            (double.tryParse(value) == null || double.parse(value) <= 0)) {
          return 'Ingresa un número válido';
        }
        return null;
      },
    );
  }

  /// Helper para construir la decoración de los Inputs
  InputDecoration _buildInputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  void dispose() {
    // Limpiar controladores
    _nameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }
}
