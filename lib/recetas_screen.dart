// lib/recetas_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutriticket/recipe.dart'; 
import 'package:nutriticket/recipe_detail_screen.dart'; 

class RecetasScreen extends StatelessWidget {
  const RecetasScreen({super.key});

  // FUNCIÓN PRINCIPAL PARA CARGAR FAVORITOS (Ruta Corregida)
  Stream<List<Map<String, dynamic>>> _loadFavoritesStream(String userId) {
    final firestore = FirebaseFirestore.instance;

    // RUTA AUTORIZADA: userFavorites/{userId}/favorites
    final favoritesCollectionRef = firestore
        .collection('userFavorites') 
        .doc(userId)                  
        .collection('favorites');     

    // La consulta directa a la subcolección es la clave para la seguridad (PERMISSION_DENIED fix)
    final favoritesStream = favoritesCollectionRef
        .orderBy('savedAt', descending: true)
        .snapshots();

    // Procesa la instantánea de favoritos
    return favoritesStream.asyncMap((favoriteSnapshot) async {
      
      final List<Future<Map<String, dynamic>?>> futures = favoriteSnapshot.docs.map((favDoc) async {
        final favData = favDoc.data();
        final recipeId = favData['recipeId'] as String?;
        
        if (recipeId == null || recipeId.isEmpty) return null;

        // Obtener el documento de receta original de /recipes
        final recipeDoc = await firestore.collection('recipes').doc(recipeId).get();

        if (recipeDoc.exists && recipeDoc.data() != null) {
          final Recipe originalRecipe = Recipe.fromMap(recipeDoc.data()!, recipeDoc.id);
          
          // Creamos el contenido de la receta para el detalle
          final String originalContent = 
            '**INGREDIENTES ORIGINALES (${originalRecipe.baseServings} porciones):**\n' +
            originalRecipe.ingredients.map((i) => '* ${i.name}: ${i.quantity} ${i.unit}').join('\n') +
            '\n\n**INSTRUCCIONES:**\n' +
            originalRecipe.instructions;

          return {
            'recipe': originalRecipe,
            'originalContent': originalContent,
            'savedServings': favData['savedServings'] as int? ?? originalRecipe.baseServings,
            'savedDiet': favData['savedDiet'] as String? ?? 'Ninguna',
            'favoriteId': favDoc.id, 
          };
        }
        return null; // Retorna null si la receta original no existe
      }).toList();

      // Espera que todas las peticiones secundarias se completen y limpia los nulos
      final results = await Future.wait(futures);
      return results.whereType<Map<String, dynamic>>().toList(); 
    });
  }

  // FUNCIÓN DE NAVEGACIÓN
  void _navigateToRecipeDetail(BuildContext context, Map<String, dynamic> detail) {
    final Recipe recipe = detail['recipe'];
    final String content = detail['originalContent'];
    // ⭐️ OBTENEMOS LOS NUEVOS PARÁMETROS ⭐️
    final String recipeId = recipe.id; // Ya tienes el ID de la receta original
    final int servings = detail['savedServings'];
    final String diet = detail['savedDiet'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(
          recipeTitle: recipe.title,
          recipeContent: content, 
          // ⭐️ AGREGAR LOS PARÁMETROS REQUERIDOS ⭐️
          recipeId: recipeId,
          currentServings: servings,
          currentDiet: diet,
        ),
      ),
    );
}

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tus recetas guardadas.'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _loadFavoritesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar favoritos: ${snapshot.error}'));
        }
        
        final favorites = snapshot.data ?? [];
        
        if (favorites.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Aún no tienes recetas guardadas. ¡Escanea un ticket y guarda tus favoritas!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final detail = favorites[index];
            
            final Recipe recipe = detail['recipe'];
            final int servings = detail['savedServings'];
            final String diet = detail['savedDiet'];

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.restaurant, color: Colors.green),
                title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Raciones guardadas: $servings | Dieta: $diet'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToRecipeDetail(context, detail),
              ),
            );
          },
        );
      },
    );
  }
}