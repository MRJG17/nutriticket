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

  // --- LÓGICA MEJORADA DE PARSEO ---
  List<Widget> _parseContent(String content) {
    // ⭐️ TRUCO NUEVO: Pre-formatear el texto
    // Buscamos números escondidos (ej: "mezclar. 2. cocinar") y les metemos un ENTER antes.
    // Regex: Busca un espacio seguido de un dígito y un punto, que NO esté al inicio de la línea.
    String formattedContent = content.replaceAllMapped(
      RegExp(r'(?<!^)(\s+)(\d+\.)'),
      (match) => '\n${match.group(2)}',
    );

    final List<Widget> widgets = [];
    final lines = formattedContent.split('\n');

    final List<String> headerKeywords = [
      'INGREDIENTES',
      'PASOS',
      'PREPARACIÓN',
      'INSTRUCCIONES',
      'DESCRIPCIÓN'
    ];

    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      trimmed = trimmed.replaceAll('**', '');

      bool isHeader = false;
      String headerText = "";
      String remainingText = "";

      for (final keyword in headerKeywords) {
        if (trimmed.toUpperCase().startsWith(keyword)) {
          isHeader = true;
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
        widgets.add(const SizedBox(height: 24));
        widgets.add(_buildSectionHeader(headerText));
        widgets.add(const SizedBox(height: 12));
        if (remainingText.isNotEmpty) {
          widgets.add(_buildNormalText(remainingText));
        }
      }
      // Detectamos si es una lista (Asterisco o Número "1.")
      else if (trimmed.startsWith('*') || RegExp(r'^\d+\.').hasMatch(trimmed)) {
        // Limpiamos el asterisco si existe, pero dejamos el número si es un paso
        String cleanLine =
            trimmed.startsWith('*') ? trimmed.substring(1).trim() : trimmed;
        widgets.add(_buildListItem(cleanLine));
      } else {
        widgets.add(_buildNormalText(trimmed));
      }
    }
    return widgets;
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
            // El puntito verde que querías
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

                  // Contenido con el parseo inteligente
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
