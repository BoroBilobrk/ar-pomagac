import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Greška pri učitavanju kamere: $e");
  }
  runApp(const BroKerApp());
}

class BroKerApp extends StatelessWidget {
  const BroKerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFFF6B00),
          inactiveTrackColor: Colors.white24,
          thumbColor: const Color(0xFFFF6B00),
          overlayColor: const Color(0x29FF6B00),
          valueTextStyle: const TextStyle(color: Colors.white),
        ),
      ),
      home: const ARScreen(),
    );
  }
}

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // State varijable za raster i proračun
  double tileWidth = 600.0;  // u mm
  double tileHeight = 600.0; // u mm
  double groutWidth = 2.0;   // u mm
  double rotationAngle = 0.0; // u stupnjevima
  double gridScale = 68.0;   // postotak (od 10 do 200)
  
  String selectedPreset = "60x60 cm";
  String lockMode = "ZAMRZNI SLIKU";
  bool sensorsActive = true;

  // Kontroleri za input polja
  final TextEditingController _widthController = TextEditingController(text: "600");
  final TextEditingController _heightController = TextEditingController(text: "600");
  final TextEditingController _groutController = TextEditingController(text: "2");

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.max,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _groutController.dispose();
    super.dispose();
  }

  void _updatePreset(String presetName, double w, double h) {
    setState(() {
      selectedPreset = presetName;
      tileWidth = w;
      tileHeight = h;
      _widthController.text = w.toInt().toString();
      _heightController.text = h.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. SLOJ: Živa slika s kamere bez rubova
          Positioned.fill(
            child: cameras.isEmpty 
                ? const Center(child: Text("Kamera nije pronađena"))
                : FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.previewSize!.height,
                              height: _controller!.value.previewSize!.width,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        );
                      } else {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                      }
                    },
                  ),
          ),

          // 2. SLOJ: Interaktivna 2D AR Mreža (Custom Graphics)
          Positioned.fill(
            child: CustomPaint(
              painter: TileGridPainter(
                width: tileWidth,
                height: tileHeight,
                grout: groutWidth,
                rotation: rotationAngle,
                scale: gridScale,
              ),
            ),
          ),

          // 3. SLOJ: UI Elementi na vrhu i dnu ekrana
          SafeArea(
            child: Column(
              children: [
                // Gornja traka sa statusima
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AR TILE",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, letterSpacing: 1.5, color: Colors.white),
                          ),
                          Text(
                            "HELPER",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, letterSpacing: 1.5, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.greenAccent, width: 1.5),
                        ),
                        child: const Text(
                          "AI\nSpreman",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11, height: 1.1),
                        ),
                      ),
                      const Spacer(),
                      // Indikator statusa sustava
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Color(0xFFFF6B00), size: 10),
                            SizedBox(width: 6),
                            Text("Sustav spreman", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                // Horizontalno skrolajući paneli na dnu
                SizedBox(
                  height: 310,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // PANEL 1: Dimenzije Pločice
                      _buildGlassPanel(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.architecture, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text("Dimenzije Pločice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    label: "ŠIRINA W (MM)",
                                    controller: _widthController,
                                    onChanged: (val) => setState(() => tileWidth = double.tryParse(val) ?? 600.0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    label: "VISINA H (MM)",
                                    controller: _heightController,
                                    onChanged: (val) => setState(() => tileHeight = double.tryParse(val) ?? 600.0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              label: "ŠIRINA FUGE J (MM)",
                              controller: _groutController,
                              onChanged: (val) => setState(() => groutWidth = double.tryParse(val) ?? 2.0),
                            ),
                            const SizedBox(height: 14),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildPresetChip("60x60 cm", 600, 600),
                                  _buildPresetChip("30x60 cm", 300, 600),
                                  _buildPresetChip("120x60 cm", 1200, 600),
                                  _buildPresetChip("30x30 cm", 300, 300),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),

                      // PANEL 2: Poravnanje Rastera i Kontrole
                      _buildGlassPanel(
                        width: 340,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sync, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text("Poravnanje Rastera", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 14),
                            
                            // Slajder za Rotaciju
                            _buildSliderLabel("Rotacija", "${rotationAngle.toInt()}°"),
                            Slider(
                              value: rotationAngle,
                              min: 0,
                              max: 360,
                              onChanged: (val) => setState(() => rotationAngle = val),
                            ),

                            // Slajder za Skalu
                            _buildSliderLabel("Veličina (Skala)", "${gridScale.toInt()}%"),
                            Slider(
                              value: gridScale,
                              min: 10,
                              max: 200,
                              onChanged: (val) => setState(() => gridScale = val),
                            ),

                            const Text("NAČIN ZAKLJUČAVANJA:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildRadioOption("ZAMRZNI SLIKU"),
                                const SizedBox(width: 16),
                                _buildRadioOption("ŽIROSKOP AR (UŽIVO)"),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // PANEL 3: Akcijski Alati i Hardver
                      _buildGlassPanel(
                        width: 280,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatusActionButton(
                                    label: "Senzori\naktivni",
                                    icon: Icons.phonelink_setup,
                                    isActive: sensorsActive,
                                    onTap: () => setState(() => sensorsActive = !sensorsActive),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatusActionButton(
                                    label: "Kamera",
                                    icon: Icons.camera_alt,
                                    isActive: false,
                                    onTap: () {},
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        rotationAngle = 0.0;
                                        gridScale = 68.0;
                                      });
                                    },
                                    child: const Text("Reset rastera", style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0084FF).withOpacity(0.3),
                                      foregroundColor: const Color(0xFF66B5FF),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF0084FF))),
                                    ),
                                    icon: const Icon(Icons.smart_toy, size: 16),
                                    label: const Text("AI Skeniraj", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Veliki Glavni Action Button na dnu panela
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B00),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.lock, size: 18),
                                  label: const Text("Zaključaj i Zamrzni", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  onPressed: () {},
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pomoćne UI komponente unutar klase ekrana
  Widget _buildGlassPanel({required double width, required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151922).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller, required Function(String) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.black38,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF6B00))),
          ),
        ),
      ],
    );
  }

    Widget _buildPresetChip(String label, double w, double h) {
    final bool isSelected = selectedPreset == label;
    return GestureDetector(
      onTap: () => _updatePreset(label, w, h),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B00).withOpacity(0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : Colors.white24, width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? const Color(0xFFFF6B00) : Colors.white)),
      ),
    );
  }

  Widget _buildSliderLabel(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRadioOption(String title) {
    final bool isSelected = lockMode == title;
    return GestureDetector(
      onTap: () => setState(() => lockMode = title),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : Colors.white54, width: 2),
            ),
            child: isSelected ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF6B00)))) : null,
          ),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusActionButton({required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00FF66).withOpacity(0.1) : Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? const Color(0xFF00FF66) : Colors.white24, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? const Color(0xFF00FF66) : Colors.white70),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.1, color: isActive ? const Color(0xFF00FF66) : Colors.white70))),
          ],
        ),
      ),
    );
  }
}

