// lib/recetas_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutriticket/recipe.dart';
import 'package:nutriticket/recipe_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecetasScreen extends StatefulWidget {
  const RecetasScreen({super.key});

  @override
  State<RecetasScreen> createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen> {
  // Estados para controlar la vista
  bool _isGridView = false; // false = Lista, true = Cuadrícula
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  String _filterDiet = "Todas"; // Filtro simple

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- STREAM DE DATOS ---
  Stream<List<Map<String, dynamic>>> _loadFavoritesStream(String userId) {
    final firestore = FirebaseFirestore.instance;
    final favoritesCollectionRef = firestore
        .collection('userFavorites')
        .doc(userId)
        .collection('favorites');

    final favoritesStream =
        favoritesCollectionRef.orderBy('savedAt', descending: true).snapshots();

    return favoritesStream.asyncMap((favoriteSnapshot) async {
      final List<Future<Map<String, dynamic>?>> futures =
          favoriteSnapshot.docs.map((favDoc) async {
        final favData = favDoc.data();
        final recipeId = favData['recipeId'] as String?;

        if (recipeId == null || recipeId.isEmpty) return null;

        final recipeDoc =
            await firestore.collection('recipes').doc(recipeId).get();

        if (recipeDoc.exists && recipeDoc.data() != null) {
          final Recipe originalRecipe =
              Recipe.fromMap(recipeDoc.data()!, recipeDoc.id);

          // ⭐️ CORRECCIÓN: Ahora incluimos la descripción al principio
          // Usamos las palabras clave exactas (DESCRIPCIÓN, INGREDIENTES, INSTRUCCIONES)
          // para que el RecipeDetailScreen las detecte y ponga las cajas verdes.
          final String originalContent =
              'DESCRIPCIÓN:\n${originalRecipe.description}\n\n' +
                  'INGREDIENTES (${originalRecipe.baseServings} porciones):\n' +
                  originalRecipe.ingredients
                      .map((i) => '* ${i.name}: ${i.quantity} ${i.unit}')
                      .join('\n') +
                  '\n\nINSTRUCCIONES:\n' +
                  originalRecipe.instructions;

          return {
            'recipe': originalRecipe,
            'originalContent': originalContent,
            'savedServings':
                favData['savedServings'] as int? ?? originalRecipe.baseServings,
            'savedDiet': favData['savedDiet'] as String? ?? 'Ninguna',
            'favoriteId': favDoc.id,
          };
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      return results.whereType<Map<String, dynamic>>().toList();
    });
  }

  // --- NAVEGACIÓN ---
  void _navigateToRecipeDetail(
      BuildContext context, Map<String, dynamic> detail) {
    final Recipe recipe = detail['recipe'];
    final String content = detail['originalContent'];
    final String recipeId = recipe.id;
    final int servings = detail['savedServings'];
    final String diet = detail['savedDiet'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(
          recipeTitle: recipe.title,
          recipeContent: content,
          recipeId: recipeId,
          currentServings: servings,
          currentDiet: diet,
          imageUrl: recipe.imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          'Recetas Favoritas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // BARRA DE HERRAMIENTAS
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchText = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Buscar receta...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[100], shape: BoxShape.circle),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.filter_list,
                        color: _filterDiet == "Todas"
                            ? Colors.grey[600]
                            : const Color(0xFF4CAF50)),
                    onSelected: (value) => setState(() => _filterDiet = value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'Todas', child: Text('Todas')),
                      const PopupMenuItem(
                          value: 'Vegetariana', child: Text('Vegetariana')),
                      const PopupMenuItem(
                          value: 'Vegana', child: Text('Vegana')),
                      const PopupMenuItem(value: 'Keto', child: Text('Keto')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[100], shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view,
                        color: const Color(0xFF4CAF50)),
                    onPressed: () => setState(() => _isGridView = !_isGridView),
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO
          Expanded(
            child: user == null
                ? const Center(child: Text('Inicia sesión para ver recetas.'))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _loadFavoritesStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF4CAF50)));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final favorites = snapshot.data ?? [];
                      final filteredFavorites = favorites.where((detail) {
                        final Recipe r = detail['recipe'];
                        final matchText =
                            r.title.toLowerCase().contains(_searchText);
                        final savedDiet = detail['savedDiet'] as String;
                        final matchDiet = _filterDiet == "Todas" ||
                            savedDiet == _filterDiet ||
                            r.tags.any((t) => t == _filterDiet);
                        return matchText && matchDiet;
                      }).toList();

                      if (filteredFavorites.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant_menu,
                                  size: 60, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              const Text('No se encontraron recetas.',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return _isGridView
                          ? _buildGridView(filteredFavorites)
                          : _buildListView(filteredFavorites);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- VISTA DE LISTA ---
  Widget _buildListView(List<Map<String, dynamic>> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final detail = favorites[index];
        final Recipe recipe = detail['recipe'];
        final int servings = detail['savedServings'];
        final String diet = detail['savedDiet'];

        return GestureDetector(
          onTap: () => _navigateToRecipeDetail(context, detail),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                // IMAGEN
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(15)),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: recipe.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: recipe.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.image,
                                    color: Colors.grey)),
                            errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey)),
                          )
                        : Container(
                            color: const Color(0xFFE8F5E9),
                            child: const Icon(Icons.restaurant,
                                color: Color(0xFF4CAF50)),
                          ),
                  ),
                ),
                // INFORMACIÓN
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.description.isNotEmpty
                              ? recipe.description
                              : 'Sin descripción disponible.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.people_outline,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('$servings',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.eco_outlined,
                                size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(diet,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- VISTA DE CUADRÍCULA ---
  Widget _buildGridView(List<Map<String, dynamic>> favorites) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final detail = favorites[index];
        final Recipe recipe = detail['recipe'];

        return GestureDetector(
          onTap: () => _navigateToRecipeDetail(context, detail),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: SizedBox(
                      width: double.infinity,
                      child: recipe.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: recipe.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                      child: Icon(Icons.image,
                                          color: Colors.grey))),
                              errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey))),
                            )
                          : Container(
                              color: const Color(0xFFE8F5E9),
                              child: const Center(
                                  child: Icon(Icons.restaurant,
                                      size: 40, color: Color(0xFF4CAF50))),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        recipe.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
