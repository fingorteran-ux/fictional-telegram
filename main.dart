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
// AUDIO TÁCTICO
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
// HELPER: MINIMAPAS REALES DE CADA CIUDAD DE TIBIA
// -------------------------------------------------------------
String getCityMinimapUrl(String city) {
  final clean = city.trim().toLowerCase();
  if (clean.contains('thais')) {
    return 'https://www.tibiawiki.com.br/images/f/f4/Map_thais.jpg';
  } else if (clean.contains('venore')) {
    return 'https://www.tibiawiki.com.br/images/b/b4/Map_venore.jpg';
  } else if (clean.contains('darashia') || clean.contains('darach')) {
    return 'https://www.tibiawiki.com.br/images/7/75/Map_darashia.jpg';
  } else if (clean.contains('carlin')) {
    return 'https://www.tibiawiki.com.br/images/c/c2/Map_Carlin.jpg';
  } else if (clean.contains('edron')) {
    return 'https://www.tibiawiki.com.br/images/b/be/Map_edron.jpg';
  } else if (clean.contains('ankrahmun')) {
    return 'https://www.tibiawiki.com.br/images/9/9d/Map_Ankrahmun.png';
  } else if (clean.contains('svargrond')) {
    return 'https://www.tibiawiki.com.br/images/1/1a/Map_Svargrond.jpg';
  } else if (clean.contains('port hope')) {
    return 'https://www.tibiawiki.com.br/images/5/52/Map_Port_Hope.jpg';
  } else if (clean.contains('kazordoon')) {
    return 'https://www.tibiawiki.com.br/images/e/e0/Map_Kazordoon.jpg';
  } else if (clean.contains('yalahar')) {
    return 'https://www.tibiawiki.com.br/images/4/43/Map_yalahar.jpg';
  } else if (clean.contains('liberty bay')) {
    return 'https://www.tibiawiki.com.br/images/0/05/Map_liberty_bay.jpg';
  } else if (clean.contains('ab\'dendriel')) {
    return 'https://www.tibiawiki.com.br/images/8/87/Map_ab%27dendriel.jpg';
  }
  return 'https://www.tibiawiki.com.br/images/f/f4/Map_thais.jpg';
}

// -------------------------------------------------------------
// APP ROOT
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
        scaffoldBackgroundColor: const Color(0xFF111418),
        primaryColor: const Color(0xFF00FFB2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C0E12),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
