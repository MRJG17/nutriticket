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

// Clase para manejar el resultado adaptado por Gemini
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
    required this.imageUrl, // ⭐️ CORRECCIÓN: Agregar 'imageUrl' al constructor
    required this.recipeOriginalId,
  });
}

// Tipo de dato de salida para la función de filtrado
typedef ScoredRecipe = ({Recipe recipe, int score, List<String> matches});

class IANutricionalScreen extends StatefulWidget {
  final List<ReceiptItem> scannedItems;

  const IANutricionalScreen({super.key, required this.scannedItems});

  @override
  State<IANutricionalScreen> createState() => _IANutricionalScreenState();
}

class _IANutricionalScreenState extends State<IANutricionalScreen> {
  // Listas de datos
  List<SuggestedRecipeDetail> _suggestedRecipes = [];
  List<Recipe> _allRecipesFromFirestore = [];

  bool _isLoading = true;
  String? _errorMessage;

  final String apiKey = "AIzaSyBYS_97Q3VtHrdjpo9thLPSyNooICgYzEI";
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  final List<String> _menuTypeOptions = ['Plan Semanal', 'Receta Única'];
  String _menuType = 'Receta Única'; // Estado actual

  final List<String> _masterDietOptions = [
    'Ninguna',
    'Vegetariana',
    'Vegana',
    'Sin Gluten',
    'Keto',
    'Paleo',
  ];

  // Preferencias
  String _currentDiet = 'Ninguna';
  int _numServings = 1;

  @override
  void initState() {
    super.initState();
    _loadAllDataAndGenerate();
  }

  // --- CARGAR DATOS DE USUARIO Y RECETAS ---
  Future<void> _loadAllDataAndGenerate() async {
    setState(() {
      _isLoading = true;
    });

    await _loadUserPreferences();
    await _loadRecipesFromFirestore();

    _generateRecipes();
  }

