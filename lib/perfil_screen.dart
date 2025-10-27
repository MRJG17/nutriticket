// lib/perfil_screen.dart

import 'dart:io'; // Necesario para File
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nutriticket/edit_profile_screen.dart'; // Importa la pantalla de edición
import 'package:nutriticket/main.dart'; // Para el AuthWrapper

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

// 1. MODIFICACIÓN: Asegúrate de que esta línea extienda "State<PerfilScreen>"
class _PerfilScreenState extends State<PerfilScreen> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
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
        if (mounted) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        // El documento no existe (ej. usuario recién registrado)
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Inicializar _userData vacío para evitar errores de null
            _userData = {};
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;
    if (_currentUser == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true; // Mostrar loading mientras se sube la imagen
      });
    }

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${_currentUser!.uid}.jpg');

      await ref.putData(await image.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'));

      final String downloadUrl = await ref.getDownloadURL();

      // Usar .set con merge:true para crear o actualizar el documento
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'photoUrl': downloadUrl}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          // Asegurarse de que _userData no sea null antes de asignarle la llave
          _userData ??= {};
          _userData!['photoUrl'] = downloadUrl;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto de perfil actualizada.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la foto: $e')),
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

  String _calculateAge(DateTime? dob) {
    if (dob == null) return 'No especificada';
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return '$age años';
  }

  // 1. MODIFICACIÓN: Eliminar el AppBar de este Scaffold
  @override
  Widget build(BuildContext context) {
    // Manejar el caso donde _userData aún es null después de cargar
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Asegurarse de que _userData no sea null para evitar errores
    final userData = _userData ?? {};

    final dob = (userData['dateOfBirth'] != null)
        ? (userData['dateOfBirth'] as Timestamp).toDate()
        : null;
    final String age = _calculateAge(dob);

    // Extraer datos de forma segura
    final String photoUrl = userData['photoUrl'] as String? ?? '';
    final String name = userData['name'] as String? ?? '';
    final String lastName = userData['lastName'] as String? ?? '';
    final String displayName = (name.isNotEmpty || lastName.isNotEmpty)
        ? '$name $lastName'
        : 'Usuario';
    final String gender = userData['gender'] as String? ?? 'No especificado';
    final String height = userData['heightCm']?.toStringAsFixed(0) ?? '0';
    final String weight = userData['weightKg']?.toStringAsFixed(1) ?? '0.0';
    final String diet = userData['dietaryPreferences'] as String? ?? 'Ninguna';
    final String household = userData['householdSize']?.toString() ?? '1';

    return Scaffold(
      // 2. MODIFICACIÓN: El AppBar se ha quitado
      backgroundColor: Colors.white, // Fondo blanco para la pantalla
      body: RefreshIndicator(
        onRefresh: _fetchUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20), // Espacio superior
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: (photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl) as ImageProvider<Object>?
                            : null,
                        child: (photoUrl.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.grey.shade600,
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  displayName.trim(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildProfileInfoRow(Icons.cake_outlined, 'Edad', age),
                        _buildProfileInfoRow(Icons.wc_outlined, 'Sexo', gender),
                        _buildProfileInfoRow(Icons.straighten_outlined,
                            'Estatura', '$height cm'),
                        _buildProfileInfoRow(Icons.monitor_weight_outlined,
                            'Peso', '$weight kg'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Sección de Preferencias
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Preferencias Alimentarias',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildProfileInfoRow(Icons.restaurant_menu_outlined,
                            'Tipo de Dieta', diet),
                        _buildProfileInfoRow(Icons.groups_outlined,
                            'Personas en Casa', household),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Botón para Modificar Datos
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // 3. MODIFICACIÓN: Comprobar si el widget está montado
                      if (!mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                      // Refrescar datos al regresar
                      if (result == true || result == null) {
                        _fetchUserData();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modificar Datos',
                        style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Botón para Eliminar Cuenta (Opcional)
                TextButton(
                  onPressed: () {
                    _showDeleteAccountDialog();
                  },
                  child: const Text(
                    'Eliminar Cuenta',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. MODIFICACIÓN: Corregir advertencias de 'use_build_context_synchronously'
  Future<void> _showDeleteAccountDialog() async {
    // Guardar el BuildContext en una variable
    final BuildContext dialogContext = context;

    return showDialog<void>(
      context: dialogContext,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        // Usar el BuildContext del builder del diálogo
        return AlertDialog(
          title: const Text('Eliminar Cuenta'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('¿Estás seguro de que quieres eliminar tu cuenta?'),
                Text('Esta acción es irreversible.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(); // Usar el context del builder
              },
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop(); // Usar el context del builder

                if (_currentUser == null) return;

                // Usar 'mounted' del State
                if (!mounted) return;
                setState(() => _isLoading = true);

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .delete();

                  final photoUrl = _userData?['photoUrl'] as String?;
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    final ref = FirebaseStorage.instance.refFromURL(photoUrl);
                    await ref.delete();
                  }

                  await _currentUser!.delete();

                  if (!mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Cuenta eliminada exitosamente.')),
                  );
                  Navigator.of(dialogContext).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      (route) => false);
                } on FirebaseAuthException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text(e.code == 'requires-recent-login'
                            ? 'Por seguridad, inicia sesión de nuevo antes de eliminar tu cuenta.'
                            : 'Error: ${e.message}')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
