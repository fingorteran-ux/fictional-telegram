import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TibiaRadarApp());
}

// GENERADOR DE SONIDOS EN MEMORIA (WAV PURO)
class TacticalAudio {
  static final AudioPlayer _player = AudioPlayer();
  static bool soundEnabled = true;

  static Uint8List _createWav(int sampleRate, List<double> samples) {
    final byteData = ByteData(44 + samples.length * 2);
    byteData.setUint32(0, 0x52494646, Endian.big); // RIFF
    byteData.setUint32(4, 36 + samples.length * 2, Endian.little);
    byteData.setUint32(8, 0x57415645, Endian.big); // WAVE
    byteData.setUint32(12, 0x666d7420, Endian.big); // fmt 
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint32(36, 0x64617461, Endian.big); // data
    byteData.setUint32(40, samples.length * 2, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      byteData.setInt16(44 + i * 2, sample, Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  // DOS PITIDOS TÁCTICOS: "PI - PI"
  static Future<void> playBeepBeep() async {
    if (!soundEnabled) return;
    try {
      HapticFeedback.vibrate();
      const sampleRate = 22050;
      final samples = <double>[];
      
      // Pitido 1 (90ms - 1050 Hz)
      for (int i = 0; i < (sampleRate * 0.09).toInt(); i++) {
        samples.add(math.sin(2 * math.pi * 1050 * i / sampleRate));
      }
      // Silencio (60ms)
      for (int i = 0; i < (sampleRate * 0.06).toInt(); i++) {
        samples.add(0.0);
      }
      // Pitido 2 (110ms - 1250 Hz)
      for (int i = 0; i < (sampleRate * 0.11).toInt(); i++) {
        samples.add(math.sin(2 * math.pi * 1250 * i / sampleRate));
      }

      final bytes = _createWav(sampleRate, samples);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (_) {}
  }

  // SIRENA MILITAR: "WIU WIU WIU WIU"
  static Future<void> playSiren() async {
    if (!soundEnabled) return;
    try {
      HapticFeedback.heavyImpact();
      const sampleRate = 22050;
      final samples = <double>[];
      const durationSeconds = 1.6;
      final totalSamples = (sampleRate * durationSeconds).toInt();

      double phase = 0.0;
      for (int i = 0; i < totalSamples; i++) {
        final t = i / sampleRate;
        // Modulación senoidal entre 450Hz y 950Hz
        final freq = 700 + 250 * math.sin(2 * math.pi * 3.5 * t);
        phase += 2 * math.pi * freq / sampleRate;
        samples.add(0.8 * math.sin(phase));
      }

      final bytes = _createWav(sampleRate, samples);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (_) {}
  }
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
        scaffoldBackgroundColor: const Color(0xFF07090E),
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
  List<String> targets = ['fingor', 'edwing ek'];
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _guildController = TextEditingController();

  Map<String, dynamic> onlineTargets = {};
  Map<String, List<dynamic>> characterDeaths = {};
  Map<String, bool> loadingDeaths = {};
  
  List<String> radarLogs = [];
  bool isScanning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadTargets();
    addLog("SISTEMA RADAR TÁCTICO V2.0 EN LÍNEA.");
    scanRadar();
    _timer = Timer.periodic(const Duration(seconds: 40), (timer) => scanRadar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _targetController.dispose();
    _guildController.dispose();
    super.dispose();
  }

  Future<void> loadTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('tibia_targets');
    if (saved != null && saved.isNotEmpty) {
      setState(() => targets = saved);
    }
  }

  Future<void> saveTargets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tibia_targets', targets);
  }

  void addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      radarLogs.insert(0, "[$time] $message");
      if (radarLogs.length > 30) radarLogs.removeLast();
    });
  }

