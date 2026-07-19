import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_flutterflow/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_session_manager.dart';

void main() {
  runApp(const KeramicarskiAlat());
}

class KeramicarskiAlat extends StatelessWidget {
  const KeramicarskiAlat({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ARRadniEkran(),
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
          // 1. OVO JE SRCE APLIKACIJE: Pravi 3D AR prostor koji skenira ravnine
          ARView(
            onARViewCreated: onARViewCreated,
            // Prepoznajemo i podove (horizontal) i zidove (vertical)
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical, 
          ),
          
          // 2. TVOJ NOVI ČISTI UI (Bez starog rastera)
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.black54,
              child: const Text(
                "AR TILE HELPER - 3D Skeniranje aktivno",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
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

    // Inicijalizacija AR motora
    this.arSessionManager!.onInitialize(
          showFeaturePoints: true, // Prikazuje sitne točkice dok hvata geometriju sobe
          showPlanes: true,        // Prikazuje mrežu kada prepozna podlogu za pločice
          showWorldOrigin: false,
        );
    this.arObjectManager!.onInitialize();
  }
}
