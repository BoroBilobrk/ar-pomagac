import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_flutterflow/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_node.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const KeramicarskiAlat());
}

class KeramicarskiAlat extends StatelessWidget {
  const KeramicarskiAlat({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ARRadniEkran(),
    );
  }
}

class ARRadniEkran extends StatefulWidget {
  const ARRadniEkran({Key? key}) : super(key: key);

  @override
  _ARRadniEkranState createState() => _ARRadniEkranState();
}

class _ARRadniEkranState extends State<ARRadniEkran> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  
  // Lista u koju spremamo svaku postavljenu pločicu kako bismo ih mogli obrisati
  List<ARNode> postavljenePlocice = [];
  
  // Početni format pločice (u metrima)
  double sirinaPlocice = 0.6; // 60 cm
  double duzinaPlocice = 0.6; // 60 cm

  @override
  void dispose() {
    super.dispose();
    arSessionManager?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. AR PROSTOR
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical, 
          ),
          
          // 2. STATUSNA TRAKA
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "BRO-KER AR - Skeniranje...",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 3. KONTROLNA PLOČA (GUMBI)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Kasnije ćemo ovdje dodati izbornik za dimenzije (120x60, 30x30 itd.)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Aktiviran format: 60x60 cm")),
                    );
                  },
                  icon: const Icon(Icons.grid_on),
                  label: const Text("60x60"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: ocistiPod,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text("Očisti"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: true, 
          showPlanes: true,        
          showWorldOrigin: false,
        );
    this.arObjectManager!.onInitialize();
    
    // Slušamo dodir prsta po ekranu
    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  // Funkcija koja se okida kada prstom dotakneš podlogu
  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    // Ako nismo pogodili ravninu, prekidamo
    if (hitTestResults.isEmpty) return;

    // Uzimamo prvi pogodak koji je prepoznata ravnina (pod/zid)
    var singleHitTestResult = hitTestResults.firstWhere((result) => result.type == ARHitTestResultType.plane);
    
    var transform = singleHitTestResult.worldTransform;
    
    // Stvaramo 3D model pločice
    var novaPlocica = ARNode(
        type: NodeType.webGLB,
        // Za početak koristimo osnovnu 3D kocku sa servera koju ćemo spljoštiti u pločicu
        uri: "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Box/glTF-Binary/Box.glb",
        // Skaliranje: širina, debljina (1cm), dužina
        scale: vector.Vector3(sirinaPlocice, 0.01, duzinaPlocice),
        position: vector.Vector3(
            transform.getColumn(3).x,
            transform.getColumn(3).y,
            transform.getColumn(3).z),
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0));
        
    // Postavljamo pločicu u AR svijet
    bool? uspjesnoDodano = await arObjectManager!.addNode(novaPlocica);
    if (uspjesnoDodano == true) {
      postavljenePlocice.add(novaPlocica);
    }
  }

  // Funkcija za brisanje svih pločica s poda
  void ocistiPod() {
    for (var plocica in postavljenePlocice) {
      arObjectManager!.removeNode(plocica);
    }
    postavljenePlocice.clear();
  }
}
