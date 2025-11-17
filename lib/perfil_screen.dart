// lib/perfil_screen.dart

import 'dart:async'; // IMPORTAR ASYNC para StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nutriticket/edit_profile_screen.dart';
import 'package:nutriticket/main.dart';
import 'package:nutriticket/login_screen.dart';
import 'package:nutriticket/register_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true; // Empezamos como true

  // VARIABLE PARA LA SUSCRIPCIÓN
  StreamSubscription<User?>? _authSubscription;

  // Lista de avatares
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

  // MODIFICAR initState() PARA ESCUCHAR CAMBIOS
  @override
  void initState() {
    super.initState();

    // Nos suscribimos a los cambios de estado de autenticación
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return; // Asegurarse que el widget todavía existe

      setState(() {
        _currentUser = user; // Actualiza el usuario actual

        if (user != null && !user.isAnonymous) {
          // Si es un usuario real, mostramos carga y buscamos sus datos
          _isLoading = true;
          _userData = null; // Limpiamos datos antiguos
          _fetchUserData(); // Buscamos los nuevos datos
        } else {
          // Si es un invitado o nulo, simplemente dejamos de cargar
          _isLoading = false;
          _userData = null;
        }
      });
    });
  }

  // AÑADIR dispose() PARA LIMPIAR LA SUSCRIPCIÓN
  @override
  void dispose() {
    _authSubscription?.cancel(); // Cancela el "oyente" para evitar errores
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    // Esta función ya es segura porque _currentUser es actualizado por el listener
    if (_currentUser == null || _currentUser!.isAnonymous) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      // El print está bien para depuración
      print("Error en fetchUserData: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- FUNCIÓN DE LOGOUT ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (_) => false,
      );
    }
  }

  // --- ✅ INICIO DE FUNCIONES AUXILIARES COMPLETAS ---

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
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 1.3,
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
      return Transform.scale(
        scale: 1.3,
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
        ),
      );
    }
    // Caso por defecto si la URL no es http ni assets
    return Icon(
      Icons.person,
      size: radius * 1.15,
      color: Colors.grey.shade600,
    );
  }

  // --- ✅ FIN DE FUNCIONES AUXILIARES ---

  @override
  Widget build(BuildContext context) {
    // Ahora el build reaccionará automáticamente a _isLoading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- LÓGICA DE VISTA (INVITADO VS. USUARIO) ---
    if (_currentUser == null || _currentUser!.isAnonymous) {
      return _buildGuestScreen(context);
    }

    // --- PERFIL DE USUARIO LOGUEADO ---
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
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
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
                    GestureDetector(
                      onTap: _showAvatarSelectionDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
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

  // --- WIDGET DE INVITADO ---
  Widget _buildGuestScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitado'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_pin,
                size: 100,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 20),
              const Text(
                'Estás en Modo Invitado',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Inicia sesión o regístrate para guardar tu perfil y sincronizar tus recetas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Crear una Cuenta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ✅ INICIO DE WIDGETS AUXILIARES COMPLETOS ---

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
    // Agregué la verificación !mounted aquí
    if (!mounted) return;
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
  // --- ✅ FIN DE WIDGETS AUXILIARES ---
}
