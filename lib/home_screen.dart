// lib/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
// ⛔️ ELIMINAMOS EL IMPORT DE 'main.dart' que ya no se usa aquí
import 'package:nutriticket/receipt_item.dart'; // Para el modelo de datos

import 'perfil_screen.dart';
import 'recetas_screen.dart';
import 'ia_nutricional_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  File? _pickedImage;
  bool _isLoading = false;
  List<ReceiptItem> _receiptItems = [];

  // ... (apiKey y apiUrl se quedan igual) ...
  final String apiKey = "AIzaSyBYS_97Q3VtHrdjpo9thLPSyNooICgYzEI";
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  final List<Widget> _widgetOptions = [
    const Center(child: Text('Inicio: Menú semanal')), // 0
    const RecetasScreen(), // 1
    const Center(child: Text('Presiona Escanear para comenzar.')), // 2
    const PerfilScreen(), // 3
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // ... (Todas las funciones de escaneo: _onScanPressed, _pickImage, _scanReceipt, _fetchWithExponentialBackoff, _showError, _showResultsDialog)
  // ... (SE QUEDAN EXACTAMENTE IGUAL) ...
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

    setState(() {
      _pickedImage = File(pickedFile.path);
      _receiptItems = [];
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
    });

    try {
      final bytes = await _pickedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(_pickedImage!.path) ?? 'image/jpeg';

      final responseSchema = {
        "type": "ARRAY",
        "items": {
          "type": "OBJECT",
          "properties": {
            "item": {"type": "STRING", "description": "Nombre del producto."},
            "qty": {
              "type": "NUMBER",
              "description": "Cantidad de artículos, usa 1 por defecto.",
            },
          },
          "required": ["item", "qty"],
        },
      };

      final payload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    "Extrae la lista de productos y cantidad del ticket. Devuelve la lista como un JSON siguiendo el esquema proporcionado. Ignora líneas de impuestos, subtotales o totales.",
              },
              {
                "inlineData": {"mimeType": mimeType, "data": base64Image},
              },
            ],
          },
        ],
        "generationConfig": {
          "responseMimeType": "application/json",
          "responseSchema": responseSchema,
        },
      };

      final response = await _fetchWithExponentialBackoff(
        Uri.parse('$apiUrl?key=$apiKey'),
        body: jsonEncode(payload),
      );

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
          'Error en la API: ${response.statusCode}. Mensaje: ${response.body}',
        );
      }
    } catch (e) {
      _showError('Ocurrió un error en el escaneo: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- 4. IMPLEMENTACIÓN DE BACKOFF (REINTENTOS) ---
  Future<http.Response> _fetchWithExponentialBackoff(
    Uri uri, {
    String? body,
  }) async {
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
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
    return http.Response(
      '{"error": "Tiempo de espera agotado o error de red."}',
      500,
    );
  }

  // --- FUNCIONES DE INTERFAZ ---

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showResultsDialog() {
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Producto',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Cant.',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 10, thickness: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ..._receiptItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.item,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '${item.qty}x',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20, thickness: 2),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          IANutricionalScreen(scannedItems: _receiptItems),
                    ),
                  );
                },
                child: const Text('Analizar Nutrición y Menú'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ⛔️ ELIMINAMOS LA FUNCIÓN _logout() DE AQUÍ. LA MOVEREMOS A perfil_screen.dart ⛔️

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- ✅ MODIFICACIÓN AQUÍ ---
      // Oculta el AppBar si el índice es 3 (Perfil), de lo contrario muéstralo.
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              title: const Text('NutriTicket'),
            ),
      // --- ✅ FIN DE LA MODIFICACIÓN ---
      body: Stack(
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
                    Text(
                      'Analizando el ticket con IA...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _onScanPressed,
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
            const SizedBox(width: 48), // Espacio para el botón flotante
            _buildNavItem(Icons.analytics, 'IA Nutricional', 2),
            _buildNavItem(Icons.person, 'Perfil', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int itemIndex) {
    final isActive = _selectedIndex == itemIndex;
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
