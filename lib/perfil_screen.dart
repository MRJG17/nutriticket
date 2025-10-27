// lib/perfil_screen.dart

// 1. MODIFICACIÓN: Se eliminan imports que ya no se usan (dart:io y image_picker)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nutriticket/edit_profile_screen.dart'; // Importa la pantalla de edición
import 'package:nutriticket/main.dart'; // Para el AuthWrapper

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // Asegúrate que esta ruta sea la correcta en tu pubspec.yaml
  final List<String> _avatarList = [
    'assets/avatars/a1.png',
    'assets/avatars/a2.png',
    'assets/avatars/a3.png',
    'assets/avatars/a4.png',
    'assets/avatars/a5.png',
    'assets/avatars/a6.png',
    'assets/avatars/a7.png',
    'assets/avatars/a8.png',
  ];

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
        if (mounted) {
          setState(() {
            _isLoading = false;
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

  // 2. MODIFICACIÓN: Se elimina la función _pickAndUploadImage()
  // Ya no la necesitamos, la hemos borrado.

  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Elige tu Avatar'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _avatarList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final assetPath = _avatarList[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateProfileWithAvatar(assetPath);
                  },
                  // 3. MODIFICACIÓN: Se añade Transform.scale para hacer "zoom"
                  child: ClipOval(
                    child: Transform.scale(
                      scale:
                          1.3, // <-- ¡Este es el "zoom"! Ajusta si es necesario
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            )
          ],
        );
      },
    );
  }

  Future<void> _updateProfileWithAvatar(String assetPath) async {
    if (_currentUser == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'photoUrl': assetPath}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _userData ??= {};
          _userData!['photoUrl'] = assetPath;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Avatar actualizado.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _getDisplayImageWidget(String url, double radius) {
    if (url.isEmpty) {
      return Icon(
        Icons.person,
        size: radius * 1.15,
        color: Colors.grey.shade600,
      );
    }
    if (url.startsWith('http')) {
      // Es una foto subida (URL de Firebase Storage)
      // Mantenemos esta lógica por si el usuario ya tenía una foto de antes
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image,
          size: radius * 1.15,
          color: Colors.grey.shade400,
        ),
      );
    }
    if (url.startsWith('assets/')) {
      // Es un avatar local
      // 3. MODIFICACIÓN: Se añade Transform.scale también aquí
      return Transform.scale(
        scale: 1.3, // <-- ¡Este es el "zoom"!
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
        ),
      );
    }
    return Icon(
      Icons.person,
      size: radius * 1.15,
      color: Colors.grey.shade600,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final userData = _userData ?? {};

    final dob = (userData['dateOfBirth'] != null)
        ? (userData['dateOfBirth'] as Timestamp).toDate()
        : null;
    final String age = _calculateAge(dob);

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

    const double avatarRadius = 70;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _fetchUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: _showAvatarSelectionDialog,
                      child: Container(
                        width: avatarRadius * 2,
                        height: avatarRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade300,
                        ),
                        child: ClipOval(
                          child: _getDisplayImageWidget(photoUrl, avatarRadius),
                        ),
                      ),
                    ),
                    // 4. MODIFICACIÓN: Icono y acción del botón
                    GestureDetector(
                      onTap: _showAvatarSelectionDialog, // <-- CAMBIADO
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined, // <-- CAMBIADO
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  displayName.trim(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // ... (El resto del código de Cards, botones, etc. no cambia)
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (!mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
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

  Future<void> _showDeleteAccountDialog() async {
    final BuildContext dialogContext = context;

    return showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();

                if (_currentUser == null) return;

                if (!mounted) return;
                setState(() => _isLoading = true);

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .delete();

                  final photoUrl = _userData?['photoUrl'] as String?;
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    if (photoUrl.startsWith('http')) {
                      final ref = FirebaseStorage.instance.refFromURL(photoUrl);
                      await ref.delete();
                    }
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
