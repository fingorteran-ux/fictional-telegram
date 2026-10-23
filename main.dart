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

// -------------------------------------------------------------
// AUDIO MILITAR
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// APP & ROOT
// -------------------------------------------------------------
class SpyFerobraApp extends StatelessWidget {
  const SpyFerobraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spy Ferobra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101317),
        primaryColor: const Color(0xFF00FFB2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0D12),
          elevation: 0,
        ),
      ),
      home: const MainDrawerScreen(),
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
// CONTENEDOR PRINCIPAL CON MENÚ LATERAL (DRAWER COMPLETO)
// -------------------------------------------------------------
class MainDrawerScreen extends StatefulWidget {
  const MainDrawerScreen({super.key});

  @override
  State<MainDrawerScreen> createState() => _MainDrawerScreenState();
}

class _MainDrawerScreenState extends State<MainDrawerScreen> {
  int _selectedDrawerIndex = 0;

  final List<Widget> _views = const [
    HomeScreen(),
    WorldsScreen(),
    EventsScreen(),
    PartyShareCalculatorScreen(),
    BlessingsCalculatorScreen(),
  ];

  final List<String> _titles = const [
    "Tibia Live // Spy Ferobra",
    "Mundos de Tibia",
    "Calendario de Eventos",
    "Compartir Experiencia",
    "Calculadora de Blessings",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedDrawerIndex],
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(TacticalAudio.soundEnabled ? Icons.volume_up : Icons.volume_off, color: TacticalAudio.soundEnabled ? const Color(0xFF00FFB2) : Colors.grey),
            onPressed: () => setState(() => TacticalAudio.soundEnabled = !TacticalAudio.soundEnabled),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF13171F),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A0D12), Color(0xFF192333)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF00FFB2).withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.security, color: Color(0xFF00FFB2), size: 28),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SPY FEROBRA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          Text("SISTEMA ILIMITADO // PRO FREE", style: TextStyle(color: Color(0xFF00FFB2), fontSize: 10, fontFamily: 'monospace')),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("Vigilancia táctica 24/7 sin bloqueos", style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            _drawerTile(0, Icons.home, "Inicio (Radar & HUD)"),
            _drawerTile(1, Icons.public, "Mundos"),
            _drawerTile(2, Icons.event_available, "Eventos"),
            const Divider(color: Colors.white12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text("HERRAMIENTAS TÁCTICAS", style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ),
            _drawerTile(3, Icons.group_add, "Compartir Experiencia (Party)"),
            _drawerTile(4, Icons.shield, "Blessings & Costos de Muerte"),
          ],
        ),
      ),
      body: _views[_selectedDrawerIndex],
    );
  }

  Widget _drawerTile(int index, IconData icon, String title) {
    final isSelected = _selectedDrawerIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF00FFB2) : Colors.white60, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF00FFB2) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() => _selectedDrawerIndex = index);
        Navigator.pop(context);
      },
    );
  }
}

