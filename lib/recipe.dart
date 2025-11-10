// lib/recipe.dart

class Recipe {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int baseServings;
  final List<Ingredient> ingredients;
  final String instructions;
  final List<String> tags; 

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl = 'placeholder.png', 
    required this.baseServings,
    required this.ingredients,
    required this.instructions,
    required this.tags,
  });

  String get ingredientNames => ingredients.map((i) => i.name.toLowerCase()).join(', ');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'baseServings': baseServings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> data, String id) {
    var ingredientList = data['ingredients'] as List<dynamic>? ?? [];
    
    final int servings = (data['baseServings'] is int) 
      ? data['baseServings'] 
      : (data['baseServings'] as num?)?.toInt() ?? 4;

    return Recipe(
      id: id,
      title: data['title'] ?? 'Receta Desconocida',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? 'placeholder.png',
      baseServings: servings,
      instructions: data['instructions'] ?? 'Pasos no disponibles.',
      tags: List<String>.from(data['tags'] ?? []),
      ingredients: ingredientList.map((i) => Ingredient.fromMap(i as Map<String, dynamic>)).toList(),
    );
  }
}

class Ingredient {
  final String name;
  final double quantity;
  final String unit; 

  Ingredient({required this.name, required this.quantity, required this.unit});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> data) {
    final double qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
    
    return Ingredient(
      name: data['name'] ?? 'Ingrediente',
      quantity: qty,
      unit: data['unit'] ?? 'unidad(es)',
    );
  }
}