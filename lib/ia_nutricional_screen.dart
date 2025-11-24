// lib/ia_nutricional_screen.dart

import 'package:flutter/material.dart';
import 'package:nutriticket/receipt_item.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutriticket/recipe_detail_screen.dart';
import 'package:nutriticket/recipe.dart';
import 'package:nutriticket/custom_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nutriticket/secrets.dart';

class SuggestedRecipeDetail {
  final String title;
  final String adaptedContent;
  final List<String> matchingIngredients;
  final String imageUrl;
  final String recipeOriginalId;

  SuggestedRecipeDetail({
    required this.title,
    required this.adaptedContent,
    required this.matchingIngredients,
    required this.imageUrl,
    required this.recipeOriginalId,
  });
}

typedef ScoredRecipe = ({Recipe recipe, int score, List<String> matches});

class IANutricionalScreen extends StatefulWidget {
  final List<ReceiptItem> scannedItems;

  const IANutricionalScreen({super.key, required this.scannedItems});

  @override
  State<IANutricionalScreen> createState() => _IANutricionalScreenState();
}

class _IANutricionalScreenState extends State<IANutricionalScreen> {
  List<SuggestedRecipeDetail> _suggestedRecipes = [];
  List<Recipe> _allRecipesFromFirestore = [];

  bool _isLoading = true;
  String? _errorMessage;

  // ✅ USAMOS LA CLAVE SEGURA
  final String apiKey = googleApiKey;

  // ✅ USAMOS EL MODELO 2.5 (IGUAL QUE EN HOME)
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  final List<String> _menuTypeOptions = ['Plan Semanal', 'Receta Única'];
  String _menuType = 'Receta Única';

  final List<String> _masterDietOptions = [
    'Ninguna',
    'Vegetariana',
    'Vegana',
    'Sin Gluten',
    'Keto',
    'Paleo',
  ];

  String _currentDiet = 'Ninguna';
  int _numServings = 1;

  @override
  void initState() {
    super.initState();
    _loadAllDataAndGenerate();
  }

  Future<void> _loadAllDataAndGenerate() async {
    setState(() => _isLoading = true);
    await _loadUserPreferences();
    await _loadRecipesFromFirestore();
    _generateRecipes();
  }

