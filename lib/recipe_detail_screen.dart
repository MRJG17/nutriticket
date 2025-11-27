// lib/recipe_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeDetailScreen extends StatefulWidget {
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

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.recipeId)
          .get();

      if (mounted) {
        setState(() {
          _isFavorite = doc.exists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para guardar recetas')),
      );
      return;
    }

    setState(() => _isFavorite = !_isFavorite);

    final ref = FirebaseFirestore.instance
        .collection('userFavorites')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.recipeId);

    try {
      if (_isFavorite) {
        await ref.set({
          'recipeId': widget.recipeId,
          'savedServings': widget.currentServings,
          'savedDiet': widget.currentDiet,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('❤️ Receta guardada en favoritos'),
                duration: Duration(seconds: 1)),
          );
        }
      } else {
        await ref.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('💔 Receta eliminada de favoritos'),
                duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // --- ⭐️ LÓGICA CORREGIDA: Detectar sección para separar pasos ⭐️ ---
  List<Widget> _parseContent(String content) {
    final List<Widget> widgets = [];

    // Dividimos por líneas. No aplicamos ningún regex global que borre texto.
    final lines = content.split('\n');

    final List<String> headerKeywords = [
      'INGREDIENTES',
      'PASOS',
      'PREPARACIÓN',
      'INSTRUCCIONES',
      'DESCRIPCIÓN'
    ];

    // Solo en estas secciones buscaremos separar los números
    final List<String> stepsKeywords = [
      'PASOS',
      'PREPARACIÓN',
      'INSTRUCCIONES'
    ];

    bool isStepSection =
        false; // Bandera para saber si estamos en zona de pasos

    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Limpiamos negritas del markdown si las hay
      trimmed = trimmed.replaceAll('**', '');

      bool isHeader = false;
      String headerText = "";
      String remainingText = "";

      // 1. Verificar si la línea es un Encabezado (Titulo)
      for (final keyword in headerKeywords) {
        if (trimmed.toUpperCase().startsWith(keyword)) {
          isHeader = true;

          // Activamos la bandera SOLO si es una sección de pasos
          if (stepsKeywords.contains(keyword)) {
            isStepSection = true;
          } else {
            isStepSection =
                false; // Si es Ingredientes o Descripción, apagamos la bandera
          }

          int splitIndex = trimmed.indexOf(':');
          if (splitIndex != -1) {
            headerText = trimmed.substring(0, splitIndex).trim();
            remainingText = trimmed.substring(splitIndex + 1).trim();
          } else {
            if (trimmed.length < 30) {
              headerText = trimmed;
            } else {
              isHeader = false;
            }
          }
          break;
        }
      }

      if (isHeader) {
        // --- A. ES UN TÍTULO ---
        widgets.add(const SizedBox(height: 24));
        widgets.add(_buildSectionHeader(headerText));
        widgets.add(const SizedBox(height: 12));

        // Si hay texto en la misma línea del título
        if (remainingText.isNotEmpty) {
          if (isStepSection) {
            _processStepText(remainingText, widgets);
          } else {
            widgets.add(_buildNormalText(remainingText));
          }
        }
      } else {
        // --- B. ES CONTENIDO ---
        if (isStepSection) {
          // ⭐️ SOLO AQUÍ aplicamos la separación de números
          _processStepText(trimmed, widgets);
        } else {
          // Comportamiento normal para Ingredientes y Descripción
          if (trimmed.startsWith('*') || RegExp(r'^\d+\.').hasMatch(trimmed)) {
            String cleanLine =
                trimmed.startsWith('*') ? trimmed.substring(1).trim() : trimmed;
            widgets.add(_buildListItem(cleanLine));
          } else {
            widgets.add(_buildNormalText(trimmed));
          }
        }
      }
    }
    return widgets;
  }

  // ⭐️ HELPER INTELIGENTE ⭐️
  void _processStepText(String text, List<Widget> widgets) {
    // Regex explicada:
    // (\s+)   -> Busca un espacio antes del número (o inicio de línea)
    // (\d+\.) -> Busca el número y el punto (ej: "2.")
    // (?!\d)  -> Asegura que NO haya otro dígito después (evita romper "2.5")
    String formatted = text.replaceAllMapped(
        RegExp(r'(\s+)(\d+\.)(?!\d)'), (match) => '\n${match.group(2)} ');

    final subLines = formatted.split('\n');
    for (var sub in subLines) {
      if (sub.trim().isNotEmpty) {
        // Usamos el diseño de lista (puntito verde)
        widgets.add(_buildListItem(sub.trim()));
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    String displayTitle = widget.recipeTitle.replaceAll('**', '').trim();
    if (displayTitle.endsWith(':')) {
      displayTitle = displayTitle.substring(0, displayTitle.length - 1);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4CAF50),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(right: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                        size: 28,
                      ),
                      onPressed: _toggleFavorite,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
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
                  widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
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
                      _buildInfoChip(
                          Icons.people, '${widget.currentServings} raciones'),
                      _buildInfoChip(Icons.restaurant_menu, widget.currentDiet),
                    ],
                  ),
                  const Divider(height: 30),

                  // Contenido Inteligente
                  ..._parseContent(widget.recipeContent),

                  const SizedBox(height: 40),
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