// 4. KORAK: Custom Painter za crtanje mreže pločica i fuge u realnom vremenu
class TileGridPainter extends CustomPainter {
  final double width;
  final double height;
  final double grout;
  final double rotation;
  final double scale;

  TileGridPainter({
    required this.width,
    required this.height,
    required this.grout,
    required this.rotation,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 80);
    
    canvas.save();
    // Translacija i rotacija oko centra ekrana
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi / 180);

    // Pretvaranje milimetarskih dimenzija u piksele pomoću skale sustava
    final double factor = scale / 300.0; 
    final double tWidth = width * factor;
    final double tHeight = height * factor;
    final double gWidth = grout * factor;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final groutPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Laser Orange oznaka za istaknuti fokus/križ
    final highlightPaint = Paint()
      ..color = const Color(0xFFFF6B00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final int steps = 8; // Broj vidljivih redova/stupaca oko centra

    // 1. Crtanje podloge za fuge i rastera
    for (int i = -steps; i <= steps; i++) {
      for (int j = -steps; j <= steps; j++) {
        final double x = i * (tWidth + gWidth);
        final double y = j * (tHeight + gWidth);

        // Iscrtavanje pojedinačne pločice
        final rect = Rect.fromLTWH(x, y, tWidth, tHeight);
        canvas.drawRect(rect, linePaint);

        // Dodavanje prostora za širinu fuge
        if (gWidth > 0) {
          final groutRectRight = Rect.fromLTWH(x + tWidth, y, gWidth, tHeight + gWidth);
          final groutRectBottom = Rect.fromLTWH(x, y + tHeight, tWidth + gWidth, gWidth);
          canvas.drawRect(groutRectRight, groutPaint);
          canvas.drawRect(groutRectBottom, groutPaint);
        }
      }
    }

    // 2. Crtanje specifične Laser Orange linije s čvorom sa slike
    canvas.drawPoints(
      PointMode.points,
      [const Offset(0, 0)],
      Paint()
        ..color = const Color(0xFFFF6B00)
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round,
    );
    
    // Isticanje glavne početne pločice od nulte točke
    canvas.drawRect(Rect.fromLTWH(0, 0, tWidth, tHeight), highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileGridPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.grout != grout ||
        oldDelegate.rotation != rotation ||
        oldDelegate.scale != scale;
  }
}