// -------------------------------------------------------------
// PANTALLA 1: INICIO (HOME / RADAR / TIBIA LIVE COMPLETO)
// -------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  int globalPlayersOnline = 15330;
  Map<String, dynamic> onlinePlayersData = {};
  Map<String, Map<String, dynamic>> characterFullData = {};

  Map<String, int> loginTimestamps = {};
  Map<String, int> logoutTimestamps = {};

  Map<String, bool> muteLoginMap = {};
  Map<String, bool> muteLogoutMap = {};
  Map<String, String> characterNotes = {};

  String boostedCreatureName = "Rustheap Golem";
  String boostedCreatureImg = "";
  String boostedBossName = "The Diamond Blossom";
  String boostedBossImg = "";

  List<String> radarLogs = [];
  bool isScanning = false;
  bool isBackgroundActive = true;
  Timer? _timer;
  Timer? _clockUpdater;

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
      characterNotes[key] = prefs.getString('note_$key') ?? '';

      final savedLogout = prefs.getInt('logout_ts_$key');
      if (savedLogout != null) {
        logoutTimestamps[key] = savedLogout;
      }
      fetchCharacterDetails(t.name);
    }

    fetchGlobalPlayersOnline();
    fetchBoostedData();
    syncNativeService();
    scanAllWorlds();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      scanAllWorlds();
      fetchGlobalPlayersOnline();
    });
  }

  Future<void> fetchGlobalPlayersOnline() async {
    try {
      final res = await http.get(Uri.parse('https://api.tibiadata.com/v4/worlds')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final total = data['worlds']?['players_online'];
        if (total != null && mounted) setState(() => globalPlayersOnline = total);
      }
    } catch (_) {}
  }

  Future<void> fetchBoostedData() async {
    try {
      final resC = await http.get(Uri.parse('https://api.tibiadata.com/v4/creatures')).timeout(const Duration(seconds: 8));
      if (resC.statusCode == 200) {
        final b = json.decode(resC.body)['creatures']?['boosted'];
        if (b != null && mounted) {
          setState(() {
            boostedCreatureName = b['name'] ?? 'Rustheap Golem';
            boostedCreatureImg = b['image_url'] ?? '';
          });
        }
      }
    } catch (_) {}

    try {
      final resB = await http.get(Uri.parse('https://api.tibiadata.com/v4/boostablebosses')).timeout(const Duration(seconds: 8));
      if (resB.statusCode == 200) {
        final b = json.decode(resB.body)['boostable_bosses']?['boosted'];
        if (b != null && mounted) {
          setState(() {
            boostedBossName = b['name'] ?? 'The Diamond Blossom';
            boostedBossImg = b['image_url'] ?? '';
          });
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
        final houses = data['character']?['houses'] ?? [];
        final guild = data['character']?['guild'] ?? {};

        if (ch != null) {
          final lastLoginStr = ch['last_login'] ?? '';
          if (lastLoginStr.isNotEmpty && !logoutTimestamps.containsKey(key)) {
            try {
              final parsed = DateTime.parse(lastLoginStr).millisecondsSinceEpoch;
              logoutTimestamps[key] = parsed;
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              characterFullData[key] = {
                'raw': ch,
                'deaths': deaths,
                'houses': houses,
                'guild': guild,
                'level': ch['level'] ?? 0,
                'vocation': ch['vocation'] ?? 'None',
                'residence': ch['town'] ?? 'Thais',
                'account_status': ch['account_status'] ?? 'Free Account',
                'achievement_points': ch['achievement_points'] ?? 0,
                'last_login': lastLoginStr,
              };
            });
          }
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

  List<TrackTarget> get filteredTargets {
    var list = targets.where((t) {
      if (currentFilter == 'ENEMIGOS') return t.type == 'enemigo';
      if (currentFilter == 'AMIGOS') return t.type == 'amigo';
      return true;
    }).toList();

    list.sort((a, b) {
      final aOn = onlinePlayersData.containsKey(a.name.toLowerCase()) ? 1 : 0;
      final bOn = onlinePlayersData.containsKey(b.name.toLowerCase()) ? 1 : 0;
      if (aOn != bOn) return bOn.compareTo(aOn);
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
      }
    }

    if (mounted) {
      setState(() {
        onlinePlayersData = newOnlineMap;
        isScanning = false;
      });
    }
  }

  void addTarget(String type) {
    final text = _nameController.text.trim();
    if (text.isNotEmpty && !targets.any((t) => t.name.toLowerCase() == text.toLowerCase())) {
      final newT = TrackTarget(name: text, type: type, world: selectedWorldInput);
      setState(() => targets.add(newT));
      fetchCharacterDetails(text);
      syncNativeService();
      _nameController.clear();
      scanAllWorlds();
    }
  }

  void removeTarget(String name) {
    setState(() {
      targets.removeWhere((t) => t.name.toLowerCase() == name.toLowerCase());
    });
    syncNativeService();
  }

  Widget _getVocationWalkingSprite(String? vocation, bool isOnline) {
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
      opacity: isOnline ? 1.0 : 0.4,
      child: Image.network(
        animUrl,
        width: 46,
        height: 46,
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
    final displayList = filteredTargets;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return ListView(
      children: [
        // 1. Ticker / Noticia superior
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF191F2B),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("NOTICIA OFICIAL DE TIBIA", style: TextStyle(color: Color(0xFF00FFB2), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text("New Optional and Open PvP Game Worlds", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text("Los servidores de prueba ya se encuentran disponibles para la comunidad.", style: TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ),

        // 2. Jugadores Online + Gráfica Tibia Live
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF0F1318),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Jugadores online", style: TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text(
                    globalPlayersOnline.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),
              SizedBox(
                width: 140,
                height: 32,
                child: CustomPaint(painter: SparklinePainter()),
              ),
            ],
          ),
        ),

        // 3. Panel de agregar personaje
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF151A22), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                            decoration: const InputDecoration(hintText: "Rastrear personaje...", hintStyle: TextStyle(color: Colors.white30, fontSize: 12), border: InputBorder.none),
                          ),
                        ),
                        DropdownButton<String>(
                          value: selectedWorldInput,
                          dropdownColor: const Color(0xFF151A22),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Color(0xFF00FFB2), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                          items: ['Ferobra', 'Quintera', 'Antica'].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedWorldInput = val);
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 6)),
                            onPressed: () => addTarget('amigo'),
                            child: const Text("🛡️ + AMIGO", style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6)),
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

              // Contador de capacidad ilimitada (Sin restricciones Pro)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("RASTREANDO (${targets.length}) // SIN LÍMITES", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      _filterTab('TODOS'),
                      const SizedBox(width: 4),
                      _filterTab('ENEMIGOS'),
                      const SizedBox(width: 4),
                      _filterTab('AMIGOS'),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),

        // 4. Lista de Personajes (Al tocar abre Información del Personaje)
        ...displayList.map((target) {
          final key = target.name.toLowerCase();
          final isOnline = onlinePlayersData.containsKey(key);
          final full = characterFullData[key] ?? {};
          final level = isOnline ? (onlinePlayersData[key]['level'] ?? 0) : (full['level'] ?? 0);
          final vocation = isOnline ? (onlinePlayersData[key]['vocation'] ?? '') : (full['vocation'] ?? 'Cargando...');

          String timerText = "";
          if (isOnline) {
            final diff = nowMs - (loginTimestamps[key] ?? nowMs);
            timerText = "En línea: ${formatElapsedTime(diff)}";
          } else {
            final diff = nowMs - (logoutTimestamps[key] ?? nowMs);
            timerText = "Offline hace: ${formatElapsedTime(diff)}";
          }

          final bottomLineColor = target.type == 'enemigo'
              ? const Color(0xFFFF5252)
              : (isOnline ? const Color(0xFF4CAF50) : const Color(0xFF2C3848));

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF151921),
              borderRadius: BorderRadius.circular(4),
              border: Border(bottom: BorderSide(color: bottomLineColor, width: 3.5)),
            ),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CharacterDetailScreen(
                      target: target,
                      fullData: full,
                      isOnline: isOnline,
                      onlineData: onlinePlayersData[key],
                    ),
                  ),
                );
              },
              leading: _getVocationWalkingSprite(vocation, isOnline),
              title: Row(
                children: [
                  Expanded(
                    child: Text(target.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isOnline ? Colors.white : Colors.white70)),
                  ),
                  Text(target.world, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Nivel $level – $vocation", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(timerText, style: TextStyle(color: isOnline ? const Color(0xFF00FFB2) : Colors.white38, fontSize: 10, fontFamily: 'monospace')),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white30, size: 16),
                onPressed: () => removeTarget(target.name),
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // 5. Bloques Boosted Creature & Boss
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
                  child: Column(
                    children: [
                      const Text("Boosted Creature", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: boostedCreatureImg.isNotEmpty
                            ? Image.network(boostedCreatureImg, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.pest_control, color: Colors.white24))
                            : const Icon(Icons.pest_control, color: Colors.white24),
                      ),
                      const SizedBox(height: 6),
                      Text(boostedCreatureName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
                  child: Column(
                    children: [
                      const Text("Boosted Boss", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: boostedBossImg.isNotEmpty
                            ? Image.network(boostedBossImg, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white24))
                            : const Icon(Icons.shield, color: Colors.white24),
                      ),
                      const SizedBox(height: 6),
                      Text(boostedBossName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 6. Tarjeta Rashid
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: const Color(0xFF0D1016),
                child: const Text("Todos los mundos", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              Container(
                height: 110,
                width: double.infinity,
                color: const Color(0xFF4A3E20),
                child: Stack(
                  children: [
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Container(
                        width: 120,
                        height: 80,
                        decoration: BoxDecoration(color: const Color(0xFFD2B57B), border: Border.all(color: Colors.black45)),
                        child: CustomPaint(painter: MinimapHousesPainter()),
                      ),
                    ),
                    Positioned(
                      right: 35,
                      top: 20,
                      child: Image.network(
                        "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=146&addons=0&head=78&body=106&legs=58&feet=76&direction=3",
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text("🚶", style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                color: const Color(0xFF1E2634),
                child: const Text("Rashid esta en Darashia", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _filterTab(String label) {
    final isSelected = currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => currentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFB2) : const Color(0xFF151921),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white60),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// PANTALLA DE DETALLE COMPLETO (INFORMACIÓN DEL PERSONAJE)
// -------------------------------------------------------------
class CharacterDetailScreen extends StatefulWidget {
  final TrackTarget target;
  final Map<String, dynamic> fullData;
  final bool isOnline;
  final dynamic onlineData;

  const CharacterDetailScreen({
    super.key,
    required this.target,
    required this.fullData,
    required this.isOnline,
    this.onlineData,
  });

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  String note = "";

  @override
  void initState() {
    super.initState();
    loadNote();
  }

  Future<void> loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      note = prefs.getString('note_${widget.target.name.toLowerCase()}') ?? '';
    });
  }

  void editNoteDialog() {
    final controller = TextEditingController(text: note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151A24),
        title: Text("Nota para ${widget.target.name}", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 14)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(hintText: "Ej: Caza en Asuras a las 20:00...", hintStyle: TextStyle(color: Colors.white30)),
        ),
        actions: [
          TextButton(child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('note_${widget.target.name.toLowerCase()}', controller.text);
              setState(() => note = controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("ACEPTAR"),
          ),
        ],
      ),
    );
  }

  void notificationsConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final key = widget.target.name.toLowerCase();
    bool notifLogin = prefs.getBool('mute_login_$key') != true;
    bool notifLogout = prefs.getBool('mute_logout_$key') != true;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF151A24),
          title: Text("Notificaciones para ${widget.target.name}", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 13, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Notificaciones de login", style: TextStyle(fontSize: 12)),
                value: notifLogin,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => notifLogin = val),
              ),
              SwitchListTile(
                title: const Text("Notificaciones de logout", style: TextStyle(fontSize: 12)),
                value: notifLogout,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => notifLogout = val),
              ),
              const ListTile(
                title: Text("Notificaciones de subida de nivel", style: TextStyle(fontSize: 12)),
                trailing: Icon(Icons.check_circle, color: Color(0xFF00FFB2), size: 20),
                subtitle: Text("Desbloqueado PRO", style: TextStyle(fontSize: 10, color: Color(0xFF00FFB2))),
              ),
              const ListTile(
                title: Text("Notificaciones de muerte", style: TextStyle(fontSize: 12)),
                trailing: Icon(Icons.check_circle, color: Color(0xFF00FFB2), size: 20),
                subtitle: Text("Desbloqueado PRO", style: TextStyle(fontSize: 10, color: Color(0xFF00FFB2))),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black),
              onPressed: () async {
                await prefs.setBool('mute_login_$key', !notifLogin);
                await prefs.setBool('mute_logout_$key', !notifLogout);
                Navigator.pop(ctx);
              },
              child: const Text("GUARDAR"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.fullData['raw'] ?? {};
    final level = widget.isOnline ? (widget.onlineData?['level'] ?? widget.fullData['level'] ?? 0) : (widget.fullData['level'] ?? 0);
    final vocation = widget.isOnline ? (widget.onlineData?['vocation'] ?? widget.fullData['vocation'] ?? '') : (widget.fullData['vocation'] ?? '');
    final residence = raw['town'] ?? 'Thais';
    final accountStatus = raw['account_status'] ?? 'Premium';
    final deaths = (widget.fullData['deaths'] as List? ?? []);
    final houses = (widget.fullData['houses'] as List? ?? []);
    final guild = (widget.fullData['guild'] as Map? ?? {});

    return Scaffold(
      appBar: AppBar(
        title: const Text("Información del personaje", style: TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: notificationsConfigDialog),
          PopupMenuButton<String>(
            color: const Color(0xFF151A24),
            onSelected: (val) {
              if (val == 'note') editNoteDialog();
              if (val == 'share') {
                Clipboard.setData(ClipboardData(text: "https://www.tibia.com/community/?subtopic=characters&name=${widget.target.name}"));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enlace oficial copiado al portapapeles")));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'note', child: Text("Editar nota")),
              const PopupMenuItem(value: 'share', child: Text("Compartir enlace")),
            ],
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Cabecera idéntica a Tibia Live
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                Image.network(
                  "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=131&addons=3&direction=3",
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.target.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("Nivel $level – $vocation", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (guild['name'] != null)
                        Text("${guild['rank'] ?? 'Member'} de ${guild['name']}", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Mini mapa de residencia
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF192A44), borderRadius: BorderRadius.circular(4)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.network("https://tibiamaps.github.io/tibia-map-data/floor-07-map.png", fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_city, color: Color(0xFF00FFB2), size: 30),
                      const SizedBox(height: 4),
                      Text("Residencia: $residence".toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Rejilla de Información
          Row(
            children: [
              _infoTile("Residencia", residence),
              const SizedBox(width: 8),
              _infoTile("Mundo", widget.target.world),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoTile("Estado de cuenta", accountStatus),
              const SizedBox(width: 8),
              _infoTile("Estado", widget.isOnline ? "Online" : "Desconectado", isOnlineColor: widget.isOnline),
            ],
          ),
          const SizedBox(height: 10),

          // Nota
          if (note.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF151E2D), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.4))),
              child: Row(
                children: [
                  const Icon(Icons.note_alt, color: Color(0xFF00FFB2), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Nota: $note", style: const TextStyle(color: Colors.white, fontSize: 12))),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Casas
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Casas", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (houses.isEmpty)
                  const Text("Sin casas", style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  ...houses.map((h) => Text("🏠 ${h['name']} (${h['town']}) – ${h['rent']} gp/mes", style: const TextStyle(color: Colors.white, fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Muertes con PK atacantes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Muertes", style: TextStyle(color: Color(0xFFFF5252), fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (deaths.isEmpty)
                  const Text("Sin muertes recientes", style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  ...deaths.map((d) {
                    final killers = (d['killers'] as List? ?? []);
                    final dateStr = (d['time'] ?? '').toString().replaceFirst('T', ' ').replaceAll('Z', '');
                    final isPkMass = killers.length > 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF0E121A), borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${d['level']} NIVEL", style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPkMass ? "Muerto por: ${killers.length} jugadores" : "Muerto por: ${killers.isNotEmpty ? killers.first['name'] : 'Criatura'}",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          if (isPkMass) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: killers.map((k) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                                  child: Text("⚔️ ${k['name']}", style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 10)),
                                );
                              }).toList(),
                            )
                          ]
                        ],
                      ),
                    );
                  }),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {bool isOnlineColor = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: isOnlineColor ? const Color(0xFF00FFB2) : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// PANTALLA: MUNDOS
// -------------------------------------------------------------
class WorldsScreen extends StatefulWidget {
  const WorldsScreen({super.key});

  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> {
  List<dynamic> worlds = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchWorlds();
  }

  Future<void> fetchWorlds() async {
    try {
      final res = await http.get(Uri.parse('https://api.tibiadata.com/v4/worlds')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          worlds = data['worlds']?['regular_worlds'] ?? [];
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2)));

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: worlds.length,
      itemBuilder: (_, idx) {
        final w = worlds[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w['name'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text("${w['pvp_type']} – ${w['location']}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              Text("${w['players_online']} online", style: const TextStyle(color: Color(0xFF00FFB2), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// PANTALLA: COMPARTIR EXPERIENCIA (PARTY SHARE CALCULATOR)
// -------------------------------------------------------------
class PartyShareCalculatorScreen extends StatefulWidget {
  const PartyShareCalculatorScreen({super.key});

  @override
  State<PartyShareCalculatorScreen> createState() => _PartyShareCalculatorScreenState();
}

class _PartyShareCalculatorScreenState extends State<PartyShareCalculatorScreen> {
  final TextEditingController _levelCtrl = TextEditingController(text: "500");
  int minLvl = 333;
  int maxLvl = 750;

  void calculate() {
    final lvl = int.tryParse(_levelCtrl.text) ?? 1;
    setState(() {
      minLvl = (lvl * 2 / 3).floor();
      maxLvl = (lvl * 3 / 2).ceil();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _levelCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: "Tu Nivel de Personaje", labelStyle: TextStyle(color: Color(0xFF00FFB2))),
            onChanged: (_) => calculate(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text("$minLvl", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text("Nivel Mínimo", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Column(
                  children: [
                    Text("$maxLvl", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text("Nivel Máximo", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// PANTALLA: CALCULADORA DE BLESSINGS
// -------------------------------------------------------------
class BlessingsCalculatorScreen extends StatefulWidget {
  const BlessingsCalculatorScreen({super.key});

  @override
  State<BlessingsCalculatorScreen> createState() => _BlessingsCalculatorScreenState();
}

class _BlessingsCalculatorScreenState extends State<BlessingsCalculatorScreen> {
  final TextEditingController _levelCtrl = TextEditingController(text: "300");
  bool promoted = true;

  int calculateTotalBless(int lvl) {
    int regularCost = 20000;
    if (lvl <= 30) {
      regularCost = 2000;
    } else if (lvl < 120) {
      regularCost = 2000 + (lvl - 30) * 200;
    }
    return regularCost * 7;
  }

  @override
  Widget build(BuildContext context) {
    final lvl = int.tryParse(_levelCtrl.text) ?? 100;
    final totalGold = calculateTotalBless(lvl);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _levelCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(labelText: "Nivel del Personaje", labelStyle: TextStyle(color: Color(0xFF00FFB2))),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Costo total de 7 Blessings: $totalGold gp", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("Bendición Twist of Fate (PvP): 50,000 gp", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Divider(color: Colors.white12),
              const Text("Protección de Equipo: 100% garantizado con 5+ blessings", style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// PANTALLA: EVENTOS
// -------------------------------------------------------------
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _eventItem("Annual Autumn Vintage", "En curso – Finaliza en 8 horas", Colors.amber),
        _eventItem("Halloween Event", "31 octubre – 3 noviembre", const Color(0xFF00FFB2)),
        _eventItem("The Lightbearer", "11 noviembre – 15 noviembre", Colors.orangeAccent),
        _eventItem("Full Moon", "12 noviembre – 15 noviembre", const Color(0xFF00E5FF)),
        _eventItem("Double XP & Skill", "Doble avance en cacería y dummy", Colors.purpleAccent),
      ],
    );
  }

  Widget _eventItem(String title, String dates, Color col) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF151921), borderRadius: BorderRadius.circular(4), border: Border(left: BorderSide(color: col, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(dates, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

// Sparkline
class SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFB2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.cubicTo(size.width * 0.35, size.height * 0.1, size.width * 0.65, size.height * 0.9, size.width, size.height * 0.6);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Minimapa
class MinimapHousesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final housePaint = Paint()..color = const Color(0xFF8B4513)..style = PaintingStyle.fill;
    final wallPaint = Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.0;

    final houses = [
      Rect.fromLTWH(10, 10, 18, 18),
      Rect.fromLTWH(35, 12, 22, 16),
      Rect.fromLTWH(68, 16, 18, 20),
      Rect.fromLTWH(15, 38, 20, 18),
      Rect.fromLTWH(48, 40, 24, 20),
    ];

    for (var h in houses) {
      canvas.drawRect(h, housePaint);
      canvas.drawRect(h, wallPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