  Future<void> scanRadar() async {
    setState(() => isScanning = true);
    addLog("Escaneando satélite en Ferobra...");

    try {
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/world/$world'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List players = data['world']?['online_players'] ?? [];

        Map<String, dynamic> currentlyOnline = {};

        for (var p in players) {
          final String name = p['name'].toString().toLowerCase();
          if (targets.contains(name)) {
            currentlyOnline[name] = p;
            if (!onlineTargets.containsKey(name)) {
              addLog("⚠️ [OBJETIVO DETECTADO]: ${p['name']} (Lvl ${p['level']})");
              TacticalAudio.playBeepBeep(); // 🔊 PI-PI
            }
          }
        }

        for (var oldTarget in onlineTargets.keys) {
          if (!currentlyOnline.containsKey(oldTarget)) {
            addLog("🛑 [SIRENA / TARGET LOST]: ${oldTarget.toUpperCase()} DESCONECTÓ");
            TacticalAudio.playSiren(); // 🚨 WIU-WIU
          }
        }

        setState(() {
          onlineTargets = currentlyOnline;
        });
        addLog("Escaneo OK: ${players.length} jugadores en Ferobra.");
      }
    } catch (e) {
      addLog("ERROR: Falla de conexión con TibiaData.");
    } finally {
      setState(() => isScanning = false);
    }
  }

  // DESPLEGAR MUERTES DESDE LA API DE PERSONAJES
  Future<void> fetchDeaths(String charName) async {
    if (characterDeaths.containsKey(charName)) return;

    setState(() => loadingDeaths[charName] = true);
    try {
      final formattedName = Uri.encodeComponent(charName);
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/$formattedName'),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List deaths = data['character']?['deaths'] ?? [];
        setState(() {
          characterDeaths[charName] = deaths;
        });
      }
    } catch (_) {
      setState(() {
        characterDeaths[charName] = [];
      });
    } finally {
      setState(() => loadingDeaths[charName] = false);
    }
  }

  // IMPORTAR GUILD ENTERA
  Future<void> importGuild() async {
    final guildName = _guildController.text.trim();
    if (guildName.isEmpty) return;

    Navigator.pop(context);
    addLog("Consultando miembros de Guild '$guildName'...");

    try {
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/guild/${Uri.encodeComponent(guildName)}'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List members = data['guild']?['members'] ?? [];
        int count = 0;

        for (var m in members) {
          final String name = m['name'].toString().toLowerCase();
          if (!targets.contains(name)) {
            targets.add(name);
            count++;
          }
        }
        await saveTargets();
        setState(() {});
        addLog("GUILD CARGADA: +$count nuevos objetivos.");
        scanRadar();
      } else {
        addLog("ERROR: Guild no encontrada.");
      }
    } catch (_) {
      addLog("ERROR: Falla al consultar guild.");
    }
    _guildController.clear();
  }

  void addTarget() {
    final text = _targetController.text.trim().toLowerCase();
    if (text.isNotEmpty && !targets.contains(text)) {
      setState(() => targets.add(text));
      saveTargets();
      addLog("Añadido a lista negra: ${text.toUpperCase()}");
      _targetController.clear();
      scanRadar();
    }
  }

  void removeTarget(String name) {
    setState(() {
      targets.remove(name);
      onlineTargets.remove(name);
      characterDeaths.remove(name);
    });
    saveTargets();
    addLog("Objetivo removido: ${name.toUpperCase()}");
  }

  // CONTADOR DE VOCACIONES
  Map<String, int> get vocationCounts {
    int ek = 0, ed = 0, ms = 0, rp = 0;
    for (var info in onlineTargets.values) {
      final voc = info['vocation']?.toString().toLowerCase() ?? '';
      if (voc.contains('knight')) ek++;
      if (voc.contains('druid')) ed++;
      if (voc.contains('sorcerer')) ms++;
      if (voc.contains('paladin')) rp++;
    }
    return {'EK': ek, 'ED': ed, 'MS': ms, 'RP': rp};
  }

  @override
  Widget build(BuildContext context) {
    final vocs = vocationCounts;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E131E),
        elevation: 2,
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
            const SizedBox(width: 10),
            Text(
              "RADAR // $world",
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              TacticalAudio.soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: TacticalAudio.soundEnabled ? const Color(0xFF00E5FF) : Colors.grey,
            ),
            onPressed: () {
              setState(() => TacticalAudio.soundEnabled = !TacticalAudio.soundEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TacticalAudio.soundEnabled ? "ALERTAS AUDIBLES ACTIVADAS" : "MODO SILENCIOSO"),
                  duration: const Duration(seconds: 1),
                  backgroundColor: const Color(0xFF00E5FF),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: isScanning ? null : scanRadar,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            // BARRA TÁCTICA DE VOCACIONES ACTIVAS
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _vocBadge("EK", vocs['EK']!, Colors.amber),
                  _vocBadge("ED", vocs['ED']!, Colors.greenAccent),
                  _vocBadge("MS", vocs['MS']!, Colors.purpleAccent),
                  _vocBadge("RP", vocs['RP']!, Colors.cyanAccent),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // PANEL DE ACCIONES (BUSCAR + BOTÓN GUILD)
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101625),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _targetController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: "ENEMIGO...",
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => addTarget(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  onPressed: addTarget,
                  child: const Text("+ TARGET"),
                ),
                const SizedBox(width: 6),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF162035),
                    foregroundColor: const Color(0xFF00E5FF),
                  ),
                  icon: const Icon(Icons.shield, size: 20),
                  tooltip: "Importar Guild",
                  onPressed: () => _showGuildDialog(),
                )
              ],
            ),
            const SizedBox(height: 14),

            // LISTA DE OBJETIVOS CON DESPLIEGUE DE MUERTES
            Expanded(
              flex: 4,
              child: ListView.builder(
                itemCount: targets.length,
                itemBuilder: (context, index) {
                  final target = targets[index];
                  final isOnline = onlineTargets.containsKey(target);
                  final data = onlineTargets[target];
                  final deaths = characterDeaths[target];
                  final isLoadingThisDeath = loadingDeaths[target] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C111C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOnline ? const Color(0xFF00FFB2) : Colors.white12,
                        width: isOnline ? 1.5 : 1.0,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        onExpansionChanged: (expanded) {
                          if (expanded) fetchDeaths(target);
                        },
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
                              ? "ONLINE | Lvl ${data['level']} | ${data['vocation']}"
                              : "OFFLINE // DESCONECTADO (Toca para muertes)",
                          style: TextStyle(
                            color: isOnline ? const Color(0xFF00FFB2) : Colors.white38,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                          onPressed: () => removeTarget(target),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            color: const Color(0xFF06080D),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "💀 HISTORIAL DE MUERTES RECIENTES:",
                                  style: TextStyle(
                                    color: Color(0xFFFF5252),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (isLoadingThisDeath)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                                      ),
                                    ),
                                  )
                                else if (deaths == null || deaths.isEmpty)
                                  const Text(
                                    "Sin muertes recientes registradas.",
                                    style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                                  )
                                else
                                  ...deaths.take(4).map((d) {
                                    final time = d['time']?.toString().split('T').first ?? '';
                                    final reason = d['reason'] ?? 'Murió';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Text(
                                        "• [$time] $reason",
                                        style: const TextStyle(
                                          color: Color(0xFFFF8A80),
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // CONSOLA TÁCTICA
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CONSOLA EN VIVO",
                style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF030407),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  itemCount: radarLogs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      radarLogs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
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

  Widget _vocBadge(String voc, int count, Color color) {
    return Row(
      children: [
        Text(
          "$voc: ",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        Text(
          "$count",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  void _showGuildDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E131E),
        title: const Text("IMPORTAR GUILD ENEMIGA", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 14)),
        content: TextField(
          controller: _guildController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nombre de la guild...",
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: importGuild,
            child: const Text("IMPORTAR"),
          ),
        ],
      ),
    );
  }
}
