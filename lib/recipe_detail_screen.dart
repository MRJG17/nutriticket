// lib/recipe_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeDetailScreen extends StatelessWidget {
  final String recipeContent;
  final String recipeTitle;
  final String recipeId;
  final int currentServings;
  final String currentDiet;
  final String? imageUrl;

  const RecipeDetailScreen({
    super.key,
    required this.recipeContent,
    required this.recipeTitle,
    required this.recipeId,
    required this.currentServings,
    required this.currentDiet,
    this.imageUrl,
  });

  // --- LÓGICA MEJORADA DE PARSEO ---
  List<Widget> _parseContent(String content) {
    final List<Widget> widgets = [];
    final lines = content.split('\n');

    // Palabras clave que activan las cajas verdes
    final List<String> headerKeywords = [
      'INGREDIENTES',
      'PASOS',
      'PREPARACIÓN',
      'INSTRUCCIONES',
      'DESCRIPCIÓN' // Agregado Descripción
    ];

    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Limpieza básica
      trimmed = trimmed.replaceAll('**', '');

      bool isHeader = false;
      String headerText = "";
      String remainingText = "";

      // 1. Verificar si la línea EMPIEZA con una palabra clave
      for (final keyword in headerKeywords) {
        if (trimmed.toUpperCase().startsWith(keyword)) {
          isHeader = true;

          // Separar el título del contenido (ej: "DESCRIPCIÓN: Hola..." -> "DESCRIPCIÓN" y "Hola...")
          // Buscamos los dos puntos o el final de la palabra clave
          int splitIndex = trimmed.indexOf(':');

          if (splitIndex != -1) {
            headerText = trimmed.substring(0, splitIndex).trim();
            remainingText = trimmed.substring(splitIndex + 1).trim();
          } else {
            // Si no hay dos puntos, asumimos que toda la línea es el título (ej: "PASOS")
            // Pero si es muy larga, probablemente no sea solo un título
            if (trimmed.length < 30) {
              headerText = trimmed;
            } else {
              // Si es muy largo, no lo tratamos como header para evitar cajas verdes gigantes
              isHeader = false;
            }
          }
          break;
        }
      }

      if (isHeader) {
        // --- A. ES UN ENCABEZADO (Caja Verde) ---
        widgets.add(const SizedBox(height: 24));
        widgets.add(_buildSectionHeader(headerText));
        widgets.add(const SizedBox(height: 12));

        // Si había texto en la misma línea (ej: Descripción), lo ponemos abajo normal
        if (remainingText.isNotEmpty) {
          widgets.add(_buildNormalText(remainingText));
        }
      } else if (trimmed.startsWith('*') ||
          RegExp(r'^\d+\.').hasMatch(trimmed)) {
        // --- B. ES UNA LISTA (Ingrediente o Paso) ---
        // Limpiamos el asterisco inicial si existe
        String cleanLine =
            trimmed.startsWith('*') ? trimmed.substring(1).trim() : trimmed;
        widgets.add(_buildListItem(cleanLine));
      } else {
        // --- C. TEXTO NORMAL ---
        widgets.add(_buildNormalText(trimmed));
      }
    }
    return widgets;
  }

  // Widget auxiliar para la Caja Verde (Encabezado)
  Widget _buildSectionHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu, color: Color(0xFF4CAF50)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para Items de lista (con puntito verde)
  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 16, height: 1.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para texto normal
  Widget _buildNormalText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800]),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Future<void> _saveFavoriteRecipe(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid)
          .collection('favorites')
          .doc(recipeId)
          .set({
        'recipeId': recipeId,
        'savedServings': currentServings,
        'savedDiet': currentDiet,
        'savedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Receta guardada en favoritos')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayTitle = recipeTitle.replaceAll('**', '').trim();
    if (displayTitle.endsWith(':')) {
      displayTitle = displayTitle.substring(0, displayTitle.length - 1);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // --- CABECERA ---
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4CAF50),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              // ⭐️ CORRECCIÓN 1: Aumentamos el padding izquierdo a 56 para librar la flecha
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              centerTitle: false,
              title: Text(
                displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                  shadows: [
                    Shadow(
                        color: Colors.black87,
                        blurRadius: 8.0,
                        offset: Offset(0, 2))
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[300]),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF4CAF50),
                            child: const Icon(Icons.restaurant,
                                size: 80, color: Colors.white54),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF4CAF50),
                          child: const Icon(Icons.restaurant,
                              size: 80, color: Colors.white54),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- CONTENIDO ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E3A59)),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildInfoChip(Icons.people, '$currentServings raciones'),
                      _buildInfoChip(Icons.restaurant_menu, currentDiet),
                    ],
                  ),
                  const Divider(height: 30),

                  // Contenido Inteligente
                  ..._parseContent(recipeContent),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveFavoriteRecipe(context),
                      icon: const Icon(Icons.favorite, color: Colors.white),
                      label: const Text(
                        'Guardar Receta',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
