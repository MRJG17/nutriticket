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

// --- 1. MODELOS DE DATOS ---

class SuggestedRecipeDetail {
  final Recipe recipe;
  final List<String> matchingIngredients;

  SuggestedRecipeDetail({
    required this.recipe,
    required this.matchingIngredients,
  });
}

class MealCardData {
  final String title;
  final String type;
  final String imageUrl;

  MealCardData({
    required this.title,
    required this.type,
    required this.imageUrl,
  });
}

class DailyPlanData {
  final String day;
  final List<MealCardData> meals;

  DailyPlanData({required this.day, required this.meals});
}

typedef ScoredRecipe = ({Recipe recipe, int score, List<String> matches});

class IANutricionalScreen extends StatefulWidget {
  final List<ReceiptItem> scannedItems;

  const IANutricionalScreen({super.key, required this.scannedItems});

  @override
  State<IANutricionalScreen> createState() => _IANutricionalScreenState();
}

class _IANutricionalScreenState extends State<IANutricionalScreen> {
  // Estado
  List<SuggestedRecipeDetail> _suggestedRecipes = [];
  List<Recipe> _allRecipesFromFirestore = [];

  // Texto del plan semanal
  String _weeklyPlanText = "";

  bool _isLoading = true;
  String? _errorMessage;

  // ✅ CONTROL DE VISTA (GRID VS LISTA)
  bool _isGridView = true;

  // API
  final String apiKey = googleApiKey;
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  // Opciones UI
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

  // --- LÓGICA DE PARSEO DEL PLAN SEMANAL ---
  List<DailyPlanData> _parseWeeklyPlan(String generatedText) {
    final List<DailyPlanData> weeklyPlan = [];

    final dayRegex = RegExp(
        r'^(Lunes|Martes|Miércoles|Jueves|Viernes|Sábado|Domingo):',
        multiLine: true);
    final rawDays = generatedText.split(dayRegex);
    final matches = dayRegex.allMatches(generatedText).toList();

    int contentIndex = rawDays.isNotEmpty && rawDays[0].trim().isEmpty ? 1 : 0;

    for (var i = 0; i < matches.length; i++) {
      if (contentIndex >= rawDays.length) break;

      final dayName = generatedText
          .substring(matches[i].start, matches[i].end)
          .replaceAll(':', '');
      final dayContent = rawDays[contentIndex++];
      final List<MealCardData> meals = [];

      final mealRegex = RegExp(
          r'(Desayuno|Comida|Cena):\s*(.*?)(?=\n(Desayuno|Comida|Cena):|\n\s*$|$)',
          multiLine: true,
          dotAll: true);
      final mealMatches = mealRegex.allMatches(dayContent);

      for (var match in mealMatches) {
        final type = match.group(1) ?? 'Comida';
        final title = match.group(2)?.trim() ?? 'Sugerencia del chef';

        String imgUrl = "https://i.imgur.com/B9P9x6U.png";
        if (type == 'Desayuno') imgUrl = "https://i.imgur.com/vHq0L59.png";
        if (type == 'Comida') imgUrl = "https://i.imgur.com/Qa8f7.jpeg";

        meals.add(MealCardData(title: title, type: type, imageUrl: imgUrl));
      }

      if (meals.isNotEmpty) {
        weeklyPlan.add(DailyPlanData(day: dayName, meals: meals));
      }
    }
    return weeklyPlan;
  }

  // --- LÓGICA LOCAL ---
  String _adaptRecipeContent(Recipe recipe, int targetServings) {
    final double scaleFactor = targetServings / recipe.baseServings;
    final String ingredientsAdapted = recipe.ingredients.map((i) {
      final double newQuantity = i.quantity * scaleFactor;
      final String quantityString = newQuantity.toStringAsFixed(
          newQuantity.truncateToDouble() == newQuantity ? 0 : 1);
      return '* ${i.name}: $quantityString ${i.unit}';
    }).join('\n');

    return '${recipe.title}\nDESCRIPCIÓN: ${recipe.description}\n\nINGREDIENTES ADAPTADOS ($targetServings porciones):\n$ingredientsAdapted\n\nPASOS:\n${recipe.instructions}';
  }