// CONTENEDOR CON DRAWER LATERAL
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
        title: Text(_titles[_selectedDrawerIndex]),
        actions: [
          IconButton(
            icon: Icon(TacticalAudio.soundEnabled ? Icons.volume_up : Icons.volume_off, color: TacticalAudio.soundEnabled ? const Color(0xFF00FFB2) : Colors.grey),
            onPressed: () => setState(() => TacticalAudio.soundEnabled = !TacticalAudio.soundEnabled),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF14171E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0C0E12),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: const Color(0xFF00FFB2).withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.shield, color: Color(0xFF00FFB2), size: 26),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SPY FEROBRA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          Text("VIGILANCIA DE WAR // PRO", style: TextStyle(color: Color(0xFF00FFB2), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("Alertas de muerte por voz y rastreo sin límites", style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            _drawerTile(0, Icons.home, "Inicio"),
            _drawerTile(1, Icons.public, "Mundos"),
            _drawerTile(2, Icons.calendar_today, "Eventos"),
            const Divider(color: Colors.white10, height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text("UTILIDADES", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
            _drawerTile(3, Icons.group_add, "Compartir Experiencia"),
            _drawerTile(4, Icons.security, "Blessings y Penalización"),
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
// PANTALLA PRINCIPAL: HOME
// -------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.tactical.tibia/radar');

  List<TrackTarget> targets = [];

  final TextEditingController _nameController = TextEditingController();
  String currentFilter = 'TODOS';

  int globalPlayersOnline = 15330;
  Map<String, dynamic> onlinePlayersData = {};
  Map<String, Map<String, dynamic>> characterFullData = {};

  Map<String, int> loginTimestamps = {};
  Map<String, int> logoutTimestamps = {};

  Map<String, bool> muteLoginMap = {};
  Map<String, bool> muteLogoutMap = {};
  Map<String, bool> muteDeathMap = {};
  Map<String, String> characterNotes = {};

  String boostedCreatureName = "Rustheap Golem";
  String boostedBossName = "The Diamond Blossom";

  Duration timeToSS = Duration.zero;

  bool isScanning = false;
  bool isAddingPlayer = false;
  Timer? _timer;
  Timer? _clockUpdater;

  @override
  void initState() {
    super.initState();
    initRadar();
    calculateTimeToSS();
    _clockUpdater = Timer.periodic(const Duration(seconds: 1), (_) {
      calculateTimeToSS();
      if (mounted) setState(() {});
    });
  }

  void calculateTimeToSS() {
    final nowUtc = DateTime.now().toUtc();
    var nextSS = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 8, 0, 0);
    if (nowUtc.isAfter(nextSS)) {
      nextSS = nextSS.add(const Duration(days: 1));
    }
    final diff = nextSS.difference(nowUtc);

    if (diff.inMinutes == 1439 && diff.inSeconds >= 55) {
      fetchBoostedData();
    }

    timeToSS = diff;
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
      muteDeathMap[key] = prefs.getBool('mute_death_$key') ?? false;
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
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
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
      await platform.invokeMethod('startRadarService');
      await platform.invokeMethod('syncTargets', {'json': jsonStr});
    } catch (_) {}
  }

  Future<void> fetchCharacterDetails(String charName) async {
    final key = charName.toLowerCase();
    try {
      final res = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(charName)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36'},
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
    if (worldsToScan.isEmpty) {
      setState(() => isScanning = false);
      return;
    }

    Map<String, dynamic> newOnlineMap = {};

    for (var w in worldsToScan) {
      try {
        final response = await http.get(
          Uri.parse('https://api.tibiadata.com/v4/world/$w'),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36'},
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

  void showIndividualNotificationsDialog(TrackTarget target) async {
    final key = target.name.toLowerCase();
    final prefs = await SharedPreferences.getInstance();

    bool notifLogin = !(prefs.getBool('mute_login_$key') ?? false);
    bool notifLogout = !(prefs.getBool('mute_logout_$key') ?? false);
    bool notifDeath = !(prefs.getBool('mute_death_$key') ?? false);
    bool notifLevel = true;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161A22),
          title: Text(
            "Notificaciones para ${target.name}",
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Notificaciones de login", style: TextStyle(fontSize: 13)),
                value: notifLogin,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => notifLogin = val),
              ),
              SwitchListTile(
                title: const Text("Notificaciones de logout", style: TextStyle(fontSize: 13)),
                value: notifLogout,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => notifLogout = val),
              ),
              SwitchListTile(
                title: const Text("Notificaciones de muerte", style: TextStyle(fontSize: 13)),
                value: notifDeath,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => notifDeath = val),
              ),
              SwitchListTile(
                title: const Text("Notificaciones de subida de nivel", style: TextStyle(fontSize: 13)),
                value: notifLevel,
                activeColor: const Color(0xFF00FFB2),
                onChanged: (val) => setDialogState(() => notifLevel = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black),
              onPressed: () async {
                await prefs.setBool('mute_login_$key', !notifLogin);
                await prefs.setBool('mute_logout_$key', !notifLogout);
                await prefs.setBool('mute_death_$key', !notifDeath);

                setState(() {
                  muteLoginMap[key] = !notifLogin;
                  muteLogoutMap[key] = !notifLogout;
                  muteDeathMap[key] = !notifDeath;
                });

                await syncNativeService();
                Navigator.pop(ctx);
              },
              child: const Text("ACEPTAR"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addTargetAuto(String type) async {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    if (targets.any((t) => t.name.toLowerCase() == text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Este personaje ya está en tu lista")),
      );
      return;
    }

    setState(() => isAddingPlayer = true);
    _nameController.clear();

    try {
      final res = await http.get(
        Uri.parse('https://api.tibiadata.com/v4/character/${Uri.encodeComponent(text)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final ch = data['character']?['character'];
        if (ch != null && ch['name'] != null) {
          final officialName = ch['name'].toString();
          final officialWorld = (ch['world'] ?? 'Ferobra').toString();

          final newT = TrackTarget(name: officialName, type: type, world: officialWorld);
          setState(() {
            targets.add(newT);
            characterFullData[officialName.toLowerCase()] = {
              'raw': ch,
              'deaths': data['character']?['deaths'] ?? [],
              'houses': data['character']?['houses'] ?? [],
              'guild': data['character']?['guild'] ?? {},
              'level': ch['level'] ?? 0,
              'vocation': ch['vocation'] ?? 'None',
              'residence': ch['town'] ?? 'Thais',
              'account_status': ch['account_status'] ?? 'Free Account',
              'last_login': ch['last_login'] ?? '',
            };
            isAddingPlayer = false;
          });

          await syncNativeService();
          scanAllWorlds();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("✅ Añadido: $officialName ($officialWorld)"),
                backgroundColor: const Color(0xFF00FFB2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}

    final fallbackTarget = TrackTarget(name: text, type: type, world: 'Ferobra');
    setState(() {
      targets.add(fallbackTarget);
      isAddingPlayer = false;
    });
    await syncNativeService();
    scanAllWorlds();
  }

  void removeTarget(String name) {
    setState(() {
      targets.removeWhere((t) => t.name.toLowerCase() == name.toLowerCase());
    });
    syncNativeService();
  }

  // TRICOLOR EXACTO: ARRIBA AMARILLO, MEDIO AZUL, ABAJO ROJO
  Widget _getVocationWalkingSprite(String? vocation, bool isOnline) {
    final voc = (vocation ?? '').toLowerCase();
    int looktype = 128;

    if (voc.contains('sorcerer')) {
      looktype = 130;
    } else if (voc.contains('knight')) {
      looktype = 131;
    } else if (voc.contains('paladin')) {
      looktype = 129;
    } else if (voc.contains('druid')) {
      looktype = 144;
    }

    // head=79 (Arriba Amarillo)
    // body=86 (En el medio Azul)
    // legs=94 (Debajo de último Rojo)
    // feet=94 (Rojo)
    final animUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=$looktype&addons=3&head=79&body=86&legs=94&feet=94&direction=3";

    return Opacity(
      opacity: isOnline ? 1.0 : 0.45,
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

  // BOSSES Y CRIATURAS EN MOVIMIENTO REAL (SIN BLOQUEOS)
  Widget _buildLiveAnimatedCreature(String creatureName) {
    final clean = creatureName
        .replaceAll(RegExp(r'^(a |an )', caseSensitive: false), '')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join('_');

    final unblockedUrl = "https://wsrv.nl/?url=tibia.fandom.com/wiki/Special:FilePath/$clean.gif&n=-1";

    return Image.network(
      unblockedUrl,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Image.network(
        "https://wsrv.nl/?url=tibia.fandom.com/wiki/Special:FilePath/Demon.gif&n=-1",
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.orangeAccent, size: 32),
      ),
    );
  }

  Map<String, String> getRashidData() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday: return {'city': 'Svargrond', 'map_url': 'https://www.tibiawiki.com.br/images/1/1a/Map_Svargrond.jpg'};
      case DateTime.tuesday: return {'city': 'Liberty Bay', 'map_url': 'https://www.tibiawiki.com.br/images/0/05/Map_liberty_bay.jpg'};
      case DateTime.wednesday: return {'city': 'Port Hope', 'map_url': 'https://www.tibiawiki.com.br/images/5/52/Map_Port_Hope.jpg'};
      case DateTime.thursday: return {'city': 'Ankrahmun', 'map_url': 'https://www.tibiawiki.com.br/images/9/9d/Map_Ankrahmun.png'};
      case DateTime.friday: return {'city': 'Darashia', 'map_url': 'https://www.tibiawiki.com.br/images/7/75/Map_darashia.jpg'};
      case DateTime.saturday: return {'city': 'Edron', 'map_url': 'https://www.tibiawiki.com.br/images/b/be/Map_edron.jpg'};
      case DateTime.sunday: return {'city': 'Carlin', 'map_url': 'https://www.tibiawiki.com.br/images/c/c2/Map_Carlin.jpg'};
      default: return {'city': 'Darashia', 'map_url': 'https://www.tibiawiki.com.br/images/7/75/Map_darashia.jpg'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = filteredTargets;
    final rData = getRashidData();

    const rashidOriginalWalkingUrl = "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=146&addons=0&head=78&body=106&legs=58&feet=76&direction=3";

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Noticia superior
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF161B24),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.feed, size: 13, color: Color(0xFF00FFB2)),
                  SizedBox(width: 5),
                  Text("NOTICIA OFICIAL DE CIPSOFT", style: TextStyle(color: Color(0xFF00FFB2), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 3),
              Text("New Optional and Open PvP Game Worlds", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text("Servidores en línea disponibles para pruebas y feedback.", style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),

        // Jugadores Online
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF0F1318),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Jugadores online", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    globalPlayersOnline.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
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

        // Buscador universal
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF171B24), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Escribe cualquier personaje...",
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00FFB2), size: 20),
                        suffixIcon: isAddingPlayer
                            ? const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFB2))),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 8)),
                            onPressed: isAddingPlayer ? null : () => addTargetAuto('amigo'),
                            child: const Text("🛡️ + AMIGO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                            onPressed: isAddingPlayer ? null : () => addTargetAuto('enemigo'),
                            child: const Text("⚔️ + ENEMIGO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("VIGILANCIA (${targets.length}) // SIN LÍMITES", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 11, fontWeight: FontWeight.bold)),
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

        // Lista de Personajes
        if (displayList.isEmpty)
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(4)),
            child: const Center(
              child: Text(
                "Sin objetivos en vigilancia.\nEscribe el nombre de tu amigo o enemigo arriba para agregarlo.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          )
        else
          ...displayList.map((target) {
            final key = target.name.toLowerCase();
            final isOnline = onlinePlayersData.containsKey(key);
            final full = characterFullData[key] ?? {};
            final level = isOnline ? (onlinePlayersData[key]['level'] ?? 0) : (full['level'] ?? 0);
            final vocation = isOnline ? (onlinePlayersData[key]['vocation'] ?? '') : (full['vocation'] ?? 'Cargando...');

            final bottomLineColor = target.type == 'enemigo'
                ? const Color(0xFFFF5252)
                : (isOnline ? const Color(0xFF4CAF50) : const Color(0xFF232B38));

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(4),
                border: Border(bottom: BorderSide(color: bottomLineColor, width: 3.5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                onLongPress: () => showIndividualNotificationsDialog(target),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CharacterDetailScreen(
                        target: target,
                        fullData: full,
                        isOnline: isOnline,
                        onlineData: onlinePlayersData[key],
                        onNotificationConfigure: () => showIndividualNotificationsDialog(target),
                      ),
                    ),
                  );
                },
                leading: _getVocationWalkingSprite(vocation, isOnline),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(target.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isOnline ? Colors.white : Colors.white70)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF202735), borderRadius: BorderRadius.circular(3)),
                      child: Text(target.world, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                subtitle: Text(
                  "Nivel $level – $vocation",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white54, size: 20),
                      onPressed: () => showIndividualNotificationsDialog(target),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                      onPressed: () => removeTarget(target.name),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 12),

        // Boosted Creature & Boss animados en vivo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
                  child: Column(
                    children: [
                      const Text("Boosted Creature", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 52,
                        child: _buildLiveAnimatedCreature(boostedCreatureName),
                      ),
                      const SizedBox(height: 6),
                      Text(boostedCreatureName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
                  child: Column(
                    children: [
                      const Text("Boosted Boss", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 52,
                        child: _buildLiveAnimatedCreature(boostedBossName),
                      ),
                      const SizedBox(height: 6),
                      Text(boostedBossName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Tarjeta de Rashid Compacta
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                color: const Color(0xFF0F1218),
                child: const Text("Todos los mundos", style: TextStyle(color: Colors.white70, fontSize: 11)),
              ),
              SizedBox(
                height: 80,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(child: Container(color: const Color(0xFF264C8A))),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 140,
                      child: ClipRRect(
                        child: Image.network(
                          rData['map_url']!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.none,
                          headers: const {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36',
                          },
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFC7A762)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 25,
                      top: 12,
                      child: Image.network(
                        rashidOriginalWalkingUrl,
                        width: 55,
                        height: 55,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => const Text("🚶", style: TextStyle(fontSize: 26)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                color: const Color(0xFF1E3A6E),
                child: Text(
                  "Rashid esta en ${rData['city']}",
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _filterTab(String label) {
    final isSelected = currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => currentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFB2) : const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white60),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// PANTALLA DETALLE: MONSTRUOS ANIMADOS EN VEZ DE LA X
// -------------------------------------------------------------
class CharacterDetailScreen extends StatefulWidget {
  final TrackTarget target;
  final Map<String, dynamic> fullData;
  final bool isOnline;
  final dynamic onlineData;
  final VoidCallback onNotificationConfigure;

  const CharacterDetailScreen({
    super.key,
    required this.target,
    required this.fullData,
    required this.isOnline,
    this.onlineData,
    required this.onNotificationConfigure,
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
        backgroundColor: const Color(0xFF161A22),
        title: Text("Nota para ${widget.target.name}", style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 14)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(hintText: "Escribe una nota táctica...", hintStyle: TextStyle(color: Colors.white30)),
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

  // MONSTRUO ANIMADO EXACTO EN VEZ DE LA X
  Widget _buildDeathMonsterImage(String killerName) {
    final cleanName = killerName
        .replaceAll(RegExp(r'^(a |an )', caseSensitive: false), '')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join('_');

    final unblockedUrl = "https://wsrv.nl/?url=tibia.fandom.com/wiki/Special:FilePath/$cleanName.gif&n=-1";

    return Image.network(
      unblockedUrl,
      width: 48,
      height: 48,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Image.network(
        "https://wsrv.nl/?url=tibia.fandom.com/wiki/Special:FilePath/Demon.gif&n=-1",
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.orangeAccent, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.fullData['raw'] ?? {};
    final level = widget.isOnline ? (widget.onlineData?['level'] ?? widget.fullData['level'] ?? 0) : (widget.fullData['level'] ?? 0);
    final vocation = widget.isOnline ? (widget.onlineData?['vocation'] ?? widget.fullData['vocation'] ?? '') : (widget.fullData['vocation'] ?? '');
    final residence = raw['town'] ?? 'Thais';
    final accountStatus = raw['account_status'] ?? 'Premium Account';
    final deaths = (widget.fullData['deaths'] as List? ?? []);
    final guild = (widget.fullData['guild'] as Map? ?? {});

    return Scaffold(
      appBar: AppBar(
        title: const Text("Información del personaje", style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: widget.onNotificationConfigure,
          ),
          IconButton(icon: const Icon(Icons.edit_note), onPressed: editNoteDialog),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: "https://www.tibia.com/community/?subtopic=characters&name=${widget.target.name}"));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enlace copiado")));
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                Image.network(
                  "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=131&addons=3&head=79&body=86&legs=94&feet=94&direction=3",
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

          // Minimapa real de residencia
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF16253D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                getCityMinimapUrl(residence),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.none,
                headers: const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36',
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.location_city, color: Color(0xFF00FFB2), size: 36),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

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
              _infoTile("Estado de la cuenta", accountStatus),
              const SizedBox(width: 8),
              _infoTile("Estado", widget.isOnline ? "Online" : "Desconectado", isOnlineColor: widget.isOnline),
            ],
          ),
          const SizedBox(height: 10),

          if (note.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF151D2A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(Icons.note, color: Color(0xFF00FFB2), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Nota: $note", style: const TextStyle(color: Colors.white, fontSize: 12))),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // -------------------------------------------------------------
          // HISTORIAL DE MUERTES: CON MONSTRUO ANIMADO DONDE ANTES SALÍA LA X
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(4)),
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
                    final isPkMass = killers.any((k) => k['player'] == true);
                    final firstKillerName = killers.isNotEmpty ? (killers.first['name'] ?? 'Criatura') : 'Criatura';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF0F1218), borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${d['level']}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  const Text("NIVEL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPkMass
                                          ? "Muerto por: ${killers.length} jugadores"
                                          : "Muerto por: $firstKillerName",
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                              // AQUÍ SALÍA LA X -> AHORA SALE EL MONSTRUO ANIMADO REAL
                              if (!isPkMass)
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: _buildDeathMonsterImage(firstKillerName),
                                ),
                            ],
                          ),
                          if (isPkMass) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: killers.map((k) {
                                return SizedBox(
                                  width: 85,
                                  child: Column(
                                    children: [
                                      Image.network(
                                        "https://outfit-images.ots.me/1285_walk_animation/animoutfit.php?id=131&addons=3&head=79&body=86&legs=94&feet=94&direction=3",
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.redAccent, size: 28),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        k['name'] ?? 'PK',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "Nivel ${k['level'] ?? '?'}",
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
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
        decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(4)),
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
// PANTALLAS SECUNDARIAS
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
              Text("${w['players_online']} online", style: const TextStyle(color: Color(0xFF00FFB2), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

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

class BlessingsCalculatorScreen extends StatefulWidget {
  const BlessingsCalculatorScreen({super.key});

  @override
  State<BlessingsCalculatorScreen> createState() => _BlessingsCalculatorScreenState();
}

class _BlessingsCalculatorScreenState extends State<BlessingsCalculatorScreen> {
  final TextEditingController _levelCtrl = TextEditingController(text: "300");

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

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _eventItem("Annual Autumn Vintage", "En curso – Finaliza en 7 horas", Colors.amber),
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
