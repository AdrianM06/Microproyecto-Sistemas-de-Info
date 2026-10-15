import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(PuzzleApp(prefs: prefs));
}

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
      home: const Scaffold(body: Center(child: Text('15-Puzzle Base'))),
    );
  }
}
