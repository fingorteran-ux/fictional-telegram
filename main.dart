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

  // TRES PITIDOS SEGUIDOS ("PI - PI - PI")
  static Future<void> playThreeBeeps() async {
    if (!soundEnabled) return;
    try {
      HapticFeedback.vibrate();
      const sampleRate = 22050;
      final samples = <double>[];
      for (int i = 0; i < (sampleRate * 0.07).toInt(); i++) samples.add(math.sin(2 * math.pi * 1100 * i / sampleRate));
      for (int i = 0; i < (sampleRate * 0.05).toInt(); i++) samples.add(0.0);
      for (int i = 0; i < (sampleRate * 0.07).toInt(); i++) samples.add(math.sin(2 * math.pi * 1220 * i / sampleRate));
      for (int i = 0; i < (sampleRate * 0.05).toInt(); i++) samples.add(0.0);
      for (int i = 0; i < (sampleRate * 0.09).toInt(); i++) samples.add(math.sin(2 * math.pi * 1350 * i / sampleRate));

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

class TrackTarget {
  final String name;
  final String type; // 'amigo' o 'enemigo'
  final String world; // 'Ferobra' o 'Quintera'

  TrackTarget({required this.name, required this.type, required this.world});

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'world': world};

  factory TrackTarget.fromJson(Map<String, dynamic> json) => TrackTarget(
        name: json['name'] ?? '',
        type: json['type'] ?? 'enemigo',
        world: json['world'] ?? 'Ferobra',
      );
}

// -------------------------------------------------------------
// PESTAÑA 1: WAR HUD (MUERTES CON MONSTRUOS Y PKS ANIMADOS)
// -------------------------------------------------------------
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  static const platform = MethodChannel('com.tactical.tibia/radar');
  List<TrackTarget> targets = [
    TrackTarget(name: 'fingor', type: 'amigo', world: 'Ferobra'),
    TrackTarget(name: 'edwing ek', type: 'enemigo', world: 'Ferobra'),
  ];

  final TextEditingController _nameController = TextEditingController();
  String selectedWorldInput = 'Ferobra';
  String currentFilter = 'TODOS';

  Map<String, dynamic> onlinePlayersData = {};
  Map<String, Map<String, dynamic>> characterInfoCache = {};
  Map<String, List<dynamic>> characterDeaths = {};
  Map<String, bool> loadingDeaths = {};

  Map<String, int> loginTimestamps = {};
  Map<String, int> sessionDurations = {};
  Map<String, String> logoutTimes = {};

  Map<String, bool> muteLoginMap = {};
  Map<String, bool> muteLogoutMap = {};

  List<String> radarLogs = [];
  bool isScanning = false;
  bool isBackgroundActive = true;
  Timer? _timer;
  Timer? _clockUpdater;

  bool isSelectionMode = false;
  final Set<String> selectedTargets = {};

  @override
  void initState() {
    super.initState();
    initRadar();
    _clockUpdater = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> initRadar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('spy_targets_json');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List decoded = json.decode(jsonStr);
        targets = decoded.map((e) => TrackTarget.fromJson(e)).toList();
      } catch (_) {}
    }

    for (var t in targets) {
      muteLoginMap[t.name.toLowerCase()] = prefs.getBool('mute_login_${t.name.toLowerCase()}') ?? false;
      muteLogoutMap[t.name.toLowerCase()] = prefs.getBool('mute_logout_${t.name.toLowerCase()}') ?? false;
      fetchCharacterDetails(t.name);
    }

    setState(() {});
    addLog("SPY FEROBRA & QUINTERA EN VIVO");
    syncNativeService();
    scanAllWorlds();
    _timer = Timer.periodic(const Duration(seconds: 35), (_) => scanAllWorlds());
  }

  Future<void> syncNativeService() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(targets.map((e) => e.toJson()).toList());
    await prefs.setString('spy_targets_json', jsonStr);

    try {
      if (isBackgroundActive) {
        await platform.invokeMethod('startRadarService');
      } else {
        await platform.invokeMethod('stopRadarService');
      }
    } catch (_) {}
  }

  Future<void> fetchCharacterDetails(String charName) async {
    final key = charName.toLowerCase();
    try {
      final res = await http.get(Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final ch = data['character']?['character'];
        if (ch != null) {
          setState(() {
            characterInfoCache[key] = {
              'level': ch['level'] ?? 0,
              'vocation': ch['vocation'] ?? 'None',
              'last_login': ch['last_login'] ?? '',
            };
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockUpdater?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      radarLogs.insert(0, "[$time] $message");
      if (radarLogs.length > 30) radarLogs.removeLast();
    });
  }

  List<TrackTarget> get dynamicFilteredTargets {
    var list = targets.where((t) {
      if (currentFilter == 'ENEMIGOS') return t.type == 'enemigo';
      if (currentFilter == 'AMIGOS') return t.type == 'amigo';
      return true;
    }).toList();

    list.sort((a, b) {
      final aOnline = onlinePlayersData.containsKey(a.name.toLowerCase()) ? 1 : 0;
      final bOnline = onlinePlayersData.containsKey(b.name.toLowerCase()) ? 1 : 0;
      if (aOnline != bOnline) {
        return bOnline.compareTo(aOnline);
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> scanAllWorlds() async {
    setState(() => isScanning = true);
    final worldsToScan = targets.map((t) => t.world).toSet();
    if (worldsToScan.isEmpty) worldsToScan.add('Ferobra');

    Map<String, dynamic> newOnlineMap = {};

    for (var w in worldsToScan) {
      try {
        final response = await http.get(Uri.parse('https://api.tibiadata.com/v4/world/$w')).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List players = data['world']?['online_players'] ?? [];
          final now = DateTime.now().millisecondsSinceEpoch;

          for (var p in players) {
            final name = p['name'].toString().toLowerCase();
            newOnlineMap[name] = p;

            final isMonitored = targets.any((t) => t.name.toLowerCase() == name && t.world.toLowerCase() == w.toLowerCase());
            if (isMonitored && !onlinePlayersData.containsKey(name)) {
              loginTimestamps[name] = now;
              final targetObj = targets.firstWhere((t) => t.name.toLowerCase() == name);
              if (targetObj.type == 'enemigo' && muteLoginMap[name] != true) {
                TacticalAudio.playThreeBeeps();
              }
              addLog("⚠️ [ONLINE]: ${p['name']} conectó en $w");
            }
          }
        }
      } catch (_) {}
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    for (var oldName in onlinePlayersData.keys) {
      if (!newOnlineMap.containsKey(oldName)) {
        if (loginTimestamps.containsKey(oldName)) {
          sessionDurations[oldName] = now - loginTimestamps[oldName]!;
        }
        final dt = DateTime.now();
        logoutTimes[oldName] = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        addLog("🛑 [OFFLINE]: ${oldName.toUpperCase()} salió");
      }
    }

    setState(() {
      onlinePlayersData = newOnlineMap;
      isScanning = false;
    });
  }

  Future<void> fetchDeaths(String charName) async {
    if (characterDeaths.containsKey(charName)) return;
    setState(() => loadingDeaths[charName] = true);
    try {
      final response = await http.get(Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}')).timeout(const Duration(seconds: 10));
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

  void addTarget(String type) {
    final text = _nameController.text.trim();
    if (text.isNotEmpty && !targets.any((t) => t.name.toLowerCase() == text.toLowerCase())) {
      final newT = TrackTarget(name: text, type: type, world: selectedWorldInput);
      setState(() => targets.add(newT));
      fetchCharacterDetails(text);
      syncNativeService();
      addLog("Nuevo $type en $selectedWorldInput: ${text.toUpperCase()}");
      _nameController.clear();
      scanAllWorlds();
    }
  }

  void removeTarget(String name) {
    setState(() {
      targets.removeWhere((t) => t.name.toLowerCase() == name.toLowerCase());
      selectedTargets.remove(name.toLowerCase());
    });
    syncNativeService();
    addLog("Removido: ${name.toUpperCase()}");
  }

  void deleteSelectedTargets() {
    final count = selectedTargets.length;
    if (count == 0) return;

    setState(() {
      targets.removeWhere((t) => selectedTargets.contains(t.name.toLowerCase()));
      selectedTargets.clear();
      isSelectionMode = false;
    });
    syncNativeService();
    addLog("Se eliminaron $count objetivos.");
  }

  void selectAllTargets() {
    setState(() {
      if (selectedTargets.length == targets.length) {
        selectedTargets.clear();
      } else {
        selectedTargets.addAll(targets.map((t) => t.name.toLowerCase()));
      }
    });
  }

  void clearAllTargets() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14080D),
        title: const Text("¿PURGAR LISTA COMPLETA?", style: TextStyle(color: Color(0xFFFF0055), fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        content: const Text("Se borrarán todos los personajes (Amigos y Enemigos).", style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
        actions: [
          TextButton(child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                targets.clear();
                selectedTargets.clear();
                isSelectionMode = false;
              });
              syncNativeService();
              addLog("LISTA PURGADA POR COMPLETO.");
            },
            child: const Text("PURGAR TODO"),
          ),
        ],
      ),
    );
  }

  void _showIndividualAlertConfig(TrackTarget target) {
    final key = target.name.toLowerCase();
    bool muteLogin = muteLoginMap[key] ?? false;
    bool muteLogout = muteLogoutMap[key] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D121E),
          title: Text(
            "${target.type.toUpperCase()}: ${target.name.toUpperCase()} (${target.world})",
            style: TextStyle(color: target.type == 'amigo' ? const Color(0xFF00FFB2) : const Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Avisar al Conectar", style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                subtitle: Text("Voz anunciando que conectó en ${target.world}", style: const TextStyle(fontSize: 10, color: Colors.white38)),
                value: !muteLogin,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => muteLogin = !val),
              ),
              const Divider(color: Colors.white12),
              SwitchListTile(
                title: const Text("Avisar al Desconectar", style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                subtitle: Text(target.type == 'enemigo' ? "Voz y sirena de 1s" : "Voz avisando desconexión", style: const TextStyle(fontSize: 10, color: Colors.white38)),
                value: !muteLogout,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => muteLogout = !val),
              ),
            ],
          ),
          actions: [
            TextButton(child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('mute_login_$key', muteLogin);
                await prefs.setBool('mute_logout_$key', muteLogout);
                setState(() {
                  muteLoginMap[key] = muteLogin;
                  muteLogoutMap[key] = muteLogout;
                });
                Navigator.pop(ctx);
                addLog("Configuración guardada para ${target.name.toUpperCase()}");
              },
              child: const Text("GUARDAR"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getVocationAvatar(String? vocation, bool isOnline, String type) {
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

    final borderColor = isOnline ? (type == 'amigo' ? const Color(0xFF00FFB2) : const Color(0xFF00E5FF)) : Colors.white12;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: isOnline ? 1.5 : 1.0),
      ),
      child: Center(
        child: Text(
          iconText,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: isOnline ? vocColor : Colors.white30),
        ),
      ),
    );
  }

  // WIDGET PARA DIBUJAR AL MONSTRUO O AL PLAYER KILLER (ANIMADO)
  Widget _buildKillerSprite(dynamic death) {
    final killers = death['killers'] as List? ?? [];
    if (killers.isEmpty) {
      return const Text("💀", style: TextStyle(fontSize: 20));
    }

    final firstKiller = killers.first;
    final killerName = firstKiller['name']?.toString() ?? 'Monstruo';
    final isPlayer = firstKiller['player'] == true;

    if (isPlayer) {
      // SI FUE ASESINADO POR UN JUGADOR (PvP / PK en Guerra)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2E0909),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.redAccent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("⚔️ 💀", style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              "PK: ${killerName.toUpperCase()}",
              style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 10),
            ),
          ],
        ),
      );
    } else {
      // SI FUE ASESINADO POR UN MONSTRUO (Muestra la miniatura animada del monstruo)
      final cleanName = killerName.replaceAll(RegExp(r'^(a |an )', caseSensitive: false), '').trim();
      final formattedUrl = "https://tibia.fandom.com/wiki/Special:FilePath/${Uri.encodeComponent(cleanName)}.gif";

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF101625),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              formattedUrl,
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) => const Text("👾", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 6),
            Text(
              cleanName.toUpperCase(),
              style: const TextStyle(color: Color(0xFF80DEEA), fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
  }

  String formatDuration(int millis) {
    final mins = (millis / 60000).floor();
    if (mins < 60) return "$mins min";
    final hrs = (mins / 60).floor();
    final remMins = mins % 60;
    return "${hrs}h ${remMins}m";
  }

  @override
  Widget build(BuildContext context) {
    final displayList = dynamicFilteredTargets;

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
            const SizedBox(width: 8),
            const Text(
              "SPY // FEROBRA & QUINTERA",
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF), letterSpacing: 1.0),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(TacticalAudio.soundEnabled ? Icons.volume_up : Icons.volume_off, color: TacticalAudio.soundEnabled ? const Color(0xFF00E5FF) : Colors.grey),
            onPressed: () => setState(() => TacticalAudio.soundEnabled = !TacticalAudio.soundEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: isScanning ? null : scanAllWorlds,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF0E1424), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                          decoration: const InputDecoration(hintText: "Nombre del personaje...", hintStyle: TextStyle(color: Colors.white30, fontSize: 12), border: InputBorder.none),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: const Color(0xFF162035), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButton<String>(
                          value: selectedWorldInput,
                          dropdownColor: const Color(0xFF0E1424),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                          items: ['Ferobra', 'Quintera'].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedWorldInput = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFB2),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ).buildWidget(
                          onPressed: () => addTarget('amigo'),
                          child: const Text("🛡️ + AMIGO", style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ).buildWidget(
                          onPressed: () => addTarget('enemigo'),
                          child: const Text("⚔️ + ENEMIGO", style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _filterBtn('TODOS'),
                const SizedBox(width: 6),
                _filterBtn('ENEMIGOS'),
                const SizedBox(width: 6),
                _filterBtn('AMIGOS'),
                const Spacer(),
                IconButton(
                  icon: Icon(isSelectionMode ? Icons.close : Icons.checklist, size: 20, color: const Color(0xFF00E5FF)),
                  onPressed: () {
                    setState(() {
                      isSelectionMode = !isSelectionMode;
                      selectedTargets.clear();
                    });
                  },
                ),
              ],
            ),

            if (isSelectionMode)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: selectAllTargets,
                      child: Text(selectedTargets.length == targets.length ? "DESMARCAR" : "TODOS (${targets.length})", style: const TextStyle(color: Colors.amber, fontFamily: 'monospace', fontSize: 11)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      onPressed: selectedTargets.isEmpty ? null : deleteSelectedTargets,
                      child: Text("BORRAR (${selectedTargets.length})", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            Expanded(
              flex: 4,
              child: ListView.builder(
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final target = displayList[index];
                  final key = target.name.toLowerCase();
                  final isOnline = onlinePlayersData.containsKey(key);
                  final onlineData = onlinePlayersData[key];
                  final cachedInfo = characterInfoCache[key] ?? {};
                  final deaths = characterDeaths[target.name] ?? [];
                  final isChecked = selectedTargets.contains(key);

                  final level = isOnline ? (onlineData['level'] ?? 0) : (cachedInfo['level'] ?? 0);
                  final vocation = isOnline ? (onlineData['vocation'] ?? '') : (cachedInfo['vocation'] ?? 'Consultando...');

                  String timerText = "";
                  if (isOnline) {
                    if (loginTimestamps.containsKey(key)) {
                      final diff = DateTime.now().millisecondsSinceEpoch - loginTimestamps[key]!;
                      timerText = "⏱️ En línea: ${formatDuration(diff)}";
                    } else {
                      timerText = "⏱️ En línea";
                    }
                  } else {
                    if (sessionDurations.containsKey(key)) {
                      final dur = formatDuration(sessionDurations[key]!);
                      final outAt = logoutTimes[key] ?? "";
                      timerText = "🕒 Salió hace poco (Duró $dur)";
                    } else {
                      timerText = "⚫ Desconectado";
                    }
                  }

                  final cardBorderColor = isOnline
                      ? (target.type == 'amigo' ? const Color(0xFF00FFB2) : const Color(0xFF00E5FF))
                      : Colors.white12;

                  return InkWell(
                    onLongPress: () => _showIndividualAlertConfig(target),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C111C),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cardBorderColor, width: isOnline ? 1.6 : 1.0),
                        boxShadow: isOnline ? [BoxShadow(color: cardBorderColor.withOpacity(0.18), blurRadius: 6, spreadRadius: 1)] : [],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          onExpansionChanged: (expanded) {
                            if (expanded) fetchDeaths(target.name);
                          },
                          leading: isSelectionMode
                              ? Checkbox(
                                  activeColor: const Color(0xFF00E5FF),
                                  checkColor: Colors.black,
                                  value: isChecked,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        selectedTargets.add(key);
                                      } else {
                                        selectedTargets.remove(key);
                                      }
                                    });
                                  },
                                )
                              : _getVocationAvatar(vocation, isOnline, target.type),
                          title: Row(
                            children: [
                              Text(
                                target.name.toUpperCase(),
                                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: isOnline ? Colors.white : Colors.white60),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: target.world == 'Ferobra' ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  target.world.toUpperCase(),
                                  style: TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: target.world == 'Ferobra' ? const Color(0xFF00E5FF) : Colors.amber),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOnline ? const Color(0xFF00FFB2).withOpacity(0.2) : Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOnline ? "ONLINE" : "OFFLINE",
                                  style: TextStyle(color: isOnline ? const Color(0xFF00FFB2) : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              )
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                "Lvl $level | $vocation",
                                style: TextStyle(color: isOnline ? Colors.white70 : Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timerText,
                                style: TextStyle(color: isOnline ? Colors.amberAccent : Colors.white30, fontSize: 9, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          trailing: isSelectionMode
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                  onPressed: () => removeTarget(target.name),
                                ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              color: const Color(0xFF06080D),
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("💀 HISTORIAL DE MUERTES CON MINIATURAS:", style: TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                  const SizedBox(height: 8),
                                  if (loadingDeaths[target.name] ?? false)
                                    const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))))
                                  else if (deaths.isEmpty)
                                    const Text("Sin muertes recientes registradas en Tibia.", style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'))
                                  else
                                    ...deaths.take(5).map((d) {
                                      final time = d['time']?.toString().split('T').first ?? '';
                                      final lvl = d['level'] ?? 0;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: const Color(0xFF0B101A), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
                                        child: Row(
                                          children: [
                                            _buildKillerSprite(d), // MINIATURA DEL MONSTRUO O PK
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Lvl $lvl en $time", style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                                  Text(d['reason'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace'), maxLines: 2),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            )
                          ],
                        ),
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

  Widget _filterBtn(String label) {
    final isSelected = currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => currentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF101625),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white60),
        ),
      ),
    );
  }
}

