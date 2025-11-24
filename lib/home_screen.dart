// lib/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutriticket/custom_loader.dart'; // Asegúrate que la ruta sea correcta

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
// ⛔️ ELIMINAMOS EL IMPORT DE 'main.dart' que ya no se usa aquí
import 'package:nutriticket/receipt_item.dart'; // Para el modelo de datos
import 'package:nutriticket/secrets.dart'; // Importa tu archivo secreto

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
  final String apiKey = googleApiKey;
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
    // 1. Inicializamos un Set con los índices de todos los elementos seleccionados por defecto
    final Set<int> selectedIndices =
        List.generate(_receiptItems.length, (index) => index).toSet();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 2. Usamos StatefulBuilder para que el diálogo pueda actualizarse (poner/quitar checks)
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5,
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- TÍTULO CENTRADO ---
                        const Text(
                          'Productos Extraídos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E3A59),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Desmarca los que no quieras incluir',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(height: 20),

                        // --- LISTA INTERACTIVA (CHECKLIST) ---
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(10),
                              shrinkWrap: true,
                              itemCount: _receiptItems.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _receiptItems[index];
                                final isSelected =
                                    selectedIndices.contains(index);

                                return InkWell(
                                  // Al tocar, invertimos la selección
                                  onTap: () {
                                    setStateDialog(() {
                                      if (isSelected) {
                                        selectedIndices.remove(index);
                                      } else {
                                        selectedIndices.add(index);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Row(
                                      children: [
                                        // Icono dinámico (Check verde o Circulo gris)
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          size: 22,
                                          color: isSelected
                                              ? const Color(0xFF4CAF50)
                                              : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 12),
                                        // Nombre del producto
                                        Expanded(
                                          child: Text(
                                            item.item,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              // Si no está seleccionado, el texto se ve "deshabilitado"
                                              color: isSelected
                                                  ? Colors.black87
                                                  : Colors.grey.shade400,
                                              decoration: isSelected
                                                  ? null
                                                  : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        // Cantidad
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.grey.shade300),
                                            ),
                                            child: Text(
                                              'x${item.qty}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // --- BOTÓN ANALIZAR NUTRICIÓN ---
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: selectedIndices.isEmpty
                                ? null // Deshabilitar si no hay nada seleccionado
                                : () {
                                    // 1. Filtramos la lista original
                                    final List<ReceiptItem> finalItems = [];
                                    for (int i = 0;
                                        i < _receiptItems.length;
                                        i++) {
                                      if (selectedIndices.contains(i)) {
                                        finalItems.add(_receiptItems[i]);
                                      }
                                    }

                                    Navigator.pop(context); // Cerrar diálogo

                                    // 2. Enviamos solo los items filtrados
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            IANutricionalScreen(
                                                scannedItems: finalItems),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              selectedIndices.isEmpty
                                  ? 'Selecciona al menos uno'
                                  : 'Analizar Nutrición',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- BOTÓN "X" DE CERRAR ---
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ⛔️ ELIMINAMOS LA FUNCIÓN _logout() DE AQUÍ. LA MOVEREMOS A perfil_screen.dart ⛔️

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ APP BAR: Se oculta si es la pestaña de perfil O si está cargando
      appBar: (_selectedIndex == 3 || _isLoading)
          ? null
          : AppBar(
              title: const Text('NutriTicket'),
            ),
      body: Stack(
        children: [
          // El contenido principal (solo visible si no carga, por el Stack)
          _widgetOptions[_selectedIndex],

          // El cargador a pantalla completa
          if (_isLoading)
            const Positioned.fill(
              child: CustomLogoLoader(
                text: 'Analizando el ticket con IA...',
              ),
            ),
        ],
      ),
      // ✅ BOTÓN FLOTANTE: Se oculta si está cargando
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _onScanPressed,
              backgroundColor: Colors.lightGreen,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.qr_code_scanner, size: 28),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // ✅ BARRA INFERIOR: Se oculta si está cargando
      bottomNavigationBar: _isLoading
          ? null
          : BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 'Inicio', 0),
                  _buildNavItem(Icons.restaurant, 'Recetas', 1),
                  const SizedBox(width: 48),
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
