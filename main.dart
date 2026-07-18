import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const BroKerApp());
}

class BroKerApp extends StatelessWidget {
  const BroKerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Tile Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // Preuzeto iz style.css: --bg-solid i --accent-color
        scaffoldBackgroundColor: const Color(0xFF0D1017),
        primaryColor: const Color(0xFFFF6600),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6600),
          secondary: Color(0xFF00E676), // --success-color
          error: Color(0xFFFF3D00), // --danger-color
        ),
        fontFamily: 'Outfit', // Tvoj odabrani font
      ),
      home: const ArCalculatorScreen(),
    );
  }
}

class ArCalculatorScreen extends StatefulWidget {
  const ArCalculatorScreen({super.key});

  @override
  State<ArCalculatorScreen> createState() => _ArCalculatorScreenState();
}

class _ArCalculatorScreenState extends State<ArCalculatorScreen> {
  // Ovdje će kasnije ići varijable stanja iz app.js (tileW, tileH, isLocked...)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Koristimo Stack da preklopimo UI preko kamere
      body: Stack(
        children: [
          // 1. SLOJ: AR Kamera (Placeholder)
          Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                'AR Kamera Feed',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),

          // 2. SLOJ: Canvas za crtanje rastera (Placeholder)
          // Ovdje će ići CustomPaint widget umjesto HTML5 Canvasa
          
          // 3. SLOJ: Korisničko sučelje (UI Container)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // HUD Header (Logo i Status)
                _buildHeader(),
                
                // Središnji dio (Desni Sidebar i prazan prostor za tapkanje)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // HUD Sidebar (Dimenzije, Kontrole)
                      _buildSidebar(),
                    ],
                  ),
                ),
                
                // HUD Footer (Upute)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Poravnajte raster s pločicom na ekranu, a zatim pritisnite "Zaključaj i Zamrzni".',
                    style: TextStyle(
                      color: const Color(0xFF90A0B8), // --text-secondary
                      fontSize: 14,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pretvoren .hud-header iz CSS-a
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6600),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0xFFFF6600), blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AR TILE HELPER',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Text('Sustav spreman', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Pretvoren .hud-sidebar i .hud-panel s Glassmorphism efektom
  Widget _buildSidebar() {
    return Container(
      width: 340,
      margin: const EdgeInsets.only(right: 20, top: 20, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // --panel-blur: 16px
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C).withOpacity(0.75), // --bg-primary
              border: Border.all(color: Colors.white.withOpacity(0.12)), // --border-color
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ovdje ćemo dodati tvoje kontrole (Inputi, Slideri, Gumbi)
                Text('📐 Dimenzije Pločice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 16),
                Text('Ovdje dolaze inputi i preseti...', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
