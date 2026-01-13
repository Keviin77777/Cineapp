import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WatchProgress {
  final int contentId;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int positionMs; // Posição em milissegundos
  final int durationMs; // Duração total em milissegundos
  final String type; // 'movie' ou 'tv'
  final int? seasonNumber;
  final int? episodeNumber;
  final DateTime lastWatched;

  WatchProgress({
    required this.contentId,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.positionMs,
    required this.durationMs,
    required this.type,
    this.seasonNumber,
    this.episodeNumber,
    required this.lastWatched,
  });

  double get progress => durationMs > 0 ? positionMs / durationMs : 0.0;
  
  String get formattedPosition {
    final duration = Duration(milliseconds: positionMs);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}min';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final duration = Duration(milliseconds: durationMs);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}min';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'title': title,
    'posterPath': posterPath,
    'backdropPath': backdropPath,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'type': type,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'lastWatched': lastWatched.toIso8601String(),
  };

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
    contentId: json['contentId'],
    title: json['title'],
    posterPath: json['posterPath'],
    backdropPath: json['backdropPath'],
    positionMs: json['positionMs'],
    durationMs: json['durationMs'],
    type: json['type'],
    seasonNumber: json['seasonNumber'],
    episodeNumber: json['episodeNumber'],
    lastWatched: DateTime.parse(json['lastWatched']),
  );
}

class WatchProgressService {
  static const String _key = 'watch_progress';

  // Salvar progresso
  Future<void> saveProgress(WatchProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    
    // Remove entrada antiga do mesmo conteúdo
    list.removeWhere((p) => p.contentId == progress.contentId && 
        p.seasonNumber == progress.seasonNumber && 
        p.episodeNumber == progress.episodeNumber);
    
    // Só salva se assistiu mais de 5% e menos de 95%
    if (progress.progress > 0.05 && progress.progress < 0.95) {
      list.insert(0, progress);
    }
    
    // Mantém apenas os últimos 20
    if (list.length > 20) {
      list.removeRange(20, list.length);
    }
    
    await prefs.setString(_key, jsonEncode(list.map((p) => p.toJson()).toList()));
  }

  // Buscar todos os progressos
  Future<List<WatchProgress>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    
    final List decoded = jsonDecode(json);
    return decoded.map((item) => WatchProgress.fromJson(item)).toList();
  }

  // Buscar progresso de um conteúdo específico
  Future<WatchProgress?> getProgress(int contentId, {int? seasonNumber, int? episodeNumber}) async {
    final list = await getAll();
    try {
      return list.firstWhere((p) => 
        p.contentId == contentId && 
        p.seasonNumber == seasonNumber && 
        p.episodeNumber == episodeNumber
      );
    } catch (e) {
      return null;
    }
  }

  // Remover progresso (quando terminar de assistir)
  Future<void> removeProgress(int contentId, {int? seasonNumber, int? episodeNumber}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    
    list.removeWhere((p) => 
      p.contentId == contentId && 
      p.seasonNumber == seasonNumber && 
      p.episodeNumber == episodeNumber
    );
    
    await prefs.setString(_key, jsonEncode(list.map((p) => p.toJson()).toList()));
  }

  // Buscar último progresso de uma série (qualquer episódio)
  Future<WatchProgress?> getLastTVShowProgress(int contentId) async {
    final list = await getAll();
    try {
      // Retorna o mais recente (já está ordenado por lastWatched)
      return list.firstWhere((p) => p.contentId == contentId && p.type == 'tv');
    } catch (e) {
      return null;
    }
  }

  // Buscar progresso de um episódio específico
  Future<WatchProgress?> getEpisodeProgress(int contentId, int seasonNumber, int episodeNumber) async {
    final list = await getAll();
    try {
      return list.firstWhere((p) => 
        p.contentId == contentId && 
        p.seasonNumber == seasonNumber && 
        p.episodeNumber == episodeNumber
      );
    } catch (e) {
      return null;
    }
  }

  // Buscar lista para exibição na Home (apenas 1 card por série, mostrando o último episódio)
  Future<List<WatchProgress>> getForHomeDisplay() async {
    final list = await getAll();
    final Map<int, WatchProgress> uniqueByContent = {};
    
    for (final p in list) {
      // Se ainda não tem esse contentId, ou se é mais recente, adiciona
      if (!uniqueByContent.containsKey(p.contentId)) {
        uniqueByContent[p.contentId] = p;
      }
    }
    
    // Retorna ordenado por lastWatched (mais recente primeiro)
    final result = uniqueByContent.values.toList();
    result.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    return result;
  }
}
