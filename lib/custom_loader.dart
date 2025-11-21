// lib/custom_loader.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomLogoLoader extends StatefulWidget {
  final String text;

  const CustomLogoLoader({
    super.key,
    required this.text,
  });

  @override
  State<CustomLogoLoader> createState() => _CustomLogoLoaderState();
}

class _CustomLogoLoaderState extends State<CustomLogoLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<Color> _dotColors = const [
    Color(0xFFEF5350), // Rojo suave
    Color(0xFFBBDEFB), // Azul claro
    Color(0xFFFFCC80), // Naranja claro
    Color(0xFFE1BEE7), // Morado claro
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white, // Fondo Blanco
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO
            Image.asset(
              'assets/images/logo.png',
              height: 180,
            ),
            const SizedBox(height: 40),

            // BOLITAS ANIMADAS
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // ✅ AJUSTE: Reducimos el padding de 25.0 a 12.0
                // Esto las regresa un poco a la izquierda para equilibrarlas.
                return Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final delay = index * 0.2;
                      final value =
                          math.sin((_controller.value - delay) * math.pi * 2);

                      final double dy = value < 0 ? value * 12.0 : 0.0;
                      final double scale = 1.0 - (value.abs() * 0.2);

                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0),
                            height: 18.0,
                            width: 18.0,
                            decoration: BoxDecoration(
                              color: _dotColors[index],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            // TEXTO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
