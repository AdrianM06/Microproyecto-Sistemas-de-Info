import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(PuzzleApp(prefs: prefs));
}

// ==========================================
// MODELOS Y SERVICIO DE PERSISTENCIA
// ==========================================

enum AppThemeMode { light, dark }
enum TileStyle { classic, colorful, minimalist }

class GameScore {
  final int moves;
  final int seconds;
  final DateTime date;

  GameScore({required this.moves, required this.seconds, required this.date});

  Map<String, dynamic> toJson() => {
        'moves': moves,
        'seconds': seconds,
        'date': date.toIso8601String(),
      };

  factory GameScore.fromJson(Map<String, dynamic> json) => GameScore(
        moves: json['moves'],
        seconds: json['seconds'],
        date: DateTime.parse(json['date']),
      );
}

class StorageService {
  final SharedPreferences prefs;

  StorageService(this.prefs);

  static const String keyDifficulty = 'pref_difficulty';
  static const String keyTheme = 'pref_theme';
  static const String keyTileStyle = 'pref_tile_style';
  static const String keyScoresPrefix = 'high_scores_';

  int getDifficulty() => prefs.getInt(keyDifficulty) ?? 4;
  Future<void> setDifficulty(int size) => prefs.setInt(keyDifficulty, size);

  AppThemeMode getThemeMode() {
    final index = prefs.getInt(keyTheme) ?? AppThemeMode.light.index;
    if (index >= AppThemeMode.values.length) return AppThemeMode.light;
    return AppThemeMode.values[index];
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      prefs.setInt(keyTheme, mode.index);

  TileStyle getTileStyle() {
    final index = prefs.getInt(keyTileStyle) ?? TileStyle.classic.index;
    return TileStyle.values[index];
  }

  Future<void> setTileStyle(TileStyle style) =>
      prefs.setInt(keyTileStyle, style.index);

  List<GameScore> getScores(int gridSize) {
    final String? raw = prefs.getString('$keyScoresPrefix$gridSize');
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => GameScore.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveScore(int gridSize, GameScore newScore) async {
    final scores = getScores(gridSize);
    bool isNewRecord = false;

    if (scores.isEmpty ||
        newScore.seconds < scores.first.seconds ||
        (newScore.seconds == scores.first.seconds &&
            newScore.moves < scores.first.moves)) {
      isNewRecord = true;
    }

    scores.add(newScore);
    scores.sort((a, b) {
      int comp = a.seconds.compareTo(b.seconds);
      if (comp == 0) return a.moves.compareTo(b.moves);
      return comp;
    });

    final topScores = scores.take(10).toList();
    final jsonList = topScores.map((e) => e.toJson()).toList();
    await prefs.setString('$keyScoresPrefix$gridSize', jsonEncode(jsonList));

    return isNewRecord;
  }

  Future<void> clearScores() async {
    await prefs.remove('${keyScoresPrefix}3');
    await prefs.remove('${keyScoresPrefix}4');
    await prefs.remove('${keyScoresPrefix}5');
  }
}

// ==========================================
// APLICACIÓN PRINCIPAL CON ESTADO DE TEMA
// ==========================================

class PuzzleApp extends StatefulWidget {
  final SharedPreferences prefs;
  const PuzzleApp({super.key, required this.prefs});

  static PuzzleAppState of(BuildContext context) =>
      context.findAncestorStateOfType<PuzzleAppState>()!;

  @override
  State<PuzzleApp> createState() => PuzzleAppState();
}

class PuzzleAppState extends State<PuzzleApp> {
  late StorageService storage;
  late AppThemeMode themeMode;
  late TileStyle tileStyle;
  late int difficulty;

  @override
  void initState() {
    super.initState();
    storage = StorageService(widget.prefs);
    themeMode = storage.getThemeMode();
    tileStyle = storage.getTileStyle();
    difficulty = storage.getDifficulty();
  }

  void updateSettings(
      {AppThemeMode? newTheme, TileStyle? newStyle, int? newDifficulty}) {
    setState(() {
      if (newTheme != null) {
        themeMode = newTheme;
        storage.setThemeMode(newTheme);
      }
      if (newStyle != null) {
        tileStyle = newStyle;
        storage.setTileStyle(newStyle);
      }
      if (newDifficulty != null) {
        difficulty = newDifficulty;
        storage.setDifficulty(newDifficulty);
      }
    });
  }

  ThemeMode _getMaterialThemeMode() {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '15-Puzzle Flutter',
      debugShowCheckedModeBanner: false,
      themeMode: _getMaterialThemeMode(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 1. PANTALLA SPLASH
// ==========================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _navigationTimer = Timer(const Duration(seconds: 3), () {
      _goToMenu();
    });
  }

  void _goToMenu() {
    _navigationTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const MainMenuScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.extension_rounded,
                        size: 80,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '15-Puzzle Flutter',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rompecabezas Deslizante',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _goToMenu,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
              ),
              child: const Text('Saltar'),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. MENÚ PRINCIPAL
// ==========================================

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.grid_on_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '15-Puzzle',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                _MenuButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'JUGAR',
                  color: theme.colorScheme.primary,
                  textColor: theme.colorScheme.onPrimary,
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  icon: Icons.emoji_events_rounded,
                  label: 'MARCADORES',
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  icon: Icons.settings_rounded,
                  label: 'CONFIGURACIÓN',
                  color: theme.colorScheme.surfaceContainerHighest,
                  textColor: theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  icon: Icons.help_outline_rounded,
                  label: 'CÓMO JUGAR',
                  color: theme.colorScheme.surfaceContainerHighest,
                  textColor: theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InstructionsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.textColor),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. PANTALLA DE CONFIGURACIÓN
// ==========================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = PuzzleApp.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Dificultad del Tablero',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 3, label: Text('Fácil\n(3x3)'), icon: Icon(Icons.grid_3x3)),
              ButtonSegment(
                  value: 4, label: Text('Medio\n(4x4)'), icon: Icon(Icons.grid_4x4)),
              ButtonSegment(
                  value: 5, label: Text('Difícil\n(5x5)'), icon: Icon(Icons.grid_on)),
            ],
            selected: {appState.difficulty},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                appState.updateSettings(newDifficulty: newSelection.first);
              });
            },
          ),
          const Divider(height: 40),
          Text(
            'Tema Visual',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          RadioListTile<AppThemeMode>(
            title: const Text('Modo Claro'),
            secondary: const Icon(Icons.light_mode_rounded),
            value: AppThemeMode.light,
            groupValue: appState.themeMode,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  appState.updateSettings(newTheme: val);
                });
              }
            },
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Modo Oscuro'),
            secondary: const Icon(Icons.dark_mode_rounded),
            value: AppThemeMode.dark,
            groupValue: appState.themeMode,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  appState.updateSettings(newTheme: val);
                });
              }
            },
          ),
          const Divider(height: 40),
          Text(
            'Estilo de Fichas',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          RadioListTile<TileStyle>(
            title: const Text('Numérico Clásico'),
            subtitle: const Text('Diseño estándar y elegante'),
            value: TileStyle.classic,
            groupValue: appState.tileStyle,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  appState.updateSettings(newStyle: val);
                });
              }
            },
          ),
          RadioListTile<TileStyle>(
            title: const Text('Colorido'),
            subtitle: const Text('Gradiente de colores dinámico por ficha'),
            value: TileStyle.colorful,
            groupValue: appState.tileStyle,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  appState.updateSettings(newStyle: val);
                });
              }
            },
          ),
          RadioListTile<TileStyle>(
            title: const Text('Minimalista'),
            subtitle: const Text('Bordes limpios y tipografía sobria'),
            value: TileStyle.minimalist,
            groupValue: appState.tileStyle,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  appState.updateSettings(newStyle: val);
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. PANTALLA DE INSTRUCCIONES
// ==========================================

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cómo Jugar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InstructionStep(
              number: '1',
              title: 'Objetivo del Juego',
              description:
                  'Ordena todas las fichas en orden numérico ascendente (de izquierda a derecha y de arriba hacia abajo), dejando el espacio vacío en la esquina inferior derecha.',
            ),
            const SizedBox(height: 20),
            const _InstructionStep(
              number: '2',
              title: 'Mecánica de Movimiento',
              description:
                  'Toca o haz clic en cualquier ficha contigua (horizontal o verticalmente) al espacio vacío para deslizarla hacia ese espacio libre.',
            ),
            const SizedBox(height: 20),
            const _InstructionStep(
              number: '3',
              title: 'Cronómetro y Récords',
              description:
                  'El cronómetro se iniciará en el momento exacto en que realices tu primer movimiento. ¡Intenta resolver el rompecabezas en el menor tiempo y número de movimientos posible!',
            ),
            const SizedBox(height: 32),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded,
                        color: theme.colorScheme.primary, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Garantía Solvitable: Todos los tableros generados son matemáticamente resolubles mediante algoritmos de paridad.',
                        style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _InstructionStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            number,
            style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
