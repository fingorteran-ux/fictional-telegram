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
    byteData.setUint16(16, 16, Endian.little);
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
        scaffoldBackgroundColor: const Color(0xFF0F1216),
        primaryColor: const Color(0xFF00FFB2),
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
        backgroundColor: const Color(0xFF0A0D12),
        selectedItemColor: const Color(0xFF00FFB2),
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
// PESTAÑA 1: WAR HUD (DISEÑO TIBIA LIVE)
// -------------------------------------------------------------
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  static const platform = MethodChannel('com.tactical.tibia/radar');
  List<TrackTarget> targets = [
    TrackTarget(name: 'Markinjr', type: 'amigo', world: 'Ferobra'),
    TrackTarget(name: 'Fingor', type: 'amigo', world: 'Ferobra'),
    TrackTarget(name: 'Magnustis', type: 'amigo', world: 'Ferobra'),
    TrackTarget(name: 'Nephasto Hunted', type: 'enemigo', world: 'Ferobra'),
  ];

  final TextEditingController _nameController = TextEditingController();
  String selectedWorldInput = 'Ferobra';
  String currentFilter = 'TODOS';

  int globalPlayersOnline = 15561;
  Map<String, dynamic> onlinePlayersData = {};
  Map<String, Map<String, dynamic>> characterInfoCache = {};
  Map<String, List<dynamic>> characterDeaths = {};
  Map<String, bool> loadingDeaths = {};

  Map<String, int> loginTimestamps = {};
  Map<String, int> logoutTimestamps = {};

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
    _clockUpdater = Timer.periodic(const Duration(seconds: 1), (_) {
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
      final key = t.name.toLowerCase();
      muteLoginMap[key] = prefs.getBool('mute_login_$key') ?? false;
      muteLogoutMap[key] = prefs.getBool('mute_logout_$key') ?? false;

      final savedLogout = prefs.getInt('logout_ts_$key');
      if (savedLogout != null) {
        logoutTimestamps[key] = savedLogout;
      }
      fetchCharacterDetails(t.name);
    }

    fetchGlobalPlayersOnline();
    setState(() {});
    addLog("SPY FEROBRA & QUINTERA // EN LÍNEA");
    syncNativeService();
    scanAllWorlds();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      scanAllWorlds();
      fetchGlobalPlayersOnline();
    });
  }

  Future<void> fetchGlobalPlayersOnline() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/worlds'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final total = data['worlds']?['players_online'];
        if (total != null && mounted) {
          setState(() => globalPlayersOnline = total);
        }
      }
    } catch (_) {}
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
        final deaths = data['character']?['deaths'] ?? [];
        if (ch != null) {
          final lastLoginStr = ch['last_login'] ?? '';
          if (lastLoginStr.isNotEmpty && !logoutTimestamps.containsKey(key)) {
            try {
              final parsed = DateTime.parse(lastLoginStr).millisecondsSinceEpoch;
              logoutTimestamps[key] = parsed;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('logout_ts_$key', parsed);
            } catch (_) {}
          }

          setState(() {
            characterInfoCache[key] = {
              'level': ch['level'] ?? 0,
              'vocation': ch['vocation'] ?? 'None',
              'last_login': lastLoginStr,
            };
            characterDeaths[key] = deaths;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> fetchDeaths(String charName) async {
    final key = charName.toLowerCase();
    setState(() => loadingDeaths[key] = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List deaths = data['character']?['deaths'] ?? [];
        setState(() => characterDeaths[key] = deaths);
      }
    } catch (_) {
    } finally {
      setState(() => loadingDeaths[key] = false);
    }
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
      if (radarLogs.length > 25) radarLogs.removeLast();
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
    final prefs = await SharedPreferences.getInstance();

    for (var t in targets) {
      final name = t.name.toLowerCase();
      if (onlinePlayersData.containsKey(name) && !newOnlineMap.containsKey(name)) {
        logoutTimestamps[name] = now;
        await prefs.setInt('logout_ts_$name', now);
        addLog("🛑 [OFFLINE]: ${t.name.toUpperCase()} desconectó de ${t.world}");
      }
    }

    setState(() {
      onlinePlayersData = newOnlineMap;
      isScanning = false;
    });
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

  void _showIndividualAlertConfig(TrackTarget target) {
    final key = target.name.toLowerCase();
    bool muteLogin = muteLoginMap[key] ?? false;
    bool muteLogout = muteLogoutMap[key] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131822),
          title: Text(
            "${target.type.toUpperCase()}: ${target.name.toUpperCase()} (${target.world})",
            style: TextStyle(color: target.type == 'amigo' ? const Color(0xFF00FFB2) : const Color(0xFFFF5252), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Avisar al Conectar", style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                subtitle: Text("Voz anunciando conexión en ${target.world}", style: const TextStyle(fontSize: 10, color: Colors.white38)),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black),
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

  // SPRITE CAMINANDO EN ÁNGULO DIAGONAL AUTÉNTICO (TIBIA LIVE)
  Widget _getOfficialVocationSprite(String? vocation, bool isOnline) {
    final voc = (vocation ?? '').toLowerCase();
    String animUrl;

    if (voc.contains('sorcerer')) {
      animUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=130&addons=3&direction=3";
    } else if (voc.contains('knight')) {
      animUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=131&addons=3&direction=3";
    } else if (voc.contains('paladin')) {
      animUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=129&addons=3&direction=3";
    } else if (voc.contains('druid')) {
      animUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=144&addons=3&direction=3";
    } else {
      animUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=128&addons=3&direction=3";
    }

    return Opacity(
      opacity: isOnline ? 1.0 : 0.35,
      child: Image.network(
        animUrl,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 36),
      ),
    );
  }

  String formatElapsedTime(int millis) {
    final seconds = (millis / 1000).floor();
    if (seconds < 60) return "${seconds}s";
    final mins = (seconds / 60).floor();
    if (mins < 60) return "${mins}m";
    final hrs = (mins / 60).floor();
    final remMins = mins % 60;
    if (hrs < 24) return "${hrs}h ${remMins}m";
    final days = (hrs / 24).floor();
    final remHrs = hrs % 24;
    return "${days}d ${remHrs}h";
  }

  @override
  Widget build(BuildContext context) {
    final displayList = dynamicFilteredTargets;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D12),
        elevation: 0,
        title: const Text(
          "SPY FEROBRA // TACTICAL WAR",
          style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            icon: Icon(TacticalAudio.soundEnabled ? Icons.volume_up : Icons.volume_off, color: TacticalAudio.soundEnabled ? const Color(0xFF00FFB2) : Colors.grey),
            onPressed: () => setState(() => TacticalAudio.soundEnabled = !TacticalAudio.soundEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FFB2)),
            onPressed: isScanning ? null : scanAllWorlds,
          )
        ],
      ),
      body: Column(
        children: [
          // -------------------------------------------------------------
          // CABECERA SUPERIOR: JUGADORES ONLINE CON GRÁFICA TIBIA LIVE
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F1318),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Jugadores online",
                      style: TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      globalPlayersOnline.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                // Sparkline estilizado
                SizedBox(
                  width: 140,
                  height: 32,
                  child: CustomPaint(
                    painter: SparklinePainter(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              children: [
                // Panel de Segundo Plano
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141922),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isBackgroundActive ? const Color(0xFF00FFB2).withOpacity(0.5) : Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(isBackgroundActive ? Icons.security : Icons.security_update_warning, color: isBackgroundActive ? const Color(0xFF00FFB2) : Colors.redAccent, size: 16),
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

                // Formulario Agregar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF141922), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
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
                            decoration: BoxDecoration(color: const Color(0xFF1E2532), borderRadius: BorderRadius.circular(4)),
                            child: DropdownButton<String>(
                              value: selectedWorldInput,
                              dropdownColor: const Color(0xFF141922),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Color(0xFF00FFB2), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
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

                // Filtros
                Row(
                  children: [
                    _filterBtn('TODOS'),
                    const SizedBox(width: 6),
                    _filterBtn('ENEMIGOS'),
                    const SizedBox(width: 6),
                    _filterBtn('AMIGOS'),
                    const Spacer(),
                    IconButton(
                      icon: Icon(isSelectionMode ? Icons.close : Icons.checklist, size: 20, color: const Color(0xFF00FFB2)),
                      onPressed: () {
                        setState(() {
                          isSelectionMode = !isSelectionMode;
                          selectedTargets.clear();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: selectAllTargets,
                    child: Text(selectedTargets.length == targets.length ? "DESMARCAR" : "TODOS (${targets.length})", style: const TextStyle(color: Colors.amber, fontFamily: 'monospace', fontSize: 11)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    onPressed: selectedTargets.isEmpty ? null : deleteSelectedTargets,
                    child: Text("BORRAR (${selectedTargets.length})", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // -------------------------------------------------------------
          // TARJETAS AL ESTILO EXACTO DE TIBIA LIVE (LÍNEA INFERIOR VERDE/ROJA)
          // -------------------------------------------------------------
          Expanded(
            flex: 5,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                final target = displayList[index];
                final key = target.name.toLowerCase();
                final isOnline = onlinePlayersData.containsKey(key);
                final onlineData = onlinePlayersData[key];
                final cachedInfo = characterInfoCache[key] ?? {};
                final deaths = characterDeaths[key] ?? [];
                final isChecked = selectedTargets.contains(key);

                final level = isOnline ? (onlineData['level'] ?? 0) : (cachedInfo['level'] ?? 0);
                final vocation = isOnline ? (onlineData['vocation'] ?? '') : (cachedInfo['vocation'] ?? 'Consultando...');

                String timerText = "";
                if (isOnline) {
                  if (loginTimestamps.containsKey(key)) {
                    final diff = nowMs - loginTimestamps[key]!;
                    timerText = "En línea: ${formatElapsedTime(diff)}";
                  } else {
                    timerText = "En línea";
                  }
                } else {
                  if (logoutTimestamps.containsKey(key)) {
                    final diff = nowMs - logoutTimestamps[key]!;
                    timerText = "Offline hace: ${formatElapsedTime(diff)}";
                  } else {
                    timerText = "Desconectado";
                  }
                }

                // Línea inferior estilo Tibia Live: Verde si online/amigo, Roja si enemigo/hunted
                final bottomLineColor = target.type == 'enemigo'
                    ? const Color(0xFFFF5252)
                    : (isOnline ? const Color(0xFF4CAF50) : const Color(0xFF2C3848));

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151921),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      bottom: BorderSide(color: bottomLineColor, width: 3.5),
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      onExpansionChanged: (expanded) {
                        if (expanded && deaths.isEmpty) {
                          fetchDeaths(target.name);
                        }
                      },
                      leading: isSelectionMode
                          ? Checkbox(
                              activeColor: const Color(0xFF00FFB2),
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
                          Expanded(
                            child: Text(
                              target.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                          Text(
                            target.world,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            "Nivel $level – $vocation",
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timerText,
                            style: TextStyle(
                              color: isOnline ? const Color(0xFF00FFB2) : Colors.white38,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white38, size: 18),
                            onPressed: () => _showIndividualAlertConfig(target),
                          ),
                          if (!isSelectionMode)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              onPressed: () => removeTarget(target.name),
                            ),
                        ],
                      ),
                      // Historial de muertes
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          color: const Color(0xFF0C1016),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("💀 HISTORIAL DE MUERTES", style: TextStyle(color: Color(0xFFFF5252), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                                  if (loadingDeaths[key] == true)
                                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5252))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (deaths.isEmpty && loadingDeaths[key] != true)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text("Sin muertes recientes registradas en la web.", style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
                                )
                              else
                                ...deaths.take(3).map((d) {
                                  final killers = (d['killers'] as List? ?? []);
                                  String killerName = "Criatura desconocida";
                                  bool isPk = false;
                                  if (killers.isNotEmpty) {
                                    killerName = killers.first['name'] ?? 'Desconocido';
                                    isPk = killers.first['player'] == true;
                                  }
                                  final dateStr = (d['time'] ?? '').toString().replaceFirst('T', ' ').replaceAll('Z', '');

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF151A24),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isPk ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isPk ? Icons.sports_kabaddi : Icons.dangerous, color: isPk ? Colors.redAccent : Colors.orangeAccent, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Lvl ${d['level']} por: ${killerName.toUpperCase()}",
                                                style: TextStyle(color: isPk ? const Color(0xFFFF6B6B) : Colors.white, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isPk)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                                            child: const Text("PK", style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                          )
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
                );
              },
            ),
          ),

          // Consola militar pequeña
          Container(
            height: 65,
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            color: const Color(0xFF080A0E),
            child: ListView.builder(
              itemCount: radarLogs.length,
              itemBuilder: (context, index) {
                return Text(radarLogs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFF80DEEA)));
              },
            ),
          ),
        ],
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
          color: isSelected ? const Color(0xFF00FFB2) : const Color(0xFF141922),
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

// Pintor de gráfica de tendencia en verde neón (Tibia Live style)
class SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFB2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.cubicTo(
      size.width * 0.35, size.height * 0.1,
      size.width * 0.65, size.height * 0.9,
      size.width, size.height * 0.6,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// PESTAÑA 2: MUNDO, RASHID Y BLOQUES BOOSTED CREATURE & BOSS
// -------------------------------------------------------------
class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  Timer? _clockTimer;
  Duration timeToSS = Duration.zero;

  String boostedCreatureName = "Cargando...";
  String boostedCreatureImg = "";

  String boostedBossName = "Cargando...";
  String boostedBossImg = "";

  @override
  void initState() {
    super.initState();
    calculateTimeToSS();
    fetchBoostedData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => calculateTimeToSS());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchBoostedData() async {
    // 1. Boosted Creature
    try {
      final resC = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/creatures'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 8));

      if (resC.statusCode == 200) {
        final data = json.decode(resC.body);
        final b = data['creatures']?['boosted'];
        if (b != null && mounted) {
          setState(() {
            boostedCreatureName = b['name'] ?? 'Rustheap Golem';
            boostedCreatureImg = b['image_url'] ?? '';
          });
        }
      }
    } catch (_) {}

    // 2. Boosted Boss
    try {
      final resB = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/boostablebosses'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 8));

      if (resB.statusCode == 200) {
        final data = json.decode(resB.body);
        final b = data['boostable_bosses']?['boosted'];
        if (b != null && mounted) {
          setState(() {
            boostedBossName = b['name'] ?? 'The Diamond Blossom';
            boostedBossImg = b['image_url'] ?? '';
          });
        }
      }
    } catch (_) {}
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
      case DateTime.monday: return {'city': 'Svargrond', 'bg': '0xFF192A44'};
      case DateTime.tuesday: return {'city': 'Liberty Bay', 'bg': '0xFF1A384A'};
      case DateTime.wednesday: return {'city': 'Port Hope', 'bg': '0xFF143322'};
      case DateTime.thursday: return {'city': 'Ankrahmun', 'bg': '0xFF473C1E'};
      case DateTime.friday: return {'city': 'Darashia', 'bg': '0xFF4A3E20'};
      case DateTime.saturday: return {'city': 'Edron', 'bg': '0xFF272A3D'};
      case DateTime.sunday: return {'city': 'Carlin', 'bg': '0xFF20352A'};
      default: return {'city': 'Darashia', 'bg': '0xFF4A3E20'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = timeToSS.inHours.toString().padLeft(2, '0');
    final minutes = (timeToSS.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (timeToSS.inSeconds % 60).toString().padLeft(2, '0');
    final rData = getRashidData();

    const rashidWalkingUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=146&addons=0&head=78&body=106&legs=58&feet=76&direction=3";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D12),
        title: const Text("MUNDO & TIBIA LIVE", style: TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Contador Server Save
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF141922), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.4))),
            child: Column(
              children: [
                const Text("⏳ CUENTA REGRESIVA SERVER SAVE (SS)", style: TextStyle(color: Color(0xFF00FFB2), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("$hours : $minutes : $seconds", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // BLOQUES BOOSTED CREATURE & BOOSTED BOSS (IDÉNTICO A TIBIA LIVE)
          // -------------------------------------------------------------
          Row(
            children: [
              // 1. Boosted Creature
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151921),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Boosted Creature",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: boostedCreatureImg.isNotEmpty
                            ? Image.network(
                                boostedCreatureImg,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, __, ___) => const Icon(Icons.pest_control, color: Colors.white24, size: 36),
                              )
                            : const Icon(Icons.pest_control, color: Colors.white24, size: 36),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        boostedCreatureName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Boosted Boss
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151921),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Boosted Boss",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: boostedBossImg.isNotEmpty
                            ? Image.network(
                                boostedBossImg,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white24, size: 36),
                              )
                            : const Icon(Icons.shield, color: Colors.white24, size: 36),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        boostedBossName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // TARJETA DE RASHID CON MINIMAPA REAL Y SPRITE CAMINANDO
          // -------------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151921),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  color: const Color(0xFF0D1016),
                  child: const Text(
                    "Todos los mundos",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(int.parse(rData['bg']!)),
                  ),
                  child: Stack(
                    children: [
                      // Minimapa esquemático auténtico de Darashia / Ciudades
                      Positioned(
                        left: 14,
                        top: 14,
                        child: Container(
                          width: 140,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD2B57B), // Color arena desierto Darashia
                            border: Border.all(color: Colors.black45),
                          ),
                          child: CustomPaint(
                            painter: MinimapHousesPainter(),
                          ),
                        ),
                      ),
                      // Rashid caminando en diagonal (estilo Tibia Live)
                      Positioned(
                        right: 35,
                        top: 25,
                        child: Image.network(
                          rashidWalkingUrl,
                          width: 65,
                          height: 65,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, __, ___) => const Text("🚶", style: TextStyle(fontSize: 32)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: const Color(0xFF1E2634),
                  child: Text(
                    "Rashid esta en ${rData['city']}",
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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

// Pintor de casitas en cuadritos para el minimapa
class MinimapHousesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final housePaint = Paint()
      ..color = const Color(0xFF8B4513) // Techos marrones
      ..style = PaintingStyle.fill;

    final wallPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final houses = [
      Rect.fromLTWH(15, 15, 20, 20),
      Rect.fromLTWH(45, 15, 25, 20),
      Rect.fromLTWH(80, 20, 20, 25),
      Rect.fromLTWH(20, 48, 22, 22),
      Rect.fromLTWH(55, 50, 30, 25),
      Rect.fromLTWH(100, 55, 20, 20),
    ];

    for (var h in houses) {
      canvas.drawRect(h, housePaint);
      canvas.drawRect(h, wallPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// PESTAÑA 3: EVENTOS
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
        backgroundColor: const Color(0xFF0A0D12),
        title: const Text("CRONÓMETROS DE EVENTOS", style: TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _liveEventCard(
            title: "⚔️ DOBLE EXP & SKILL",
            countdown: getTimeRemaining(12, 10),
            desc: "Doble experiencia en cacería y doble velocidad en training.",
            color: const Color(0xFF00FFB2),
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
            color: const Color(0xFF00E5FF),
          ),
        ],
      ),
    );
  }

  Widget _liveEventCard({required String title, required String countdown, required String desc, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151921),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF0A0D12), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text("⏳ Inicia en: $countdown", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
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
