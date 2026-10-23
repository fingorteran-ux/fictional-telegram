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
  runApp(const SpyFerobraApp());
}

class TacticalAudio {
  static final AudioPlayer _player = AudioPlayer();
  static bool soundEnabled = true;

  static Uint8List _createWav(int sampleRate, List<double> samples) {
    final byteData = ByteData(44 + samples.length * 2);
    byteData.setUint32(0, 0x52494646, Endian.big);
    byteData.setUint32(4, 36 + samples.length * 2, Endian.little);
    byteData.setUint32(8, 0x57415645, Endian.big);
    byteData.setUint32(12, 0x666d7420, Endian.big);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint32(36, 0x64617461, Endian.big);
    byteData.setUint32(40, samples.length * 2, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      byteData.setInt16(44 + i * 2, sample, Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  static Future<void> playBeepBeep() async {
    if (!soundEnabled) return;
    try {
      HapticFeedback.vibrate();
      const sampleRate = 22050;
      final samples = <double>[];
      for (int i = 0; i < (sampleRate * 0.09).toInt(); i++) {
        samples.add(math.sin(2 * math.pi * 1050 * i / sampleRate));
      }
      for (int i = 0; i < (sampleRate * 0.06).toInt(); i++) {
        samples.add(0.0);
      }
      for (int i = 0; i < (sampleRate * 0.11).toInt(); i++) {
        samples.add(math.sin(2 * math.pi * 1250 * i / sampleRate));
      }
      final bytes = _createWav(sampleRate, samples);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (_) {}
  }
}

class SpyFerobraApp extends StatelessWidget {
  const SpyFerobraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spy Ferobra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07090E),
        primaryColor: const Color(0xFF00E5FF),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    RadarScreen(),
    WorldScreen(),
    EventsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF0B0F1A),
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'WAR HUD'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'MUNDO & RASHID'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'EVENTOS'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// PESTAÑA 1: WAR HUD (ONLINE PRIMERO, SPRITES & TIMERS)
// -------------------------------------------------------------
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  static const platform = MethodChannel('com.tactical.tibia/radar');
  final String world = 'Ferobra';
  List<String> targets = ['fingor', 'edwing ek'];
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _guildController = TextEditingController();

  Map<String, dynamic> onlineTargets = {};
  Map<String, List<dynamic>> characterDeaths = {};
  Map<String, bool> loadingDeaths = {};
  
  // Tiempos de conexión y sesiones
  Map<String, int> loginTimestamps = {};
  Map<String, int> sessionDurations = {};
  Map<String, String> logoutTimes = {};

  List<String> radarLogs = [];
  bool isScanning = false;
  bool isBackgroundActive = true;
  Timer? _timer;
  Timer? _clockUpdater;

  // Selección masiva
  bool isSelectionMode = false;
  final Set<String> selectedTargets = {};

  @override
  void initState() {
    super.initState();
    initRadar();
    // Actualiza los cronómetros de "En línea hace X min" cada 30 segundos
    _clockUpdater = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> initRadar() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('tibia_targets');
    if (saved != null && saved.isNotEmpty) {
      targets = saved;
    }
    setState(() {});
    addLog("SPY FEROBRA INICIADO // RADAR TÁCTICO LISTO");
    syncNativeService();
    scanRadar();
    _timer = Timer.periodic(const Duration(seconds: 35), (timer) => scanRadar());
  }

  Future<void> syncNativeService() async {
    try {
      if (isBackgroundActive) {
        await platform.invokeMethod('startRadarService', {'targets': targets});
      } else {
        await platform.invokeMethod('stopRadarService');
      }
    } catch (_) {}
  }

  Future<void> updateTargetsNative() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tibia_targets', targets);
    try {
      await platform.invokeMethod('updateTargets', {'targets': targets});
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockUpdater?.cancel();
    _targetController.dispose();
    _guildController.dispose();
    super.dispose();
  }

  void addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      radarLogs.insert(0, "[$time] $message");
      if (radarLogs.length > 30) radarLogs.removeLast();
    });
  }

  // ORDEN DINÁMICO: CONECTADOS ARRIBA, DESCONECTADOS ABAJO AL INSTANTE
  List<String> get dynamicSortedTargets {
    final online = targets.where((t) => onlineTargets.containsKey(t)).toList();
    final offline = targets.where((t) => !onlineTargets.containsKey(t)).toList();
    online.sort((a, b) => a.compareTo(b));
    offline.sort((a, b) => a.compareTo(b));
    return [...online, ...offline];
  }

  Future<void> scanRadar() async {
    setState(() => isScanning = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/world/$world'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List players = data['world']?['online_players'] ?? [];

        Map<String, dynamic> currentlyOnline = {};
        final now = DateTime.now().millisecondsSinceEpoch;

        for (var p in players) {
          final String name = p['name'].toString().toLowerCase();
          if (targets.contains(name)) {
            currentlyOnline[name] = p;
            if (!onlineTargets.containsKey(name)) {
              addLog("⚠️ [ONLINE]: ${p['name']} (Lvl ${p['level']})");
              loginTimestamps[name] = now;
              TacticalAudio.playBeepBeep();
            }
          }
        }

        for (var oldTarget in onlineTargets.keys) {
          if (!currentlyOnline.containsKey(oldTarget)) {
            addLog("🛑 [OFFLINE]: ${oldTarget.toUpperCase()} DESCONECTÓ");
            if (loginTimestamps.containsKey(oldTarget)) {
              sessionDurations[oldTarget] = now - loginTimestamps[oldTarget]!;
            }
            final dt = DateTime.now();
            logoutTimes[oldTarget] = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
          }
        }

        setState(() {
          onlineTargets = currentlyOnline;
        });
        addLog("Escaneo: ${players.length} conectados en Ferobra.");
      }
    } catch (_) {
      addLog("Reintentando satélite...");
    } finally {
      setState(() => isScanning = false);
    }
  }

  Future<void> fetchDeaths(String charName) async {
    if (characterDeaths.containsKey(charName)) return;
    setState(() => loadingDeaths[charName] = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}'),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List deaths = data['character']?['deaths'] ?? [];
        setState(() => characterDeaths[charName] = deaths);
      }
    } catch (_) {
      setState(() => characterDeaths[charName] = []);
    } finally {
      setState(() => loadingDeaths[charName] = false);
    }
  }

  Future<void> importGuild() async {
    final guildName = _guildController.text.trim();
    if (guildName.isEmpty) return;
    Navigator.pop(context);
    addLog("Importando guild '$guildName'...");

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
        await updateTargetsNative();
        setState(() {});
        addLog("GUILD CARGADA: +$count objetivos.");
        scanRadar();
      }
    } catch (_) {
      addLog("ERROR importando guild.");
    }
    _guildController.clear();
  }

  void addTarget() {
    final text = _targetController.text.trim().toLowerCase();
    if (text.isNotEmpty && !targets.contains(text)) {
      setState(() => targets.add(text));
      updateTargetsNative();
      addLog("Añadido: ${text.toUpperCase()}");
      _targetController.clear();
      scanRadar();
    }
  }

  void removeTarget(String name) {
    setState(() {
      targets.remove(name);
      onlineTargets.remove(name);
      characterDeaths.remove(name);
      selectedTargets.remove(name);
    });
    updateTargetsNative();
    addLog("Removido: ${name.toUpperCase()}");
  }

  void deleteSelectedTargets() {
    final count = selectedTargets.length;
    if (count == 0) return;

    setState(() {
      targets.removeWhere((t) => selectedTargets.contains(t));
      for (var t in selectedTargets) {
        onlineTargets.remove(t);
        characterDeaths.remove(t);
      }
      selectedTargets.clear();
      isSelectionMode = false;
    });
    updateTargetsNative();
    addLog("Se eliminaron $count objetivos seleccionados.");
  }

  void selectAllTargets() {
    setState(() {
      if (selectedTargets.length == targets.length) {
        selectedTargets.clear();
      } else {
        selectedTargets.addAll(targets);
      }
    });
  }

  void clearAllTargets() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14080D),
        title: const Text("¿PURGAR LISTA COMPLETA?", style: TextStyle(color: Color(0xFFFF0055), fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        content: const Text("Se eliminarán todos los enemigos de Spy Ferobra.", style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
        actions: [
          TextButton(child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                targets.clear();
                onlineTargets.clear();
                characterDeaths.clear();
                selectedTargets.clear();
                isSelectionMode = false;
              });
              updateTargetsNative();
              addLog("LISTA PURGADA POR COMPLETO.");
            },
            child: const Text("PURGAR TODO"),
          ),
        ],
      ),
    );
  }

  // SPRITE DE VOCACIÓN ANIMADO EN MINIATURA
  Widget _getVocationAvatar(String? vocation, bool isOnline) {
    final voc = (vocation ?? '').toLowerCase();
    String iconText = "⚔️";
    Color vocColor = Colors.grey;

    if (voc.contains('knight')) {
      iconText = "🛡️ EK";
      vocColor = Colors.amber;
    } else if (voc.contains('druid')) {
      iconText = "🌿 ED";
      vocColor = Colors.greenAccent;
    } else if (voc.contains('sorcerer')) {
      iconText = "⚡ MS";
      vocColor = Colors.purpleAccent;
    } else if (voc.contains('paladin')) {
      iconText = "🏹 RP";
      vocColor = Colors.cyanAccent;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOnline ? const Color(0xFF00FFB2) : Colors.white12,
          width: isOnline ? 1.5 : 1.0,
        ),
      ),
      child: Center(
        child: Text(
          iconText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: isOnline ? vocColor : Colors.white30,
          ),
        ),
      ),
    );
  }

  String formatDuration(int millis) {
    final mins = (millis / 60000).floor();
    if (mins < 60) return "$mins min";
    final hrs = (mins / 60).floor();
    final remMins = mins % 60;
    return "${hrs}h ${remMins}m";
  }

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
    final displayList = dynamicSortedTargets;

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
                  BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.8), blurRadius: 8, spreadRadius: 2)
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "SPY FEROBRA // RADAR",
              style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF), letterSpacing: 1.5),
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: isScanning ? null : scanRadar,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0A101C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isBackgroundActive ? const Color(0xFF00FFB2) : Colors.redAccent, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(isBackgroundActive ? Icons.security : Icons.security_update_warning, color: isBackgroundActive ? const Color(0xFF00FFB2) : Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBackgroundActive ? "SPY 24/7 EN SEGUNDO PLANO: ACTIVO" : "SEGUNDO PLANO: DESACTIVADO",
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: isBackgroundActive ? const Color(0xFF00FFB2) : Colors.redAccent),
                    ),
                  ),
                  Switch(
                    value: isBackgroundActive,
                    activeColor: const Color(0xFF00FFB2),
                    onChanged: (val) {
                      setState(() => isBackgroundActive = val);
                      syncNativeService();
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(color: const Color(0xFF080C14), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3))),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFF101625), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _targetController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: const InputDecoration(hintText: "ENEMIGO...", hintStyle: TextStyle(color: Colors.white30, fontSize: 13), border: InputBorder.none),
                      onSubmitted: (_) => addTarget(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  onPressed: addTarget,
                  child: const Text("+ TARGET"),
                ),
                const SizedBox(width: 6),
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF162035), foregroundColor: const Color(0xFF00E5FF)),
                  icon: const Icon(Icons.shield, size: 20),
                  onPressed: () => _showGuildDialog(),
                )
              ],
            ),
            const SizedBox(height: 8),

            // BARRA TÁCTICA DE ACCIONES MASIVAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: Icon(isSelectionMode ? Icons.close : Icons.checklist, size: 16, color: const Color(0xFF00E5FF)),
                  label: Text(
                    isSelectionMode ? "CANCELAR" : "MODO SELECCIÓN",
                    style: const TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    setState(() {
                      isSelectionMode = !isSelectionMode;
                      selectedTargets.clear();
                    });
                  },
                ),
                if (isSelectionMode) ...[
                  TextButton(
                    onPressed: selectAllTargets,
                    child: Text(
                      selectedTargets.length == targets.length ? "DESMARCAR" : "TODOS (${targets.length})",
                      style: const TextStyle(color: Colors.amber, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0055),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: selectedTargets.isEmpty ? null : deleteSelectedTargets,
                    child: Text(
                      "BORRAR (${selectedTargets.length})",
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ] else ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.redAccent),
                    label: const Text(
                      "PURGAR LISTA",
                      style: TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 11),
                    ),
                    onPressed: targets.isEmpty ? null : clearAllTargets,
                  ),
                ],
              ],
            ),

            // LISTA ORDENADA DINÁMICAMENTE (CONECTADOS ARRIBA)
            Expanded(
              flex: 4,
              child: ListView.builder(
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final target = displayList[index];
                  final isOnline = onlineTargets.containsKey(target);
                  final data = onlineTargets[target];
                  final deaths = characterDeaths[target];
                  final isLoadingThisDeath = loadingDeaths[target] ?? false;
                  final isChecked = selectedTargets.contains(target);

                  // Cálculo de cronómetro
                  String timerText = "";
                  if (isOnline) {
                    if (loginTimestamps.containsKey(target)) {
                      final diff = DateTime.now().millisecondsSinceEpoch - loginTimestamps[target]!;
                      timerText = "⏱️ En línea hace: ${formatDuration(diff)}";
                    } else {
                      timerText = "⏱️ En línea";
                    }
                  } else {
                    if (sessionDurations.containsKey(target)) {
                      final dur = formatDuration(sessionDurations[target]!);
                      final outAt = logoutTimes[target] ?? "";
                      timerText = "⏳ Duró: $dur ${outAt.isNotEmpty ? '(Salió $outAt)' : ''}";
                    } else {
                      timerText = "OFFLINE // Desconectado";
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C111C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOnline ? const Color(0xFF00FFB2) : Colors.white12,
                        width: isOnline ? 1.6 : 1.0,
                      ),
                      boxShadow: isOnline
                          ? [
                              BoxShadow(color: const Color(0xFF00FFB2).withOpacity(0.18), blurRadius: 8, spreadRadius: 1)
                            ]
                          : [],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        onExpansionChanged: (expanded) {
                          if (expanded) fetchDeaths(target);
                        },
                        leading: isSelectionMode
                            ? Checkbox(
                                activeColor: const Color(0xFF00E5FF),
                                checkColor: Colors.black,
                                value: isChecked,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedTargets.add(target);
                                    } else {
                                      selectedTargets.remove(target);
                                    }
                                  });
                                },
                              )
                            : _getVocationAvatar(data?['vocation'], isOnline),
                        title: Row(
                          children: [
                            Text(
                              target.toUpperCase(),
                              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: isOnline ? Colors.white : Colors.white60),
                            ),
                            if (isOnline) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF00FFB2).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: const Text("ONLINE", style: TextStyle(color: Color(0xFF00FFB2), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ),
                            ]
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? "Lvl ${data['level']} | ${data['vocation']}" : "Toca para ver muertes",
                              style: TextStyle(color: isOnline ? const Color(0xFF00FFB2) : Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timerText,
                              style: TextStyle(color: isOnline ? Colors.amberAccent : Colors.white30, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        trailing: isSelectionMode
                            ? null
                            : IconButton(
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
                                const Text("💀 HISTORIAL DE MUERTES RECIENTES:", style: TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                const SizedBox(height: 6),
                                if (isLoadingThisDeath)
                                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))))
                                else if (deaths == null || deaths.isEmpty)
                                  const Text("Sin muertes recientes registradas.", style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'))
                                else
                                  ...deaths.take(4).map((d) {
                                    final time = d['time']?.toString().split('T').first ?? '';
                                    final reason = d['reason'] ?? 'Murió';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Text("• [$time] $reason", style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11, fontFamily: 'monospace')),
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
            const Align(alignment: Alignment.centerLeft, child: Text("CONSOLA MILITAR", style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 11))),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF030407), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)),
                child: ListView.builder(
                  itemCount: radarLogs.length,
                  itemBuilder: (context, index) {
                    return Text(radarLogs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF80DEEA)));
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
        Text("$voc: ", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        Text("$count", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
          decoration: const InputDecoration(hintText: "Nombre de la guild...", hintStyle: TextStyle(color: Colors.white30)),
        ),
        actions: [
          TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
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

// -------------------------------------------------------------
// PESTAÑA 2: MUNDO (MINIMAPA DE TIBIA & RASHID CAMINANDO)
// -------------------------------------------------------------
class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> with SingleTickerProviderStateMixin {
  Timer? _clockTimer;
  Duration timeToSS = Duration.zero;
  late AnimationController _walkController;

  @override
  void initState() {
    super.initState();
    calculateTimeToSS();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => calculateTimeToSS());
    _walkController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _walkController.dispose();
    super.dispose();
  }

  void calculateTimeToSS() {
    final nowUtc = DateTime.now().toUtc();
    var nextSS = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 8, 0, 0);
    if (nowUtc.isAfter(nextSS)) {
      nextSS = nextSS.add(const Duration(days: 1));
    }
    setState(() {
      timeToSS = nextSS.difference(nowUtc);
    });
  }

  Map<String, String> getRashidData() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday:
        return {'city': 'SVARGROND', 'spot': 'Taberna de Dankwart (al sur del barco)', 'next': 'LIBERTY BAY'};
      case DateTime.tuesday:
        return {'city': 'LIBERTY BAY', 'spot': 'Taberna de Lyonel (1er piso)', 'next': 'PORT HOPE'};
      case DateTime.wednesday:
        return {'city': 'PORT HOPE', 'spot': 'Barco de Clyde (segundo piso)', 'next': 'ANKRAHMUN'};
      case DateTime.thursday:
        return {'city': 'ANKRAHMUN', 'spot': 'Taberna de Arito (sobre el depósito)', 'next': 'DARASHIA'};
      case DateTime.friday:
        return {'city': 'DARASHIA', 'spot': 'Taberna de Miraia (al sur del banco)', 'next': 'EDRON'};
      case DateTime.saturday:
        return {'city': 'EDRON', 'spot': 'Taberna de Mirabell (arriba del depósito)', 'next': 'CARLIN'};
      case DateTime.sunday:
        return {'city': 'CARLIN', 'spot': 'Depósito central (segundo piso)', 'next': 'SVARGROND'};
      default:
        return {'city': 'DARASHIA', 'spot': 'Taberna de Miraia', 'next': 'EDRON'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = timeToSS.inHours.toString().padLeft(2, '0');
    final minutes = (timeToSS.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (timeToSS.inSeconds % 60).toString().padLeft(2, '0');
    final rData = getRashidData();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E131E),
        title: const Text("MUNDO & RASHID", style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5FF), fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B101D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Column(
              children: [
                const Text("⏳ CUENTA REGRESIVA SERVER SAVE (SS)", style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("$hours : $minutes : $seconds", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 2)),
                const SizedBox(height: 4),
                const Text("Se reinicia diariamente a las 10:00 AM CET", style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // MINIMAPA REAL DEL JUEGO CON RASHID CAMINANDO
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1.5),
              color: const Color(0xFF1B231A), // Tono base mapa Tibia
            ),
            child: Stack(
              children: [
                // Textura simulada de Minimapa Oficial de Tibia (cuadrícula, paredes y calles)
                CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: TibiaMinimapPainter(),
                ),
                // Retícula de mira sobre la taberna
                Positioned(
                  top: 75,
                  left: 140,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
                    ),
                  ),
                ),
                // RASHID ANIMADO CAMINANDO SOBRE EL MAPA
                AnimatedBuilder(
                  animation: _walkController,
                  builder: (context, child) {
                    return Positioned(
                      top: 85,
                      left: 130 + (_walkController.value * 40),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)),
                            child: const Text("Rashid", style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 2),
                          const Text("🚶", style: TextStyle(fontSize: 26)), // Muñeco de Rashid
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // NOMBRE DE LA CIUDAD EN LETRAS PEQUEÑAS ABAJO DEL MAPA
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1424),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("📍 UBICACIÓN HOY: ${rData['city']}", style: const TextStyle(color: Colors.amber, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text("Local: ${rData['spot']}", style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11)),
                const Divider(color: Colors.white12, height: 12),
                Text("⏭️ TRAS EL SS VA A: ${rData['next']}", style: const TextStyle(color: Colors.amberAccent, fontFamily: 'monospace', fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ESTADO DE YASIR
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1424),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.directions_boat, color: Color(0xFF00FFB2), size: 18),
                    SizedBox(width: 8),
                    Text("YASIR (BARCO ORIENTAL)", style: TextStyle(color: Color(0xFF00FFB2), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text("Eventos posibles de atraco tras el Server Save:\n• Carlin (Muelle sur)\n• Liberty Bay (Muelle este)\n• Ankrahmun (Muelle oeste)", style: TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// PINTOR DEL MINIMAPA ESTILO TIBIA (Cuadrículas, calles marrones y paredes de piedra)
class TibiaMinimapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF141A12);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()..color = const Color(0xFF382D1C); // Calle de tierra/piedra
    canvas.drawRect(Rect.fromLTWH(40, 90, size.width - 80, 50), roadPaint);
    canvas.drawRect(Rect.fromLTWH(130, 40, 80, 140), roadPaint);

    final wallPaint = Paint()..color = const Color(0xFF5A5852)..strokeWidth = 3..style = PaintingStyle.stroke;
    // Edificio de la taberna
    canvas.drawRect(Rect.fromLTWH(110, 60, 120, 80), wallPaint);

    final roofPaint = Paint()..color = const Color(0xFF6B261D).withOpacity(0.5); // Techo rojizo clásico
    canvas.drawRect(Rect.fromLTWH(113, 63, 114, 74), roofPaint);

    // Grid de coordenadas de mapa
    final gridPaint = Paint()..color = Colors.black26..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// PESTAÑA 3: EVENTOS (CRONÓMETROS DIGITALES EN VIVO)
// -------------------------------------------------------------
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Calcula la cuenta regresiva exacta en Días, Horas, Minutos y Segundos
  String getTimeRemaining(int targetDays, int targetHours) {
    final now = DateTime.now();
    var targetDate = DateTime(now.year, now.month, now.day + targetDays, targetHours, 0, 0);
    final diff = targetDate.difference(now);

    final days = diff.inDays;
    final hrs = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    final secs = diff.inSeconds % 60;

    return "${days}d ${hrs.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E131E),
        title: const Text("CRONÓMETROS DE EVENTOS", style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5FF), fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _liveEventCard(
            title: "⚔️ DOBLE EXP & SKILL",
            countdown: getTimeRemaining(12, 10),
            desc: "Doble experiencia en cacería y doble velocidad en training.",
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(height: 14),
          _liveEventCard(
            title: "🔨 EVENTO DE FORJA / TIERS",
            countdown: getTimeRemaining(20, 10),
            desc: "Bonus de Fusión: mayor tasa de éxito y menor gasto de Dust.",
            color: Colors.amber,
          ),
          const SizedBox(height: 14),
          _liveEventCard(
            title: "⚡ RAPID RESPAWN & LOOT",
            countdown: getTimeRemaining(6, 10),
            desc: "Reaparición acelerada de monstruos para completar el Bestiary.",
            color: const Color(0xFF00FFB2),
          ),
          const SizedBox(height: 14),
          _liveEventCard(
            title: "🧙 BEWITCHED OFICIAL",
            countdown: getTimeRemaining(28, 10),
            desc: "Evento mundial del caldero y bonificación global de experiencia.",
            color: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _liveEventCard({required String title, required String countdown, required String desc, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D121F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.7), width: 1.3),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 8, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF060910), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  "⏳ Inicia en: $countdown",
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Colors.white60, fontFamily: 'monospace', fontSize: 11)),
        ],
      ),
    );
  }
}