  // --- CARGA DE DATOS ---
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
      } catch (e) {}
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

  // --- GENERACIÓN ---

  Future<void> _generateSingleRecipes(List<ScoredRecipe> candidateRecipesInfo,
      String availableItemsString) async {
    for (final scoredRecipe in candidateRecipesInfo) {
      if (mounted) {
        _suggestedRecipes.add(SuggestedRecipeDetail(
          recipe: scoredRecipe.recipe,
          matchingIngredients: scoredRecipe.matches,
        ));
      }
    }
    if (_suggestedRecipes.isEmpty && mounted) {
      _showError('No se pudieron generar sugerencias. Verifica tus filtros.');
    }
  }

  Future<String?> _generateWeeklyPlanText(
      List<ScoredRecipe> candidateRecipesInfo) async {
    final List<Map<String, dynamic>> selectedRecipes =
        candidateRecipesInfo.map((s) => s.recipe.toJson()).toList();
    final selectedRecipesJson = jsonEncode(selectedRecipes);

    final prompt = """
      Genera un plan de menú semanal ($_numServings personas, dieta $_currentDiet).
      Usa las Recetas base disponibles: $selectedRecipesJson. 
      
      FORMATO OBLIGATORIO (Estricto para parseo):
      Usa exactamente "Lunes:", "Martes:", etc.
      Dentro de cada día usa exactamente "Desayuno:", "Comida:", "Cena:".
      
      Ejemplo de Salida:
      Lunes:
      Desayuno: [Descripción breve]
      Comida: [Nombre de la receta base o sugerencia]
      Cena: [Nombre de la receta base o sugerencia]
      Martes:
      ...
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
        "generationConfig": {"temperature": 0.7},
      };

      final response = await _fetchWithExponentialBackoff(
        Uri.parse('$apiUrl?key=$apiKey'),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonResponse['candidates'][0]['content']['parts'][0]['text']
            as String;
      } else {
        throw Exception('Error API: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error al generar plan: $e');
      return null;
    }
  }

  Future<void> _generateRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestedRecipes = [];
      _weeklyPlanText = "";
    });

    if (_allRecipesFromFirestore.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final candidateRecipesInfo =
        _filterRecipes(widget.scannedItems, _currentDiet, _numServings);

    final availableItemsString =
        widget.scannedItems.map((i) => '${i.item} (x${i.qty})').join(', ');

    if (_menuType == 'Plan Semanal') {
      String? text = await _generateWeeklyPlanText(candidateRecipesInfo);
      if (text != null && mounted) {
        setState(() {
          _weeklyPlanText = text;
          // Dummy para activar builder
          if (candidateRecipesInfo.isNotEmpty) {
            _suggestedRecipes.add(SuggestedRecipeDetail(
                recipe: candidateRecipesInfo.first.recipe,
                matchingIngredients: []));
          } else if (_allRecipesFromFirestore.isNotEmpty) {
            _suggestedRecipes.add(SuggestedRecipeDetail(
                recipe: _allRecipesFromFirestore.first,
                matchingIngredients: []));
          }
        });
      }
    } else {
      if (candidateRecipesInfo.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No hay recetas coincidentes con tus ingredientes.';
        });
        return;
      }
      await _generateSingleRecipes(candidateRecipesInfo, availableItemsString);
    }

    setState(() => _isLoading = false);
  }

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
        final hasMatch =
            availableItems.any((item) => item.contains(ingredientNameLower));
        if (hasMatch) {
          score++;
          matches.add(ingredient.name);
        }
      }
      return (recipe: recipe, score: score, matches: matches);
    }).toList();

    scoredRecipes.sort((a, b) => b.score.compareTo(a.score));
    // Aumentamos el límite para que el scroll tenga sentido (ej: 20 recetas)
    return scoredRecipes.where((s) => s.score > 0).take(20).toList();
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

  Widget _buildWeeklyPlanView() {
    final List<DailyPlanData> weeklyPlan = _parseWeeklyPlan(_weeklyPlanText);

    if (weeklyPlan.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No se pudo generar el calendario. Intenta de nuevo.",
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: weeklyPlan.map((dayData) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            shape: Border.all(color: Colors.transparent),
            title: Text(dayData.day,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            leading: const Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
            children: [
              SizedBox(
                height: 220,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: dayData.meals.length,
                  itemBuilder: (context, mealIndex) {
                    final meal = dayData.meals[mealIndex];
                    return _buildMealCard(meal);
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMealCard(MealCardData meal) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: CachedNetworkImage(
                imageUrl: meal.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.fastfood, color: Colors.grey[400]),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      meal.type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐️ VISTA PRINCIPAL DE RECETAS (Grid vs Filas de Carruseles) ⭐️
  Widget _buildRecipeListView() {
    if (_menuType == 'Plan Semanal') {
      return _buildWeeklyPlanView();
    }

    // 1. VISTA CUADRÍCULA (Grid Vertical)
    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _suggestedRecipes.length,
        itemBuilder: (context, index) {
          final item = _suggestedRecipes[index];
          return _buildGridRecipeCard(item);
        },
      );
    }

    // 2. VISTA "CARRUSELES APILADOS" (Chunked Carousel)
    else {
      // Dividimos las recetas en grupos de 5
      final int chunkSize = 5;
      List<List<SuggestedRecipeDetail>> recipeChunks = [];
      for (var i = 0; i < _suggestedRecipes.length; i += chunkSize) {
        recipeChunks.add(_suggestedRecipes.sublist(
            i,
            i + chunkSize > _suggestedRecipes.length
                ? _suggestedRecipes.length
                : i + chunkSize));
      }

      // Construimos una Columna de Carruseles
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recipeChunks.asMap().entries.map((entry) {
          final int rowIndex = entry.key;
          final List<SuggestedRecipeDetail> chunk = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Separación entre filas
              if (rowIndex > 0) const SizedBox(height: 16),

              // ⛔️ TEXTO ELIMINADO SEGÚN TU SOLICITUD
              // El carrusel se dibuja limpio.

              SizedBox(
                height:
                    250, // ✅ ALTURA REDUCIDA para que las tarjetas se vean más chicas
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: chunk.length,
                  itemBuilder: (context, index) {
                    final item = chunk[index];
                    return _buildSingleRecipeCard(item);
                  },
                ),
              ),
            ],
          );
        }).toList(),
      );
    }
  }

  // Tarjeta: Diseño Nuevo (Vertical para Grid)
  Widget _buildGridRecipeCard(SuggestedRecipeDetail item) {
    final Recipe recipe = item.recipe;
    final String adaptedContent = _adaptRecipeContent(recipe, _numServings);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              recipeContent: adaptedContent,
              recipeTitle: recipe.title,
              recipeId: recipe.id,
              currentServings: _numServings,
              currentDiet: _currentDiet,
              imageUrl: recipe.imageUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFE8F5E9),
                            child: const Icon(Icons.restaurant_menu,
                                color: Color(0xFFA5D6A7)),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Center(
                              child: Icon(Icons.restaurant_menu,
                                  size: 30, color: Color(0xFF4CAF50))),
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.matchingIngredients.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tienes ${item.matchingIngredients.length} ingr.',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF2E7D32)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta: Diseño Ajustado (Ahora igual al Grid pero en horizontal)
  Widget _buildSingleRecipeCard(SuggestedRecipeDetail item) {
    final Recipe recipe = item.recipe;
    final String adaptedContent = _adaptRecipeContent(recipe, _numServings);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              recipeContent: adaptedContent,
              recipeTitle: recipe.title,
              recipeId: recipe.id,
              currentServings: _numServings,
              currentDiet: _currentDiet,
              imageUrl: recipe.imageUrl,
            ),
          ),
        );
      },
      child: Container(
        width: 170, // ✅ ANCHO REDUCIDO (Similar al Grid)
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) =>
                              Container(color: const Color(0xFFE8F5E9)),
                        )
                      : Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Center(
                              child: Icon(Icons.restaurant_menu,
                                  size: 30, color: Color(0xFF4CAF50))),
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.bold) // ✅ Fuente ajustada a 14
                        ),
                    const SizedBox(height: 4),
                    if (item.matchingIngredients.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            'Tienes ${item.matchingIngredients.length} ingr.',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF2E7D32))),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: CustomLogoLoader(text: 'Preparando tus sugerencias...'));
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
        // ✅ 2. BOTÓN DE CAMBIO DE VISTA (Solo visible si no es Plan Semanal)
        actions: [
          if (_menuType == 'Receta Única')
            IconButton(
              // Si está en Grid, muestra icono de Lista, y viceversa
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              tooltip: 'Cambiar Vista',
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null ||
        (_suggestedRecipes.isEmpty && _weeklyPlanText.isEmpty)) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Error desconocido.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllDataAndGenerate,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white),
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
      // Usamos ExpansionTile para ocultar/mostrar
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          shape: Border.all(color: Colors.transparent),
          collapsedShape: Border.all(color: Colors.transparent),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: const Text(
            'Ajustar Preferencias',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: const Icon(Icons.tune, color: Color(0xFF4CAF50)),
          childrenPadding:
              const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          children: [
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
            _buildDropdownLabel('Raciones'),
            _buildStyledDropdown<int>(
              value: _numServings,
              items: [1, 2, 3, 4, 5, 6, 7, 8],
              onChanged: (val) {
                if (val != null) setState(() => _numServings = val);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateRecipes,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Re-Adaptar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
                color: Colors.grey[600])));
  }

  Widget _buildStyledDropdown<T>(
      {required T value,
      required List<T> items,
      required ValueChanged<T?> onChanged}) {
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
      ),
    );
  }
}