  // --- CARGAR PREFERENCIAS DESDE FIRESTORE ---
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
          final loadedDiet = data['dietaryPreferences'] ?? 'Ninguna';
          if (mounted) {
            setState(() {
              _currentDiet = loadedDiet;
              _numServings = data['householdSize'] ?? 1;
            });
          }
        }
      } catch (e) {
        print("Error al cargar preferencias: $e");
      }
    }
  }

  // --- CARGAR RECETAS DESDE FIRESTORE ---
  Future<void> _loadRecipesFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('recipes').get();

      final List<Recipe> loadedRecipes = snapshot.docs.map((doc) {
        return Recipe.fromMap(doc.data(), doc.id);
      }).toList();

      if (mounted) {
        _allRecipesFromFirestore = loadedRecipes;
      }

      if (_allRecipesFromFirestore.isEmpty) {
        _errorMessage =
            'No se encontraron recetas en la base de datos de Firestore. Usa el botón en la pantalla de Inicio para subir una receta de prueba.';
      }
    } catch (e) {
      _errorMessage =
          'Error al conectar con Firestore para cargar las recetas: ${e.toString()}';
      print("Error Firestore: $e");
    }
  }

  // --- Lógica del Plan Semanal (Generación de Calendario) ---
  Future<void> _generateWeeklyPlan(List<ScoredRecipe> candidateRecipesInfo,
      String availableItemsString) async {
    // 1. Preparamos el JSON de las 3 mejores recetas
    final List<Map<String, dynamic>> selectedRecipes =
        candidateRecipesInfo.map((s) => s.recipe.toJson()).toList();

    final selectedRecipesJson = jsonEncode(selectedRecipes);

    // 2. PROMPT DE GENERACIÓN DE CALENDARIO
    final prompt = """
      Eres un planificador de comidas IA. Genera un plan de menú semanal (Lunes a Domingo) para $_numServings persona(s) y la dieta '$_currentDiet'.

      Debes utilizar las siguientes recetas proporcionadas en JSON como platos fuertes para COMIDA y CENA a lo largo de la semana. Puedes repetir cualquiera de ellas:
      Recetas base (JSON): $selectedRecipesJson

      Para DESAYUNO, sugiere ideas sencillas que complementen la dieta.

      Devuelve el resultado en formato de texto simple. Para cada día, lista Desayuno, Comida y Cena.
      Usa el siguiente formato:
      Lunes:
        Desayuno: [Desayuno simple sugerido]
        Comida: [Plato fuerte USANDO una de las Recetas base. Indica si hay sobras.]
        Cena: [Plato fuerte USANDO una de las Recetas base. Indica si hay sobras.]
      Martes:
        ...
      (Continúa hasta el Domingo)
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
        "generationConfig": {
          "temperature": 0.6,
        },
      };

      final response = await _fetchWithExponentialBackoff(
        Uri.parse('$apiUrl?key=$apiKey'),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final generatedText = jsonResponse['candidates'][0]['content']['parts']
            [0]['text'] as String;

        // Guardamos la respuesta como una ÚNICA "receta" para el Plan Semanal
        if (mounted) {
          _suggestedRecipes.add(SuggestedRecipeDetail(
            title: "Plan Semanal para $_currentDiet",
            adaptedContent: generatedText, // Contiene el menú completo
            matchingIngredients: [],
            imageUrl: candidateRecipesInfo.isNotEmpty
                ? candidateRecipesInfo.first.recipe.imageUrl
                : '', // ⭐️ Foto de la primera receta
            recipeOriginalId: candidateRecipesInfo.isNotEmpty
                ? candidateRecipesInfo.first.recipe.id
                : '', // ⭐️ ID para referencia
          ));
        }
      } else {
        throw Exception(
            'API falló con código ${response.statusCode}. Mensaje: ${response.body}');
      }
    } catch (e) {
      _showError('Fallo al generar el plan semanal: ${e.toString()}');
    }
  }

  // --- Lógica de Recetas Únicas (Adaptación de Porciones) ---
  Future<void> _generateSingleRecipes(List<ScoredRecipe> candidateRecipesInfo,
      String availableItemsString) async {
    for (final scoredRecipe in candidateRecipesInfo) {
      final recipe = scoredRecipe.recipe;
      final matchingIngredients = scoredRecipe.matches;
      final recipeJson = jsonEncode(recipe.toJson());

      final prompt = """
        Eres un chef IA especializado en adaptar recetas.
        
        Tu tarea es adaptar la siguiente receta (proporcionada en formato JSON) para $_numServings persona(s) y considerar el siguiente tipo de dieta: '$_currentDiet'.

        Receta JSON:
        $recipeJson

        Ingredientes comprados disponibles (contexto):
        [$availableItemsString]
        
        1. **Ajusta las cantidades de los ingredientes** de la receta para el número de raciones deseado (original: ${recipe.baseServings}, deseado: $_numServings).
        2. **Genera la receta completa** en formato de texto limpio.
        3. El contenido debe incluir: El título original de la receta, una Descripción Breve, una sección de INGREDITENTES ADAPTADOS (con las nuevas cantidades y unidades), y una sección de PASOS.
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
          "generationConfig": {
            "temperature": 0.5,
          },
        };

        final response = await _fetchWithExponentialBackoff(
          Uri.parse('$apiUrl?key=$apiKey'),
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          final generatedText = jsonResponse['candidates'][0]['content']
              ['parts'][0]['text'] as String;

          if (mounted) {
            _suggestedRecipes.add(SuggestedRecipeDetail(
              title: recipe.title,
              adaptedContent: generatedText,
              matchingIngredients: matchingIngredients,
              imageUrl: recipe.imageUrl, // ⭐️ AÑADIDO
              recipeOriginalId: recipe.id,
            ));
          }
        } else {
          print(
              'Error API al adaptar ${recipe.title}: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Excepción al adaptar ${recipe.title}: $e');
        _showError('Fallo al contactar a la IA: ${e.toString()}');
      }
    }
  }

  // --- 2. LÓGICA DE BÚSQUEDA Y FILTRO ---
  List<ScoredRecipe> _filterRecipes(
      List<ReceiptItem> items, String diet, int servings) {
    final recipesToFilter = _allRecipesFromFirestore;

    // 1. Obtener nombres de ingredientes del ticket
    final availableItems = items.map((i) => i.item.toLowerCase()).toList();

    // 2. Filtrar por dieta
    final dietFiltered = recipesToFilter.where((recipe) {
      if (diet == 'Ninguna') return true;
      return recipe.tags.any((tag) => tag.toLowerCase() == diet.toLowerCase());
    }).toList();

    // 3. Evaluar la cobertura de ingredientes (Score y Matches)
    final List<ScoredRecipe> scoredRecipes = dietFiltered.map((recipe) {
      int score = 0;
      final List<String> matches = [];

      for (var ingredient in recipe.ingredients) {
        final ingredientNameLower = ingredient.name.toLowerCase();

        // Buscar coincidencia
        final hasMatch = availableItems
            .firstWhere(
              (item) => item.contains(ingredientNameLower),
              orElse: () => '',
            )
            .isNotEmpty;

        if (hasMatch) {
          score++;
          matches.add(ingredient.name);
        }
      }
      return (recipe: recipe, score: score, matches: matches);
    }).toList();

    // 4. Ordenar por score y tomar las 3 mejores (que tengan al menos 1 coincidencia)
    scoredRecipes.sort((a, b) => b.score.compareTo(a.score));

    return scoredRecipes.where((s) => s.score > 0).take(3).toList();
  }

  // --- 3. ADAPTACIÓN DE RECETA CON GEMINI API ---
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

    // 1. Obtener recetas candidatas de Firestore
    final candidateRecipesInfo =
        _filterRecipes(widget.scannedItems, _currentDiet, _numServings);

    if (candidateRecipesInfo.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'No se encontraron recetas que coincidan con tus ingredientes y preferencias de dieta. Asegúrate de tener al menos un ingrediente en común.';
      });
      return;
    }

    // 2. Preparar el contexto de los ingredientes disponibles
    final availableItemsString =
        widget.scannedItems.map((i) => '${i.item} (x${i.qty})').join(', ');

    // ⭐️ DECISIÓN DE FLUJO ⭐️
    if (_menuType == 'Plan Semanal') {
      await _generateWeeklyPlan(candidateRecipesInfo, availableItemsString);
    } else {
      await _generateSingleRecipes(candidateRecipesInfo, availableItemsString);
    }

    if (_suggestedRecipes.isEmpty && _errorMessage == null) {
      _errorMessage =
          'Fallo la adaptación de todas las recetas candidatas o la IA no pudo procesar la solicitud.';
    }

    setState(() {
      _isLoading = false;
    });
  }

  // --- 4. FUNCIÓN DE BACKOFF (REINTENTOS) ---
  Future<http.Response> _fetchWithExponentialBackoff(Uri uri,
      {String? body}) async {
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
        if (response.statusCode < 500 && response.statusCode != 429)
          return response;
      } catch (e) {
        // Ignorar errores de red y reintentar
      }

      if (i < maxRetries - 1) {
        final delay = initialDelay * (1 << i);
        await Future.delayed(delay);
      }
    }
    return http.Response(
        '{"error": "Tiempo de espera agotado o error de red."}', 500);
  }

  // --- FUNCIONES DE INTERFAZ Y UTILIDAD ---
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  // ------------------------------------------------------------
  // WIDGETS DE VISUALIZACIÓN DE RESULTADOS
  // ------------------------------------------------------------

  // Vista para Plan Semanal
  Widget _buildWeeklyPlanView(SuggestedRecipeDetail menuResult) {
    final List<String> days = menuResult.adaptedContent.split(RegExp(
        r'\n(?=Lunes|Martes|Miércoles|Jueves|Viernes|Sábado|Domingo)',
        caseSensitive: false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          menuResult.title,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey),
        ),
        const Divider(),
        ...days.map((dayPlan) {
          if (dayPlan.trim().isEmpty) return const SizedBox.shrink();

          final parts = dayPlan.trim().split(':');
          final day = parts[0].trim().replaceAll('\n', '');
          final content = parts.length > 1
              ? parts.sublist(1).join(':').trim()
              : 'Contenido no especificado.';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ExpansionTile(
              title: Text(day,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.calendar_today, color: Colors.green),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(content, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Vista para Recetas Únicas (Horizontal Scroll)
  Widget _buildRecipeListView() {
    // ⭐️ Si es Plan Semanal, solo hay un elemento, lo renderizamos con la vista de menú ⭐️
    if (_menuType == 'Plan Semanal' && _suggestedRecipes.isNotEmpty) {
      return _buildWeeklyPlanView(_suggestedRecipes.first);
    }

    // Si es Receta Única, renderizamos el scroll horizontal
    return SizedBox(
      height: 350,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedRecipes.length,
        itemBuilder: (context, index) {
          final adaptedResult = _suggestedRecipes[index];
          final recipeContent = adaptedResult.adaptedContent;
          final recipeTitle = adaptedResult.title;
          final matchingIngredients = adaptedResult.matchingIngredients;
          final originalId = adaptedResult.recipeOriginalId;

          // Intenta encontrar la descripción
          final recipeLines = recipeContent
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          final titleLine = recipeLines.firstWhere(
              (line) => line.toUpperCase().contains(recipeTitle.toUpperCase()),
              orElse: () => recipeTitle);
          final descriptionIndex = recipeLines.indexOf(titleLine) + 1;
          final recipeDescription = descriptionIndex < recipeLines.length
              ? recipeLines[descriptionIndex]
              : 'Receta adaptada por IA.';

          final imageUrl =
              adaptedResult.imageUrl; // ⭐️ La URL ahora es accesible

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(
                    recipeContent: recipeContent,
                    recipeTitle: recipeTitle,
                    recipeId: originalId,
                    currentServings: _numServings,
                    currentDiet: _currentDiet,
                  ),
                ),
              );
            },
            child: Container(
              width: 250,
              margin: const EdgeInsets.only(right: 16),
              child: Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      // ⭐️ Usamos Image.network si la URL es válida ⭐️
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.lightGreen.shade100,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                      color: Colors.green),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.lightGreen.shade100,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image,
                                      size: 60, color: Colors.red),
                                );
                              },
                            )
                          : Container(
                              // Placeholder si no hay URL
                              color: Colors.lightGreen.shade100,
                              alignment: Alignment.center,
                              child: const Icon(Icons.food_bank,
                                  size: 60, color: Colors.green),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 8.0, left: 12.0, right: 12.0),
                      child: Text(
                        recipeTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      child: Text(
                        'Raciones: $_numServings | Dieta: $_currentDiet',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tienes:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              matchingIngredients.join(', '),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 12.0, bottom: 8.0),
                        child: Text('Ver Receta Adaptada',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // INTERFAZ PRINCIPAL Y CONSTRUCTOR DE CUERPO
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // ✅ SI ESTÁ CARGANDO: Pantalla completa verde sin AppBar
    if (_isLoading) {
      return const Scaffold(
        body: CustomLogoLoader(
          text: 'Cargando recetas y adaptándolas para ti...',
        ),
      );
    }

    // ✅ SI YA CARGÓ: Pantalla normal con AppBar y contenido
    return Scaffold(
      appBar: AppBar(title: const Text('IA Nutricional')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. Si está cargando, mostramos la animación de bolitas
    if (_isLoading) {
      return const CustomLogoLoader(
        text: 'Cargando recetas y adaptándolas para ti...',
      );
    }
    // 2. Si hay error o no hay recetas, mostramos el mensaje de error
    if (_errorMessage != null || _suggestedRecipes.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(
                _errorMessage ??
                    'No se pudo generar una sugerencia de receta. Intenta con más ingredientes.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadAllDataAndGenerate,
              child: const Text('Reintentar Carga / Búsqueda'),
            ),
          ],
        ),
      ));
    }

    // 2. Si todo salió bien (hay recetas), mostramos el contenido principal
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModificationOptions(),
          const SizedBox(height: 30),
          Text(
            _menuType == 'Plan Semanal'
                ? 'Menú Semanal Sugerido:'
                : 'Recetas Sugeridas (Adaptadas por Gemini):',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const Divider(),
          _buildRecipeListView(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // WIDGET PARA LAS PREFERENCIAS DEL USUARIO
  Widget _buildModificationOptions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajustar Adaptación:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // Selector de Modo (Plan Semanal / Receta Única)
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Modo de Sugerencia'),
              value: _menuType,
              items: _menuTypeOptions
                  .map((label) =>
                      DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _menuType = value;
                  });
                  _generateRecipes();
                }
              },
            ),
            const SizedBox(height: 10),

            // ⭐️ Selector de Dieta (Faltaba en la versión anterior) ⭐️
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                  labelText: 'Tipo de Dieta (Actual: $_currentDiet)'),
              value: _currentDiet,
              items: _masterDietOptions
                  .map((label) =>
                      DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentDiet = value;
                  });
                }
              },
            ),
            const SizedBox(height: 10),

            // Selector de Raciones
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                        labelText: 'Raciones (Actual: $_numServings)'),
                    value: _numServings,
                    items: [1, 2, 3, 4, 5, 6, 7, 8]
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _numServings = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Botón para Regenerar la Receta (Aplicar filtros y re-adaptar)
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateRecipes,
                  child: const Text('Re-Adaptar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