extension ElevatedButtonExtension on ButtonStyle {
  Widget buildWidget({required VoidCallback onPressed, required Widget child}) {
    return ElevatedButton(style: this, onPressed: onPressed, child: child);
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
      case DateTime.monday: return {'city': 'SVARGROND', 'spot': 'Taberna de Dankwart (al sur del barco)', 'next': 'LIBERTY BAY'};
      case DateTime.tuesday: return {'city': 'LIBERTY BAY', 'spot': 'Taberna de Lyonel (1er piso)', 'next': 'PORT HOPE'};
      case DateTime.wednesday: return {'city': 'PORT HOPE', 'spot': 'Barco de Clyde (segundo piso)', 'next': 'ANKRAHMUN'};
      case DateTime.thursday: return {'city': 'ANKRAHMUN', 'spot': 'Taberna de Arito (sobre el depósito)', 'next': 'DARASHIA'};
      case DateTime.friday: return {'city': 'DARASHIA', 'spot': 'Taberna de Miraia (al sur del banco)', 'next': 'EDRON'};
      case DateTime.saturday: return {'city': 'EDRON', 'spot': 'Taberna de Mirabell (arriba del depósito)', 'next': 'CARLIN'};
      case DateTime.sunday: return {'city': 'CARLIN', 'spot': 'Depósito central (segundo piso)', 'next': 'SVARGROND'};
      default: return {'city': 'DARASHIA', 'spot': 'Taberna de Miraia', 'next': 'EDRON'};
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
            decoration: BoxDecoration(color: const Color(0xFF0B101D), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00E5FF))),
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

          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1.5),
              color: const Color(0xFF1B231A),
            ),
            child: Stack(
              children: [
                CustomPaint(size: const Size(double.infinity, 220), painter: TibiaMinimapPainter()),
                Positioned(
                  top: 75,
                  left: 140,
                  child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5))),
                ),
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
                          const Text("🚶", style: TextStyle(fontSize: 26)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFF0E1424), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)),
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

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0E1424), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("YASIR (BARCO ORIENTAL)", style: TextStyle(color: Color(0xFF00FFB2), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 6),
                Text("Puertos posibles tras el Server Save:\n• Carlin (Muelle sur)\n• Liberty Bay (Muelle este)\n• Ankrahmun (Muelle oeste)", style: TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TibiaMinimapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF141A12);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()..color = const Color(0xFF382D1C);
    canvas.drawRect(Rect.fromLTWH(40, 90, size.width - 80, 50), roadPaint);
    canvas.drawRect(Rect.fromLTWH(130, 40, 80, 140), roadPaint);

    final wallPaint = Paint()..color = const Color(0xFF5A5852)..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(110, 60, 120, 80), wallPaint);

    final roofPaint = Paint()..color = const Color(0xFF6B261D).withOpacity(0.5);
    canvas.drawRect(Rect.fromLTWH(113, 63, 114, 74), roofPaint);

    final gridPaint = Paint()..color = Colors.black26..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint); }
    for (double i = 0; i < size.height; i += 20) { canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint); }
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
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 8, spreadRadius: 1)],
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
                Text("⏳ Inicia en: $countdown", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
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
