import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_flutterflow/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_node.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_anchor.dart';
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
  ARAnchorManager? arAnchorManager;
  
  List<ARNode> postavljenePlocice = [];
  List<ARAnchor> postavljenaSidra = [];
  
  // Početni format
  double sirinaPlocice = 0.6;
  double duzinaPlocice = 0.6;
  String aktivniFormat = "60x60";

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
          // 1. AR Kamera
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical, 
          ),
          
          // 2. NIŠAN (Crosshair) na sredini ekrana
          Center(
            child: IgnorePointer( // Ignorira dodir kako bi klik prošao do AR-a
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.add, color: Colors.redAccent.withOpacity(0.8), size: 24),
                ),
              ),
            ),
          ),

          // 3. Gornja traka sa statusom
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "BRO-KER AR - Format: $aktivniFormat",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 4. Donji gumbi (Format i Brisanje)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: prikaziIzbornikFormata,
                  icon: const Icon(Icons.photo_size_select_large),
                  label: Text(aktivniFormat),
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

  // Funkcija za otvaranje izbornika s formatima
  void prikaziIzbornikFormata() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Odaberi dimenzije pločice", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.crop_square),
                  title: const Text('60 x 60 cm'),
                  onTap: () => postaviFormat(0.6, 0.6, '60x60'),
                ),
                ListTile(
                  leading: const Icon(Icons.view_array),
                  title: const Text('120 x 60 cm'),
                  onTap: () => postaviFormat(1.2, 0.6, '120x60'),
                ),
                ListTile(
                  leading: const Icon(Icons.view_day),
                  title: const Text('120 x 20 cm (Imitacija drveta)'),
                  onTap: () => postaviFormat(1.2, 0.2, '120x20'),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('30 x 60 cm'),
                  onTap: () => postaviFormat(0.3, 0.6, '30x60'),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // Ažuriranje varijabli nakon odabira formata
  void postaviFormat(double sirina, double duzina, String naziv) {
    setState(() {
      sirinaPlocice = sirina;
      duzinaPlocice = duzina;
      aktivniFormat = naziv;
    });
    Navigator.of(context).pop();
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: true, 
          showPlanes: true,        
          showWorldOrigin: false,
        );
    this.arObjectManager!.onInitialize();
    
    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    ARHitTestResult? planeHit;
    for (var result in hitTestResults) {
      if (result.type == ARHitTestResultType.plane) {
        planeHit = result;
        break;
      }
    }
    
    if (planeHit == null) return;
    
    var novoSidro = ARPlaneAnchor(transformation: planeHit.worldTransform);
    bool? dodanoSidro = await arAnchorManager!.addAnchor(novoSidro);

    if (dodanoSidro == true) {
      postavljenaSidra.add(novoSidro);
      
      var novaPlocica = ARNode(
          type: NodeType.webGLB,
          uri: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Box/glTF-Binary/Box.glb",
          scale: vector.Vector3(sirinaPlocice, 0.01, duzinaPlocice),
          position: vector.Vector3(0.0, 0.0, 0.0), 
          rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0));
          
      bool? uspjesnoDodano = await arObjectManager!.addNode(novaPlocica, planeAnchor: novoSidro);
      if (uspjesnoDodano == true) {
        postavljenePlocice.add(novaPlocica);
      }
    }
  }

  void ocistiPod() {
    for (var plocica in postavljenePlocice) {
      arObjectManager!.removeNode(plocica);
    }
    for (var sidro in postavljenaSidra) {
      arAnchorManager!.removeAnchor(sidro);
    }
    postavljenePlocice.clear();
    postavljenaSidra.clear();
  }
}
