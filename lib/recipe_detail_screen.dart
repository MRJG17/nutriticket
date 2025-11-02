// lib/recipe_detail_screen.dart

import 'package:flutter/material.dart';

class RecipeDetailScreen extends StatelessWidget {
  // Recibimos el texto plano de la receta completa generada por Gemini
  final String recipeContent;
  final String recipeTitle;

  const RecipeDetailScreen({
    super.key,
    required this.recipeContent,
    required this.recipeTitle,
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
      } 
      // Detectar ítems de lista (usando guiones o puntos)
      else if (trimmedLine.startsWith('-') || trimmedLine.startsWith('•') || RegExp(r'^\d+\.').hasMatch(trimmedLine)) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
          child: Text(trimmedLine, style: const TextStyle(fontSize: 16)),
        ));
      } 
      // Texto normal (descripciones, notas)
      else {
        widgets.add(Text(trimmedLine, style: const TextStyle(fontSize: 16, height: 1.4)));
      }
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    String displayTitle = recipeTitle.contains(':') ? recipeTitle.split(':').first.trim() : recipeTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.lightGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recipeTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green),
            ),
            const Divider(height: 20),
            
            // Contenido Formateado
            ..._buildContent(recipeContent),
            
            const SizedBox(height: 40),
            // ⭐️ Botón de Aceptar/Guardar Receta ⭐️
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 💡 Implementación futura: Lógica para guardar la receta en el catálogo
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receta guardada en tu catálogo personal!')),
                  );
                  Navigator.pop(context); // Regresar a la lista
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('Aceptar y Guardar Receta', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
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