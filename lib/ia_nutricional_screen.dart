// lib/ia_nutricional_screen.dart

import 'package:flutter/material.dart';
import 'package:nutriticket/receipt_item.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutriticket/recipe_detail_screen.dart'; 

// Clase para manejar los resultados del menú
class WeeklyMenu {
  final String menuPlan;
  WeeklyMenu(this.menuPlan);
}

class IANutricionalScreen extends StatefulWidget {
  final List<ReceiptItem> scannedItems; 

  const IANutricionalScreen({super.key, required this.scannedItems});

  @override
  State<IANutricionalScreen> createState() => _IANutricionalScreenState();
}

class _IANutricionalScreenState extends State<IANutricionalScreen> {
  WeeklyMenu? _weeklyMenu;
  bool _isLoading = true;
  String? _errorMessage;

  // ⚠️ CLAVE DE API y URL (Copiar de HomeScreen) ⚠️
  final String apiKey = "AIzaSyBYS_97Q3VtHrdjpo9thLPSyNooICgYzEI"; 
  final String apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent";

  // ⭐️ LISTAS MAESTRAS DEFINIDAS (COHERENTE CON EL PERFIL) ⭐️
  // El valor por defecto de Firestore para la dieta es 'Ninguna' o el valor guardado
  final List<String> _masterDietOptions = [
    'Ninguna', 
    'Vegetariana',
    'Vegana',
    'Sin Gluten',
    'Keto',
    'Paleo',
  ];
  final List<String> _menuTypeOptions = ['Plan Semanal', 'Receta Única'];
  final List<int> _servingOptions = [1, 2, 3, 4, 5];
  
  // ⭐️ PREFERENCIAS CARGADAS (Iniciamos con el valor seguro) ⭐️
  String _currentDiet = 'Ninguna'; // ⭐️ INICIO SEGURO ⭐️
  String _menuType = 'Receta Única'; 
  int _numServings = 1; 

  @override
  void initState() {
    super.initState();
    _loadAndDecide(); 
  }

  // --- 1. CARGAR PREFERENCIAS DESDE FIRESTORE (CORREGIDA) ---
  Future<void> _loadAndDecide() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          
          // ⭐️ CORRECCIÓN CLAVE: Usar 'Ninguna' como fallback si el valor de Firestore es nulo. ⭐️
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
    
