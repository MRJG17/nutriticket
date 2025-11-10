// lib/recipe_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Importar Auth

class RecipeDetailScreen extends StatelessWidget {
  // Recibimos el texto plano de la receta completa generado por Gemini
  final String recipeContent;
  final String recipeTitle;
  
  // ⭐️ CAMPOS NECESARIOS PARA GUARDAR LA REFERENCIA ⭐️
  final String recipeId;
  final int currentServings;
  final String currentDiet;

  const RecipeDetailScreen({
    super.key,
    required this.recipeContent,
    required this.recipeTitle,
    // ⭐️ Los datos de referencia de la receta original ⭐️
    required this.recipeId,
    required this.currentServings,
    required this.currentDiet,
  });

  // Función auxiliar para formatear y mostrar el contenido de Gemini
  List<Widget> _buildContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Detectar Títulos/Encabezados (Ingredientes, Pasos, etc.)
      if (trimmedLine.toUpperCase().contains('INGREDIENTES') || 
          trimmedLine.toUpperCase().contains('PASOS') ||
          trimmedLine.toUpperCase().contains('PREPARACIÓN') ||
          trimmedLine.toUpperCase().contains('INSTRUCCIONES')) 
      {
        widgets.add(const SizedBox(height: 12));
        widgets.add(
          Text(
            trimmedLine,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        );
        widgets.add(const Divider(color: Colors.green, thickness: 1));
      } else {
        // Contenido regular (descripción, lista de pasos o ingredientes)
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              trimmedLine,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        );
      }
    }
    return widgets;
  }
  
  // ⭐️ FUNCIÓN PARA GUARDAR FAVORITO EN FIRESTORE ⭐️
  Future<void> _saveFavoriteRecipe(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar favoritos.')),
      );
      return;
    }

    try {
  // 1. OBTENER EL USUARIO ACTUAL
  final user = FirebaseAuth.instance.currentUser;
  
  // 2. VERIFICACIÓN DE SEGURIDAD
  if (user == null) {
    // Esto no debería suceder si el usuario está en HomeScreen/RecipeDetailScreen,
    // pero es una buena práctica.
    throw Exception("Usuario no autenticado.");
  }

  // 3. ESTRUCTURA DE GUARDADO RECOMENDADA (Subcolección de favoritos)
  // Ruta: userFavorites/{uid}/favorites/{recipeId}
  await FirebaseFirestore.instance
      .collection('userFavorites') // Colección principal
      .doc(user.uid)                 // Documento del usuario (USAMOS EL UID AQUÍ)
      .collection('favorites')      // Subcolección de las recetas guardadas
      .doc(recipeId)                // Documento de la receta (usamos el ID de la receta para evitar duplicados)
      .set({
        // Datos a guardar
        'recipeId': recipeId, 
        'savedServings': currentServings, 
        'savedDiet': currentDiet, 
        'savedAt': FieldValue.serverTimestamp(), 
        // Puedes agregar aquí el contenido completo de la receta adaptada si lo deseas:
        // 'adaptedContent': widget.recipeContent,
      });

  // Éxito
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Receta guardada en tu catálogo personal!')),
  );
  Navigator.pop(context);

} catch (e) {
      print("Error al guardar favorito: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayTitle = recipeTitle.contains(':') ? recipeTitle.split(':').first.trim() : recipeTitle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Receta Adaptada'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green),
            ),
            // Muestra las raciones y la dieta guardada
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
              child: Text(
                'Adaptada para $currentServings raciones ($currentDiet)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ),
            const Divider(height: 20),
            
            // Contenido Formateado
            ..._buildContent(recipeContent),
            
            const SizedBox(height: 40),
            
            // ⭐️ Botón 'Aceptar y Guardar Receta' (Llama a la función de guardado) ⭐️
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveFavoriteRecipe(context), 
                icon: const Icon(Icons.favorite, color: Colors.white),
                label: const Text('Aceptar y Guardar Receta', style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}