  Future<void> _loadUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          if (mounted) {
            setState(() {
              _currentDiet = data['dietaryPreferences'] ?? 'Ninguna';
              _numServings = data['householdSize'] ?? 1;
            });
          }
        }
      } catch (e) {
        // print("Error preferences: $e");
      }
    }
  }

  Future<void> _loadRecipesFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('recipes').get();
      final List<Recipe> loadedRecipes = snapshot.docs.map((doc) {
        return Recipe.fromMap(doc.data(), doc.id);
      }).toList();

      if (mounted) _allRecipesFromFirestore = loadedRecipes;

      if (_allRecipesFromFirestore.isEmpty) {
        _errorMessage = 'No se encontraron recetas en la base de datos.';
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: ${e.toString()}';
    }
  }

  // --- PARSEO SEGURO (EVITA PANTALLA ROJA) ---
  String _parseGeminiResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Error API (${response.statusCode}): ${response.body}');
    }

    final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

    // Si 'candidates' no existe o está vacío, lanzamos error controlado
    if (jsonResponse['candidates'] == null ||
        (jsonResponse['candidates'] as List).isEmpty) {
      throw Exception('La IA no devolvió resultados válidos.');
    }

    final parts = jsonResponse['candidates'][0]['content']['parts'] as List;
    if (parts.isEmpty) {
      throw Exception('Respuesta vacía.');
    }

    return parts[0]['text'] as String;
  }

  // --- PLAN SEMANAL ---
  Future<void> _generateWeeklyPlan(List<ScoredRecipe> candidateRecipesInfo,
      String availableItemsString) async {
    final List<Map<String, dynamic>> selectedRecipes =
        candidateRecipesInfo.map((s) => s.recipe.toJson()).toList();
    final selectedRecipesJson = jsonEncode(selectedRecipes);

    // Prompt directo pero sin limitaciones técnicas extremas
    final prompt = """
      Genera un plan de menú semanal ($_numServings personas, dieta $_currentDiet).
      Recetas base disponibles: $selectedRecipesJson.
      
      FORMATO OBLIGATORIO:
      Empieza directamente con "Lunes:".
      Usa este esquema para cada día:
      Lunes:
      Desayuno: ...
      Comida: ...
      Cena: ...
    """;

    try {
      final payload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        // ✅ QUITAMOS EL LÍMITE DE TOKENS PARA QUE NO FALLE
        "generationConfig": {
          "temperature": 0.7, // Creatividad estándar
        },
      };

      final response = await _fetchWithExponentialBackoff(
        Uri.parse('$apiUrl?key=$apiKey'),
        body: jsonEncode(payload),
      );

      final generatedText = _parseGeminiResponse(response);

      if (mounted) {
        _suggestedRecipes.add(SuggestedRecipeDetail(
          title: "Plan Semanal ($_currentDiet)",
          adaptedContent: generatedText,
          matchingIngredients: [],
          imageUrl: candidateRecipesInfo.isNotEmpty
              ? candidateRecipesInfo.first.recipe.imageUrl
              : '',
          recipeOriginalId: candidateRecipesInfo.isNotEmpty
              ? candidateRecipesInfo.first.recipe.id
              : '',
        ));
      }
    } catch (e) {
      _showError('Error al generar plan: $e');
    }
  }

  // --- RECETA ÚNICA ---
  Future<void> _generateSingleRecipes(List<ScoredRecipe> candidateRecipesInfo,
      String availableItemsString) async {
    for (final scoredRecipe in candidateRecipesInfo) {
      final recipe = scoredRecipe.recipe;
      final matchingIngredients = scoredRecipe.matches;
      final recipeJson = jsonEncode(recipe.toJson());

      final prompt = """
        Adapta esta receta para $_numServings persona(s), dieta '$_currentDiet'.
        Receta JSON: $recipeJson
        Ingredientes disponibles: [$availableItemsString].

        INSTRUCCIONES DE FORMATO:
        1. NO saludes. Solo entrega la receta.
        2. Usa estos encabezados exactos en mayúsculas:
           DESCRIPCIÓN:
           INGREDIENTES:
           PASOS:
        
        Estructura:
        [Título]
        DESCRIPCIÓN: [Resumen]
        INGREDIENTES: [Lista]
        PASOS: [Lista numerada]
      """;

      try {
        final payload = {
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          // ✅ QUITAMOS EL LÍMITE DE TOKENS
          "generationConfig": {
            "temperature": 0.5,
          },
        };

        final response = await _fetchWithExponentialBackoff(
          Uri.parse('$apiUrl?key=$apiKey'),
          body: jsonEncode(payload),
        );

        final generatedText = _parseGeminiResponse(response);

        if (mounted) {
          _suggestedRecipes.add(SuggestedRecipeDetail(
            title: recipe.title,
            adaptedContent: generatedText,
            matchingIngredients: matchingIngredients,
            imageUrl: recipe.imageUrl,
            recipeOriginalId: recipe.id,
          ));
        }
      } catch (e) {
        // print('Error al adaptar receta: $e');
      }
    }

    if (_suggestedRecipes.isEmpty && mounted) {
      _showError('No se pudieron generar recetas. Verifica tu conexión.');
    }
  }

  // --- FILTROS ---
  List<ScoredRecipe> _filterRecipes(
      List<ReceiptItem> items, String diet, int servings) {
    final recipesToFilter = _allRecipesFromFirestore;
    final availableItems = items.map((i) => i.item.toLowerCase()).toList();

    final dietFiltered = recipesToFilter.where((recipe) {
      if (diet == 'Ninguna') return true;
      return recipe.tags.any((tag) => tag.toLowerCase() == diet.toLowerCase());
    }).toList();

    final List<ScoredRecipe> scoredRecipes = dietFiltered.map((recipe) {
      int score = 0;
      final List<String> matches = [];
      for (var ingredient in recipe.ingredients) {
        final ingredientNameLower = ingredient.name.toLowerCase();
        final hasMatch = availableItems
            .firstWhere((item) => item.contains(ingredientNameLower),
                orElse: () => '')
            .isNotEmpty;
        if (hasMatch) {
          score++;
          matches.add(ingredient.name);
        }
      }
      return (recipe: recipe, score: score, matches: matches);
    }).toList();

    scoredRecipes.sort((a, b) => b.score.compareTo(a.score));
    return scoredRecipes.where((s) => s.score > 0).take(3).toList();
  }

  Future<void> _generateRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestedRecipes = [];
    });

    if (_allRecipesFromFirestore.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final candidateRecipesInfo =
        _filterRecipes(widget.scannedItems, _currentDiet, _numServings);

    if (candidateRecipesInfo.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No hay recetas coincidentes con tus ingredientes.';
      });
      return;
    }

    final availableItemsString =
        widget.scannedItems.map((i) => '${i.item} (x${i.qty})').join(', ');

    if (_menuType == 'Plan Semanal') {
      await _generateWeeklyPlan(candidateRecipesInfo, availableItemsString);
    } else {
      await _generateSingleRecipes(candidateRecipesInfo, availableItemsString);
    }

    setState(() => _isLoading = false);
  }

  Future<http.Response> _fetchWithExponentialBackoff(Uri uri,
      {String? body}) async {
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.post(uri,
            headers: {'Content-Type': 'application/json'}, body: body);
        if (response.statusCode >= 500 || response.statusCode == 429) {
          // retry
        } else {
          return response;
        }
      } catch (e) {}
      if (i < maxRetries - 1) await Future.delayed(initialDelay * (1 << i));
    }
    return http.Response('{"error": "Timeout"}', 500);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: CustomLogoLoader(
            text: 'Cargando recetas y adaptándolas para ti...'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('IA Nutricional',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null || _suggestedRecipes.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Error desconocido.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllDataAndGenerate,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModificationOptions(),
          const SizedBox(height: 30),
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _menuType == 'Plan Semanal'
                      ? 'Tu Plan Semanal'
                      : 'Recetas Sugeridas',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecipeListView(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModificationOptions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajustar Preferencias',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const Divider(height: 24),
          _buildDropdownLabel('Modo de Sugerencia'),
          _buildStyledDropdown<String>(
            value: _menuType,
            items: _menuTypeOptions,
            onChanged: (val) {
              if (val != null) {
                setState(() => _menuType = val);
                _generateRecipes();
              }
            },
          ),
          const SizedBox(height: 16),
          _buildDropdownLabel('Tipo de Dieta'),
          _buildStyledDropdown<String>(
            value: _currentDiet,
            items: _masterDietOptions,
            onChanged: (val) {
              if (val != null) setState(() => _currentDiet = val);
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdownLabel('Raciones'),
                    _buildStyledDropdown<int>(
                      value: _numServings,
                      items: [1, 2, 3, 4, 5, 6, 7, 8],
                      onChanged: (val) {
                        if (val != null) setState(() => _numServings = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _generateRecipes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Re-Adaptar',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600])),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
              value: item,
              child: Text('$item', style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4CAF50))),
      ),
      icon: const Icon(Icons.arrow_drop_down_circle_outlined,
          color: Colors.grey, size: 20),
    );
  }

  Widget _buildRecipeListView() {
    if (_menuType == 'Plan Semanal' && _suggestedRecipes.isNotEmpty) {
      return _buildWeeklyPlanView(_suggestedRecipes.first);
    }
    return SizedBox(
      height: 340,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _suggestedRecipes.length,
        itemBuilder: (context, index) {
          final adaptedResult = _suggestedRecipes[index];
          return _buildRecipeCard(adaptedResult);
        },
      ),
    );
  }

  Widget _buildWeeklyPlanView(SuggestedRecipeDetail menuResult) {
    final List<String> days = menuResult.adaptedContent.split(RegExp(
        r'\n(?=Lunes|Martes|Miércoles|Jueves|Viernes|Sábado|Domingo)',
        caseSensitive: false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: days.map((dayPlan) {
        if (dayPlan.trim().isEmpty) return const SizedBox.shrink();
        final parts = dayPlan.trim().split(':');
        final day = parts[0].trim().replaceAll('\n', '');
        final content =
            parts.length > 1 ? parts.sublist(1).join(':').trim() : '...';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: ExpansionTile(
            shape: Border.all(color: Colors.transparent),
            title:
                Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF4CAF50)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(content,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800])),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecipeCard(SuggestedRecipeDetail item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              recipeContent: item.adaptedContent,
              recipeTitle: item.title,
              recipeId: item.recipeOriginalId,
              currentServings: _numServings,
              currentDiet: _currentDiet,
              imageUrl: item.imageUrl,
            ),
          ),
        );
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 500),
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[50]),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Icon(Icons.restaurant_menu,
                              size: 40, color: Color(0xFFA5D6A7)),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                            child: Icon(Icons.restaurant_menu,
                                size: 50, color: Color(0xFF4CAF50))),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('$_numServings raciones • $_currentDiet',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.check_circle_outline,
                              size: 14, color: Color(0xFF4CAF50)),
                          SizedBox(width: 4),
                          Text('Tienes:',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50)))
                        ]),
                        const SizedBox(height: 2),
                        Text(item.matchingIngredients.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[800])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
              child: const Center(
                  child: Text('Ver Receta',
                      style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                          fontSize: 14))),
            ),
          ],
        ),
      ),
    );
  }
}
