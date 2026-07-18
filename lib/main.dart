import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// Globalna varijabla koja drži popis svih kamera na mobitelu
List<CameraDescription> cameras = [];

Future<void> main() async {
  // Osiguravamo da je sustav spreman prije nego zatražimo pristup hardveru
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

  @override
  void initState() {
    super.initState();
    // Ako uređaj ima kameru, inicijaliziramo prvu (najčešće glavna stražnja) u najvišoj rezoluciji
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.max,
        enableAudio: false, // Ne treba nam mikrofon za mjerenje pločica
      );
      _initializeControllerFuture = _controller!.initialize();
    }
  }

  @override
  void dispose() {
    // Gasimo kameru kada se aplikacija zatvori radi štednje baterije
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. SLOJ: Živa slika s kamere
          Positioned.fill(
            child: cameras.isEmpty 
                ? const Center(child: Text("Kamera nije pronađena"))
                : FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        // Kamera je spremna, prikazujemo sliku
                        return CameraPreview(_controller!);
                      } else {
                        // Dok se kamera pali, vrtimo indikator
                        return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
                      }
                    },
                  ),
          ),

          // 2. SLOJ: UI Elementi i stakleni paneli
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.deepOrange, size: 12),
                      const SizedBox(width: 8),
                      const Text(
                        "AR TILE HELPER",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text("Sustav spreman"),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Prazan prostor za buduće dimenzije i alate
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6), // Glassmorphism baza
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Dimenzije Pločice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      Text("Ovdje dolaze inputi i preseti...", style: TextStyle(color: Colors.white54)),
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
}
