import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TibiaRadarApp());
}

class TibiaRadarApp extends StatelessWidget {
  const TibiaRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tibia Tactical Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090C),
        primaryColor: const Color(0xFF00E5FF),
      ),
      home: const RadarScreen(),
    );
  }
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final String world = 'Ferobra';
  final List<String> targets = ['fingor'];
  final TextEditingController _targetController = TextEditingController();
  
  Map<String, dynamic> onlineTargets = {};
  List<String> radarLogs = [];
  bool isScanning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    addLog("SISTEMA RADAR INICIALIZADO.");
    addLog("OBJETIVO PRINCIPAL FIJADO: FINGOR");
    scanRadar();
    _timer = Timer.periodic(const Duration(seconds: 45), (timer) {
      scanRadar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _targetController.dispose();
    super.dispose();
  }

  void addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      radarLogs.insert(0, "[$time] $message");
      if (radarLogs.length > 20) radarLogs.removeLast();
    });
  }

  Future<void> scanRadar() async {
    setState(() => isScanning = true);
    addLog("Escaneando servidores de $world...");

    try {
      final response = await http.get(
        Uri.parse('https://api.tibia.data.v4.tibia.lat/v4/world/$world'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List players = data['world']?['online_players'] ?? [];

        Map<String, dynamic> currentlyOnline = {};

        for (var p in players) {
          final String name = p['name'].toString().toLowerCase();
          if (targets.contains(name)) {
            currentlyOnline[name] = p;
            if (!onlineTargets.containsKey(name)) {
              addLog("⚠️ OBJETIVO DETECTADO: ${p['name']} (Lvl ${p['level']})");
            }
          }
        }

        for (var oldTarget in onlineTargets.keys) {
          if (!currentlyOnline.containsKey(oldTarget)) {
            addLog("🛑 OBJETIVO DESCONECTADO: ${oldTarget.toUpperCase()}");
          }
        }

        setState(() {
          onlineTargets = currentlyOnline;
        });
        addLog("Escaneo completado. ${players.length} jugadores en Ferobra.");
      }
    } catch (e) {
      addLog("ERROR: Falla de enlace satelital con TibiaData.");
    } finally {
      setState(() => isScanning = false);
    }
  }

  void addTarget() {
    final text = _targetController.text.trim().toLowerCase();
    if (text.isNotEmpty && !targets.contains(text)) {
      setState(() {
        targets.add(text);
      });
      addLog("Nuevo enemigo en lista negra: ${text.toUpperCase()}");
      _targetController.clear();
      scanRadar();
    }
  }

  void removeTarget(String name) {
    setState(() {
      targets.remove(name);
      onlineTargets.remove(name);
    });
    addLog("Objetivo removido: ${name.toUpperCase()}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E121A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isScanning ? const Color(0xFF00FFB2) : const Color(0xFF00E5FF),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "RADAR TÁCTICO // $world",
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: isScanning ? null : scanRadar,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101522),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: "NOMBRE DEL ENEMIGO...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => addTarget(),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                    onPressed: addTarget,
                    child: const Text("RASTREAR"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "LISTA NEGRA DE OBJETIVOS",
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 3,
              child: ListView.builder(
                itemCount: targets.length,
                itemBuilder: (context, index) {
                  final target = targets[index];
                  final isOnline = onlineTargets.containsKey(target);
                  final data = onlineTargets[target];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D111A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOnline ? const Color(0xFF00FFB2) : Colors.white12,
                        width: isOnline ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isOnline ? Icons.radar : Icons.person_off_outlined,
                        color: isOnline ? const Color(0xFF00FFB2) : Colors.grey,
                      ),
                      title: Text(
                        target.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isOnline ? Colors.white : Colors.white60,
                        ),
                      ),
                      subtitle: Text(
                        isOnline
                            ? "ONLINE | Nivel: ${data['level']} | ${data['vocation']}"
                            : "OFFLINE // DESCONECTADO",
                        style: TextStyle(
                          color: isOnline ? const Color(0xFF00FFB2) : Colors.grey,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                        onPressed: () => removeTarget(target),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Text(
              "CONSOLA DE EVENTOS EN VIVO",
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF040507),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.builder(
                  itemCount: radarLogs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      radarLogs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF80DEEA),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
