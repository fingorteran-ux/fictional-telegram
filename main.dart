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
  final String type;
  final String world;

  TrackTarget({required this.name, required this.type, required this.world});

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'world': world};

  factory TrackTarget.fromJson(Map<String, dynamic> json) => TrackTarget(
        name: json['name'] ?? '',
        type: json['type'] ?? 'enemigo',
        world: json['world'] ?? 'Ferobra',
      );
}

// -------------------------------------------------------------
// PESTAÑA 1: WAR HUD (MAGO CON FERUMBRAS HAT & SPRITES OFICIALES)
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
    addLog("SPY FEROBRA & QUINTERA ACTIVO // VIGILANCIA 24/7");
    syncNativeService();
    scanAllWorlds();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => scanAllWorlds());
  }

  Future<void> syncNativeService() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(targets.map((e) => e.toJson()).toList());
    await prefs.setString('spy_targets_json', jsonStr);

    try {
      if (isBackgroundActive) {
        await platform.invokeMethod('startRadarService');
        await platform.invokeMethod('syncTargets', {'json': jsonStr});
      } else {
        await platform.invokeMethod('stopRadarService');
      }
    } catch (_) {}
  }

  Future<void> fetchCharacterDetails(String charName) async {
    final key = charName.toLowerCase();
    try {
      final res = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

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
        final response = await http.get(
          Uri.parse('https://api.tibiadata.com/v4/world/$w'),
          headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List players = data['world']?['online_players'] ?? [];
          final now = DateTime.now().millisecondsSinceEpoch;

          addLog("🛰️ $w: ${players.length} jugadores conectados.");

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
    // Únicamente registra desconexiones de personas en la lista (CERO desconocidos)
    for (var t in targets) {
      final name = t.name.toLowerCase();
      if (onlinePlayersData.containsKey(name) && !newOnlineMap.containsKey(name)) {
        if (loginTimestamps.containsKey(name)) {
          sessionDurations[name] = now - loginTimestamps[name]!;
        }
        final dt = DateTime.now();
        logoutTimes[name] = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        addLog("🛑 [OFFLINE]: ${t.name.toUpperCase()} desconectó de ${t.world}");
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
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

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

  // SPRITE OFICIAL ANIMADO DE VOCACIÓN (MAGO FULL CON FERUMBRAS HAT)
  Widget _getOfficialVocationSprite(String? vocation, bool isOnline) {
    final voc = (vocation ?? '').toLowerCase();
    String spriteUrl;

    if (voc.contains('sorcerer')) {
      // MAGO FULL CON EL SOMBRERO DE FERUMBRAS (OFFICIAL GIF)
      spriteUrl = "https://tibia.fandom.com/wiki/Special:FilePath/Outfit_Mage_Male_Addon_3.gif";
    } else if (voc.contains('knight')) {
      // GUERRERO CON ESPADA / FULL KNIGHT (OFFICIAL GIF)
      spriteUrl = "https://tibia.fandom.com/wiki/Special:FilePath/Outfit_Warrior_Male_Addon_3.gif";
    } else if (voc.contains('paladin')) {
      // CAZADOR CON MOCHILA / HUNTER FULL (OFFICIAL GIF)
      spriteUrl = "https://tibia.fandom.com/wiki/Special:FilePath/Outfit_Hunter_Male_Addon_3.gif";
    } else if (voc.contains('druid')) {
      // DRUIDA CON CUERNOS / DRUID FULL (OFFICIAL GIF)
      spriteUrl = "https://tibia.fandom.com/wiki/Special:FilePath/Outfit_Druid_Male_Addon_3.gif";
    } else {
      spriteUrl = "https://tibia.fandom.com/wiki/Special:FilePath/Outfit_Citizen_Male_Addon_3.gif";
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isOnline ? const Color(0xFF00FFB2) : Colors.white12, width: isOnline ? 1.5 : 1.0),
      ),
      child: Center(
        child: Opacity(
          opacity: isOnline ? 1.0 : 0.35,
          child: Image.network(
            spriteUrl,
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24),
          ),
        ),
      ),
    );
  }

  // MONSTRUO OFICIAL ANIMADO EN MOVIMIENTO (SIN LOGOS NI EMOJIS)
  Widget _buildOfficialMonsterSprite(dynamic death) {
    final killers = death['killers'] as List? ?? [];
    if (killers.isEmpty) {
      return Image.network("https://tibia.fandom.com/wiki/Special:FilePath/Demon.gif", width: 34, height: 34);
    }

    final firstKiller = killers.first;
    final killerName = firstKiller['name']?.toString() ?? 'Demon';
    final isPlayer = firstKiller['player'] == true;

    if (isPlayer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFF26080A), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.redAccent)),
        child: Text("PK: ${killerName.toUpperCase()}", style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10)),
      );
    } else {
      final cleanName = killerName.replaceAll(RegExp(r'^(a |an )', caseSensitive: false), '').trim().replaceAll(' ', '_');
      final monsterUrl = "https://tibia.fandom.com/wiki/Special:FilePath/$cleanName.gif";

      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: const Color(0xFF070B14), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)),
        child: Image.network(
          monsterUrl,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.network("https://tibia.fandom.com/wiki/Special:FilePath/Demon.gif", width: 34, height: 34),
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
                boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.8), blurRadius: 8, spreadRadius: 2)],
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
            // PANEL 24/7 FIJO ARRIBA
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
                      isBackgroundActive ? "VIGILANCIA 24/7 EN SEGUNDO PLANO: ACTIVA" : "SEGUNDO PLANO: DESACTIVADO",
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

            // PANEL AGREGAR CON SELECTOR FEROBRA / QUINTERA
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
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 8)),
                          onPressed: () => addTarget('amigo'),
                          child: const Text("🛡️ + AMIGO", style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
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

            // FILTROS
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

            // LISTA ORDENADA (ONLINE PRIMERO)
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
                      child: ListTile(
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
                            : _getOfficialVocationSprite(vocation, isOnline),
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

// -------------------------------------------------------------
// PESTAÑA 2: MUNDO (TARJETA IDÉNTICA CON RASHID Y MAPA REAL)
// -------------------------------------------------------------
class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  Timer? _clockTimer;
  Duration timeToSS = Duration.zero;

  @override
  void initState() {
    super.initState();
    calculateTimeToSS();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => calculateTimeToSS());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
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
      case DateTime.monday: return {'city': 'Svargrond', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Svargrond.png'};
      case DateTime.tuesday: return {'city': 'Liberty Bay', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Liberty_Bay.png'};
      case DateTime.wednesday: return {'city': 'Port Hope', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Port_Hope.png'};
      case DateTime.thursday: return {'city': 'Ankrahmun', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Ankrahmun.png'};
      case DateTime.friday: return {'city': 'Darashia', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Darashia.PNG'};
      case DateTime.saturday: return {'city': 'Edron', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Edron.png'};
      case DateTime.sunday: return {'city': 'Carlin', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Carlin.png'};
      default: return {'city': 'Darashia', 'map': 'https://tibia.fandom.com/wiki/Special:FilePath/Darashia.PNG'};
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TARJETA DE RASHID EXACTAMENTE IDÉNTICA A TU FOTO DE REFERENCIA
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1424),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                // Encabezado superior
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: const Color(0xFF070B14),
                  child: const Center(
                    child: Text("Todos los mundos", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Imagen del mapa con Rashid sobrepuesto a la derecha
                Container(
                  height: 190,
                  width: double.infinity,
                  color: const Color(0xFF1B2E68),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          rData['map']!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF22356B)),
                        ),
                      ),
                      Positioned(
                        right: 25,
                        top: 40,
                        child: Image.network(
                          "https://tibia.fandom.com/wiki/Special:FilePath/Rashid.gif",
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text("🚶", style: TextStyle(fontSize: 32)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Barra inferior azul marina
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFF233660),
                  child: Center(
                    child: Text(
                      "Rashid esta en ${rData['city']}",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