    _decideAndGenerate();
  }

  // --- 2. DECISIÓN Y FLUJO (NUEVA LÓGICA DE USUARIO) ---
  void _decideAndGenerate() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final numItems = widget.scannedItems.length;
    
    if (numItems < 3) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Consideramos que son pocos ingredientes para generar un menú. Necesitas al menos 3.';
      });
      return;
    }
    
    _menuType = 'Receta Única';
    _generateMenu();
  }
  
  // --- 3. GENERACIÓN DE MENÚ CON GEMINI API ---
  Future<void> _generateMenu() async {
    final itemsList = widget.scannedItems.map((i) => '${i.item} (x${i.qty})').join(', ');
    String prompt;
    
    // El prompt usa las preferencias cargadas (dieta, raciones)
    if (_menuType == 'Plan Semanal') {
      prompt = "Genera un plan de menú semanal balanceado para la dieta '$_currentDiet' y para $_numServings persona(s), utilizando los siguientes ingredientes comprados: [$itemsList]. El menú debe ser fácil de seguir, incluir desayuno, comida y cena, y priorizar la salud y el uso de estos ingredientes. Devuelve el resultado en formato de texto simple con encabezados por día (Lunes, Martes, Miércoles, etc.) y subencabezados por tiempo de comida.";
    } else { // Receta Única (3 Opciones)
      prompt = "Crea tres (3) opciones de recetas simples, detalladas y con el perfil de dieta '$_currentDiet', que use la mayor cantidad posible de estos ingredientes: [$itemsList]. Para cada opción, dame primero el Título, luego una Descripción Breve de una sola frase, y finalmente los Ingredientes y Pasos. Separa cada receta con una línea de guiones (----).";
    }

    try {
      final payload = {
          "contents": [
            {"role": "user", "parts": [
              {"text": prompt}
            ]}
          ],
          "generationConfig": {
            "temperature": 0.7, 
          },
      };

      final response = await _fetchWithExponentialBackoff(
        Uri.parse('$apiUrl?key=$apiKey'),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final generatedText = jsonResponse['candidates'][0]['content']['parts'][0]['text'] as String;
        
        // ⭐️ Guardado del texto generado (Lógica a implementar si se desea) ⭐️
        // if (_menuType == 'Receta Única') { await _saveGeneratedRecipes(generatedText); }

        setState(() {
          _weeklyMenu = WeeklyMenu(generatedText);
        });
      } else {
        throw Exception('API falló con código ${response.statusCode}. Mensaje: ${response.body}');
      }

    } catch (e) {
      _showError('Fallo al contactar a la IA: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- 4. FUNCIÓN PARA GENERAR PLAN SEMANAL (BOTÓN OPCIONAL) ---
  void _generateWeeklyPlan() {
    if (_menuType == 'Plan Semanal') return; 
    
    setState(() {
      _menuType = 'Plan Semanal';
      _isLoading = true;
    });
    
    _generateMenu(); // Lanza la generación del Plan Semanal
  }

  // --- 5. FUNCIÓN DE BACKOFF (REINTENTOS) ---
  Future<http.Response> _fetchWithExponentialBackoff(Uri uri, {String? body}) async {
    const maxRetries = 3; 
    const initialDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
        if (response.statusCode < 500 && response.statusCode != 429) return response;
      } catch (e) {
        // Ignorar errores de red y reintentar
      }

      if (i < maxRetries - 1) {
        final delay = initialDelay * (1 << i);
        await Future.delayed(delay);
      }
    }
    return http.Response('{"error": "Tiempo de espera agotado o error de red."}', 500); 
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

  // Vista para Plan Semanal (Editable por secciones)
  Widget _buildWeeklyPlanView(String menuPlan) {
    final List<String> days = menuPlan.split(RegExp(r'\n(?=Lunes|Martes|Miércoles|Jueves|Viernes|Sábado|Domingo)', caseSensitive: false));

    return Column(
      children: days.map((dayPlan) {
        if (dayPlan.trim().isEmpty) return const SizedBox.shrink();
        
        final parts = dayPlan.trim().split(':');
        final day = parts[0].trim().replaceAll('\n', '');
        final content = parts.length > 1 ? parts.sublist(1).join(':').trim() : 'Contenido no especificado.';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ExpansionTile(
            title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.edit, color: Colors.green), 
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(content, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  // Vista para Receta Única (Listado de Tarjetas)
  Widget _buildRecipeListView(String menuPlan) {
  // 💡 Asume que Gemini separa las recetas con una línea de guiones (----)
  final recipeBlocks = menuPlan.split(RegExp(r'-----|----', caseSensitive: false)); 
  final recipes = recipeBlocks.where((b) => b.trim().isNotEmpty).take(3).toList();

  return SizedBox(
    height: 300, 
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipeContent = recipes[index]; 
        final recipeLines = recipeContent.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        
        final recipeTitle = recipeLines.isNotEmpty ? recipeLines.first : 'Receta Sugerida';
        // ⭐️ EXTRAEMOS LA DESCRIPCIÓN (Asume que es la segunda línea) ⭐️
        final recipeDescription = recipeLines.length > 1 ? recipeLines[1] : 'Descripción no disponible.';
        
        final displayTitle = recipeTitle.length > 30 ? '${recipeTitle.substring(0, 30)}...' : recipeTitle;
          return GestureDetector(
            onTap: () {
              // ⭐️ NAVEGACIÓN A DETALLES DE LA RECETA ⭐️
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(
                    recipeContent: recipeContent, 
                    recipeTitle: displayTitle,
                  ),
                ),
              );
            },
            child: Container(
            width: 220,
            margin: const EdgeInsets.only(right: 16),
            child: Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              // ⭐️ DISEÑO DE TARJETA MEJORADO (Basado en el ejemplo visual) ⭐️
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 150, // Altura fija para el placeholder de la imagen
                    color: Colors.lightGreen.shade100, 
                    alignment: Alignment.center,
                    child: const Icon(Icons.restaurant_menu, size: 50, color: Colors.green),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0),
                    child: Text(
                      recipeTitle, // Título completo
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: Text(
                      recipeDescription, // ⭐️ DESCRIPCIÓN BREVE ⭐️
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  // Botón 'Ver Receta'
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0, bottom: 8.0),
                      child: Text('Ver Receta', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
  // INTERFAZ PRINCIPAL
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA Nutricional: Menú Semanal')),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 10),
          Text('Generando tu menú semanal con IA...'),
        ],
      ));
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error al generar el menú: $_errorMessage', style: const TextStyle(color: Colors.red)));
    }
    
    // Contenido principal: Opciones de Modificación + Resultado
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModificationOptions(),
          
          const SizedBox(height: 20),
          
          Text(
            'Resultado: ${_menuType == 'Plan Semanal' ? 'Plan Semanal' : 'Recetas Sugeridas'}', 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const Divider(),
          
          // ⭐️ MUESTRA LA VISTA CORRECTA ⭐️
          if (_weeklyMenu != null)
            _menuType == 'Plan Semanal' 
              ? _buildWeeklyPlanView(_weeklyMenu!.menuPlan) 
              : _buildRecipeListView(_weeklyMenu!.menuPlan)
          else
            const Text('No hay suficiente información para generar una sugerencia.'),
        ],
      ),
    );
  }
  
  // WIDGET PARA LAS PREFERENCIAS DEL USUARIO (CON BOTÓN OPCIONAL)
  Widget _buildModificationOptions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajustar Plan:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Selector de Menú (Modo actual)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Modo Actual'),
              value: _menuType,
              items: _menuTypeOptions // ⭐️ Usa la lista correcta
                  .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _menuType = value;
                  });
                  _generateMenu(); // Regenerar al cambiar el modo
                }
              },
            ),
            const SizedBox(height: 10),

            // Selector de Dieta (Vegano, Gluten-Free, etc.)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Tipo de Dieta (Actual: $_currentDiet)'),
              value: _currentDiet,
              items: _masterDietOptions // ⭐️ USAMOS LA LISTA QUE COINCIDE CON FIRESTORE ⭐️
                  .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentDiet = value;
                  });
                  // 💡 Opcional: _generateMenu() si cambiar la dieta debe regenerar
                }
              },
            ),
            const SizedBox(height: 10),

            // Selector de Raciones
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: 'Raciones (Actual: $_numServings)'),
                    value: _numServings,
                    items: _servingOptions // Usa la lista correcta
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
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
                // Botón para Regenerar el Menú
                ElevatedButton(
                  onPressed: _decideAndGenerate, // Lanza la generación (ahora usa las nuevas preferencias)
                  child: const Text('Regenerar'),
                ),
              ],
            ),

            // ⭐️ BOTÓN OPCIONAL DE PLAN SEMANAL ⭐️
            if (_menuType == 'Receta Única')
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateWeeklyPlan,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('¿Quieres crear un Plan Semanal?', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, 
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}