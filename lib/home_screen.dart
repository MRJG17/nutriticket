// lib/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

// ⭐️ NUEVAS IMPORTACIONES PARA GEMINI ⭐️
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:nutriticket/main.dart'; // Para AuthWrapper
import 'package:nutriticket/receipt_item.dart'; // Para el modelo de datos

// ✅ INICIO DE LA MODIFICACIÓN: Importamos las pantallas reales
import 'perfil_screen.dart';
import 'recetas_screen.dart';
import 'ia_nutricional_screen.dart';
// ✅ FIN DE LA MODIFICACIÓN

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ⭐️ VARIABLES DE ESCANEO DE GEMINI ⭐️
  File? _pickedImage;
  bool _isLoading = false;
  List<ReceiptItem> _receiptItems = [];
  String? _errorMessage;

  // ************************************************************
  // ** PASO CLAVE: DEBES INSERTAR TU CLAVE DE API AQUÍ **
  // ************************************************************
  // ⚠️ ¡REEMPLAZA "TU_CLAVE_AQUI" con tu clave real de la API de Gemini!
  final String apiKey = "AIzaSyBYS_97Q3VtHrdjpo9thLPSyNooICgYzEI";
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent";

  // ✅ INICIO DE LA MODIFICACIÓN: Usamos los widgets de las pantallas reales
  final List<Widget> _widgetOptions = [
    const Center(child: Text('Inicio: Menú semanal')), // Pantalla de Inicio
    const RecetasScreen(), // Pantalla de Recetas
    const IANutricionalScreen(), // Pantalla de IA
    const PerfilScreen(), // Pantalla de Perfil
  ];
  // ✅ FIN DE LA MODIFICACIÓN

  void _onItemTapped(int index) {
    if (index == 2) return;
    // Ajuste de índice: Si es 3 o 4 en la barra, se mapea a 2 o 3 en _widgetOptions
    setState(() => _selectedIndex = index > 2 ? index - 1 : index);
  }

  // --- 1. CAPTURA DE IMAGEN ---
  void _onScanPressed() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. GESTIONAR LA IMAGEN Y LLAMAR AL ESCANER ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ninguna imagen')),
        );
      }
      return;
    }

    // ⭐️ Actualiza el estado y lanza el escaneo de Gemini ⭐️
    setState(() {
      _pickedImage = File(pickedFile.path);
      _receiptItems = [];
      _errorMessage = null;
    });
    await _scanReceipt();
  }

  // --- 3. PROCESO DE ESCANEO CON GEMINI API ---
  Future<void> _scanReceipt() async {
    if (_pickedImage == null || apiKey == "TU_CLAVE_AQUI" || apiKey.isEmpty) {
      _showError('Error: Por favor, inserta la Clave de API de Gemini.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await _pickedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(_pickedImage!.path) ?? 'image/jpeg';

      // ⭐️ Definición del esquema JSON para la salida estructurada ⭐️
      final responseSchema = {
        "type": "ARRAY",
        "items": {
          "type": "OBJECT",
          "properties": {
            "item": {"type": "STRING", "description": "Nombre del producto."},
            "price": {
              "type": "NUMBER",
              "description": "Precio unitario o total del artículo."
            },
            "qty": {
              "type": "NUMBER",
              "description": "Cantidad de artículos, usa 1 por defecto."
            }
          },
          "required": ["item", "price"]
        }
      };

      final payload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    "Extrae la lista de productos, su precio y cantidad del ticket. Devuelve la lista como un JSON siguiendo el esquema proporcionado. Ignora líneas de impuestos, subtotales o totales."
              },
              {
                "inlineData": {
                  "mimeType": mimeType,
                  "data": base64Image,
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json",
          "responseSchema": responseSchema,
        },
      };

      // Llamada a la API con Backoff
      final response = await _fetchWithExponentialBackoff(
        Uri.parse('$apiUrl?key=$apiKey'),
        body: jsonEncode(payload),
      );

      // 4. Procesamiento de la respuesta
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final jsonText = jsonResponse['candidates'][0]['content']['parts'][0]
            ['text'] as String;

        final List<dynamic> parsedJsonList = jsonDecode(jsonText);

        setState(() {
          _receiptItems =
              parsedJsonList.map((item) => ReceiptItem.fromJson(item)).toList();
        });
        if (mounted) _showResultsDialog();
      } else {
        _showError(
            'Error en la API: ${response.statusCode}. Mensaje: ${response.body}');
      }
    } catch (e) {
      _showError('Ocurrió un error en el escaneo: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- 4. IMPLEMENTACIÓN DE BACKOFF (REINTENTOS) ---
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
        // Si no es un error de rate limit (429), devuelve la respuesta
        if (response.statusCode < 500 && response.statusCode != 429) {
          return response;
        }
      } catch (e) {
        // Ignorar errores de red y reintentar
      }

      if (i < maxRetries - 1) {
        final delay = initialDelay * (1 << i);
        await Future.delayed(delay);
      }
    }
    // Si todos los reintentos fallan, devuelve el último error
    return http.Response(
        '{"error": "Tiempo de espera agotado o error de red."}', 500);
  }

  // --- FUNCIONES DE INTERFAZ ---

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false); // Asegura que se quite el indicador
  }

  // Función para mostrar la lista de productos extraídos
  void _showResultsDialog() {
    final total = _receiptItems.fold<double>(
        0.0, (sum, item) => sum + (item.price * item.qty));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Productos Extraídos por IA'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lista de productos
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ..._receiptItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(item.item,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500))),
                              Text('${item.qty}x',
                                  style: const TextStyle(color: Colors.grey)),
                              Text(
                                  '\$${(item.price * item.qty).toStringAsFixed(2)}'),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const Divider(height: 20, thickness: 2),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL ESTIMADO:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                  // 💡 NAVEGACIÓN A LA PANTALLA DE IA NUTRICIONAL 💡
                  _onItemTapped(
                      2); // Selecciona el índice 2 (IA Nutricional) en la barra
                },
                child: const Text('Analizar Nutrición y Menú'),
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aquí puedes añadir un indicador de carga global si _isLoading es verdadero
    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriTicket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Navega al AuthWrapper, forzando el regreso a la pantalla de bienvenida
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        // Usamos Stack para el indicador de carga sobre la pantalla
        children: [
          _widgetOptions[_selectedIndex],
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text('Analizando el ticket con IA...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading
            ? null
            : _onScanPressed, // Desactiva el botón si está cargando
        backgroundColor: Colors.lightGreen,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Inicio', 0),
            _buildNavItem(Icons.restaurant, 'Recetas', 1),
            const SizedBox(width: 48),
            _buildNavItem(Icons.analytics, 'IA Nutricional',
                3), // Índice real de la barra
            _buildNavItem(Icons.person, 'Perfil', 4), // Índice real de la barra
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int itemIndex) {
    // La lógica de mapeo se hace en _onItemTapped, aquí solo calculamos si está activo
    final optionIndex = itemIndex > 2 ? itemIndex - 1 : itemIndex;
    final isActive = _selectedIndex == optionIndex;
    final color = isActive ? Colors.lightGreen : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(itemIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              Text(label, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
