import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/tv_show.dart';

class BaserowService {
  static const String _baseUrl = 'https://api.baserow.io/api/database/rows/table';
  static const String _token = 'QmAfq5k4dgeBb9WOwCE8qWxhmPSkookG';
  
  // IDs das tabelas
  static const int _moviesTableId = 426110;
  static const int _categoriesTableId = 426934;
  static const int _episodesTableId = 443422;

  static Map<String, String> get _headers => {
    'Authorization': 'Token $_token',
    'Content-Type': 'application/json',
  };

  // Buscar filmes em alta (ordenados por IMDB)
  Future<List<Movie>> getTrendingMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Imdb&filter__Tipo__equal=Filmes&size=20'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro getTrendingMovies: $e');
      return [];
    }
  }

  // Buscar filmes populares (ordenados por Views)
  Future<List<Movie>> getPopularMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Views&filter__Tipo__equal=Filmes&size=20'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro getPopularMovies: $e');
      return [];
    }
  }

  // Top 10 filmes por Views
  Future<List<Movie>> getTop10Movies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Views&filter__Tipo__equal=Filmes&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro getTop10Movies: $e');
      return [];
    }
  }

  // Top 10 séries por Views
  Future<List<TVShow>> getTop10TVShows() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Views&filter__Tipo__equal=Series&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro getTop10TVShows: $e');
      return [];
    }
  }

  // Séries em alta (ordenadas por IMDB)
  Future<List<TVShow>> getTrendingTVShows() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Imdb&filter__Tipo__equal=Series&size=20'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro getTrendingTVShows: $e');
      return [];
    }
  }

  // Detalhes de um filme
  Future<Movie?> getMovieDetails(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/$movieId/?user_field_names=true'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _convertToMovie(data);
      }
      return null;
    } catch (e) {
      print('Erro getMovieDetails: $e');
      return null;
    }
  }

  // Detalhes de uma série
  Future<TVShow?> getTVShowDetails(int tvShowId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/$tvShowId/?user_field_names=true'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _convertToTVShow(data);
      }
      return null;
    } catch (e) {
      print('Erro getTVShowDetails: $e');
      return null;
    }
  }

  // Episódios de uma série
  Future<List<Map<String, dynamic>>> getEpisodes(int seriesId) async {
    try {
      // Buscar todos os episódios da série (não filtrar por temporada aqui)
      final response = await http.get(
        Uri.parse('$_baseUrl/$_episodesTableId/?user_field_names=true&size=100'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        // Filtrar episódios que pertencem à série (pelo nome da série)
        final seriesName = await _getSeriesName(seriesId);
        final filteredResults = results.where((item) {
          final episodeName = item['Nome']?.toString() ?? '';
          return episodeName.toLowerCase().contains(seriesName.toLowerCase());
        }).toList();
        
        return filteredResults.map((item) => {
          'id': _parseInt(item['id']),
          'nome': item['Nome'] ?? '',
          'link': item['Link'] ?? '',
          'temporada': _parseInt(item['Temporada']),
          'episodio': _parseInt(item['Episodio']),
          'data': item['Data'] ?? '',
        }).toList();
      }
      return [];
    } catch (e) {
      print('Erro getEpisodes: $e');
      return [];
    }
  }

  // Helper para pegar o nome da série
  Future<String> _getSeriesName(int seriesId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/$seriesId/?user_field_names=true'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Nome'] ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // Categorias
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_categoriesTableId/?user_field_names=true'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => {
          'id': _parseInt(item['id']),
          'nome': item['Nome'] ?? '',
        }).toList();
      }
      return [];
    } catch (e) {
      print('Erro getCategories: $e');
      return [];
    }
  }

  // Converter para Movie
  Movie _convertToMovie(Map<String, dynamic> item) {
    // Processar categorias - tentar ambos os nomes de campo (singular e plural)
    String categoriesStr = '';
    final rawCategories = item['Categoria'] ?? item['Categorias'];
    if (rawCategories != null) {
      if (rawCategories is List) {
        categoriesStr = rawCategories.map((c) {
          if (c is Map) {
            return c['value'] ?? c['Nome'] ?? c.toString();
          }
          return c.toString();
        }).join(', ');
      } else if (rawCategories is String) {
        categoriesStr = rawCategories;
      } else {
        categoriesStr = rawCategories.toString();
      }
    }

    // Pegar título e garantir formatação correta
    final rawTitle = item['Nome Formatado'] ?? item['Nome'] ?? '';
    final title = _formatTitle(rawTitle);
    
    return Movie(
      id: _parseInt(item['id']),
      title: title,
      overview: item['Sinopse'] ?? '',
      posterPath: item['Capa'] ?? '',
      backdropPath: item['Capa de fundo'] ?? item['Capa'] ?? '',
      releaseDate: _formatDate(item['Data de Lançamento']),
      voteAverage: _parseDouble(item['Imdb']),
      genreIds: _parseGenres(rawCategories),
      streamUrl: item['Link'] ?? '',
      duration: item['Duração']?.toString() ?? '',
      views: _parseInt(item['Views']),
      tmdbId: _parseInt(item['UID']),
      categories: categoriesStr,
    );
  }

  // Converter para TVShow
  TVShow _convertToTVShow(Map<String, dynamic> item) {
    // Processar categorias - tentar ambos os nomes de campo (singular e plural)
    String categoriesStr = '';
    final rawCategories = item['Categoria'] ?? item['Categorias'];
    if (rawCategories != null) {
      if (rawCategories is List) {
        categoriesStr = rawCategories.map((c) {
          if (c is Map) {
            return c['value'] ?? c['Nome'] ?? c.toString();
          }
          return c.toString();
        }).join(', ');
      } else if (rawCategories is String) {
        categoriesStr = rawCategories;
      } else {
        categoriesStr = rawCategories.toString();
      }
    }

    // Pegar nome e garantir formatação correta
    final rawName = item['Nome Formatado'] ?? item['Nome'] ?? '';
    final name = _formatTitle(rawName);
    
    return TVShow(
      id: _parseInt(item['id']),
      name: name,
      overview: item['Sinopse'] ?? '',
      posterPath: item['Capa'] ?? '',
      backdropPath: item['Capa de fundo'] ?? item['Capa'] ?? '',
      firstAirDate: _formatDate(item['Data de Lançamento']),
      voteAverage: _parseDouble(item['Imdb']),
      genreIds: _parseGenres(rawCategories),
      streamUrl: item['Link'] ?? '',
      seasons: _parseInt(item['Temporadas']),
      views: _parseInt(item['Views']),
      tmdbId: _parseInt(item['UID']),
      categories: categoriesStr,
    );
  }

  // Helpers
  
  // Formatar título - capitaliza primeira letra de cada palavra
  String _formatTitle(String title) {
    if (title.isEmpty) return title;
    return title.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Manter números e palavras pequenas como estão
      if (word.length <= 2 && !RegExp(r'^[A-Za-zÀ-ÿ]').hasMatch(word)) {
        return word;
      }
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return '';
    final str = date.toString();
    if (str.contains('-') && str.length >= 10) return str.substring(0, 10);
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length >= 3) {
        return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
    }
    return str;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<int> _parseGenres(dynamic genres) {
    if (genres == null) return [];
    if (genres is String) {
      return genres.split(',').map((g) => g.trim().hashCode).toList();
    }
    return [];
  }

  // Buscar detalhes do TMDB usando UID (com idioma português)
  Future<Map<String, dynamic>?> getTMDBDetails(int tmdbId, String type) async {
    try {
      const apiKey = '279e039eafd4ccc7c289a589c9b613e3';
      final url = type == 'movie' 
          ? 'https://api.themoviedb.org/3/movie/$tmdbId?api_key=$apiKey&language=pt-BR&append_to_response=credits,similar'
          : 'https://api.themoviedb.org/3/tv/$tmdbId?api_key=$apiKey&language=pt-BR&append_to_response=credits,similar';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('Erro ao buscar dados TMDB: $e');
      return null;
    }
  }

  // Buscar episódios de uma temporada do TMDB
  Future<List<Map<String, dynamic>>> getTMDBSeasonEpisodes(int tmdbId, int seasonNumber) async {
    try {
      const apiKey = '279e039eafd4ccc7c289a589c9b613e3';
      final url = 'https://api.themoviedb.org/3/tv/$tmdbId/season/$seasonNumber?api_key=$apiKey&language=pt-BR';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final episodes = data['episodes'] as List? ?? [];
        
        return episodes.map((ep) => {
          'episode_number': ep['episode_number'],
          'name': ep['name'],
          'overview': ep['overview'],
          'still_path': ep['still_path'],
          'air_date': ep['air_date'],
          'runtime': ep['runtime'],
        }).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar episódios TMDB: $e');
      return [];
    }
  }

  // Buscar detalhes completos (Baserow + TMDB)
  Future<Movie?> getEnhancedMovieDetails(int movieId) async {
    try {
      // Primeiro busca dados do Baserow
      final baserowMovie = await getMovieDetails(movieId);
      if (baserowMovie == null) return null;

      // Se tem UID do TMDB, busca dados complementares
      if (baserowMovie.tmdbId != null && baserowMovie.tmdbId! > 0) {
        final tmdbData = await getTMDBDetails(baserowMovie.tmdbId!, 'movie');
        if (tmdbData != null) {
          // Combina dados do Baserow com TMDB
          return Movie(
            id: baserowMovie.id,
            title: tmdbData['title'] ?? baserowMovie.title, // Prioriza título do TMDB
            overview: tmdbData['overview'] ?? baserowMovie.overview, // Prioriza sinopse do TMDB
            posterPath: tmdbData['poster_path'] ?? baserowMovie.posterPath, // Prioriza poster do TMDB
            backdropPath: tmdbData['backdrop_path'] ?? baserowMovie.backdropPath, // Prioriza backdrop do TMDB
            releaseDate: tmdbData['release_date'] ?? baserowMovie.releaseDate,
            voteAverage: (tmdbData['vote_average'] ?? baserowMovie.voteAverage).toDouble(),
            genreIds: baserowMovie.genreIds,
            streamUrl: baserowMovie.streamUrl,
            duration: baserowMovie.duration,
            views: baserowMovie.views,
            tmdbId: baserowMovie.tmdbId,
            categories: baserowMovie.categories,
          );
        }
      }

      return baserowMovie;
    } catch (e) {
      print('Erro getEnhancedMovieDetails: $e');
      return null;
    }
  }

  // Buscar séries relacionadas usando dados do TMDB
  Future<List<Movie>> getTMDBSimilarMovies(int tmdbId, int excludeId) async {
    try {
      final tmdbData = await getTMDBDetails(tmdbId, 'movie');
      if (tmdbData != null) {
        final similar = tmdbData['similar'] as Map<String, dynamic>?;
        final results = similar?['results'] as List? ?? [];
        
        final movies = <Movie>[];
        for (final item in results.take(10)) {
          final tmdbMovie = Movie(
            id: item['id'] ?? 0,
            title: item['title'] ?? '',
            overview: item['overview'] ?? '',
            posterPath: item['poster_path'],
            backdropPath: item['backdrop_path'],
            releaseDate: item['release_date'] ?? '',
            voteAverage: (item['vote_average'] ?? 0).toDouble(),
            genreIds: List<int>.from(item['genre_ids'] ?? []),
            streamUrl: null,
            duration: null,
            views: null,
            tmdbId: item['id'],
            categories: null,
          );
          movies.add(tmdbMovie);
        }
        return movies;
      }
      return [];
    } catch (e) {
      print('Erro getTMDBSimilarMovies: $e');
      return [];
    }
  }
  Future<List<Movie>> getRelatedMovies(String category, int excludeId) async {
    try {
      // Se tem categoria, busca apenas pela primeira
      if (category.isNotEmpty) {
        final firstCategory = category.split(',').first.trim();
        
        final url = '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$firstCategory&filter__Tipo__equal=Filmes&size=15';
        
        final response = await http.get(Uri.parse(url), headers: _headers);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List results = data['results'] ?? [];
          
          final movies = results
              .where((item) => _parseInt(item['id']) != excludeId)
              .map((item) => _convertToMovie(item))
              .take(10)
              .toList();
          
          if (movies.isNotEmpty) {
            return movies;
          }
        }
      }
      
      // Fallback: filmes populares do Baserow
      final popularMovies = await getPopularMovies();
      return popularMovies.where((m) => m.id != excludeId).take(10).toList();
    } catch (e) {
      try {
        final popularMovies = await getPopularMovies();
        return popularMovies.where((m) => m.id != excludeId).take(10).toList();
      } catch (e2) {
        return [];
      }
    }
  }

  // Buscar séries relacionadas por categoria
  Future<List<TVShow>> getRelatedTVShows(String category, int excludeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categorias__contains=$category&filter__Tipo__equal=Series&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        // Filtrar a série atual
        final filtered = results.where((item) => _parseInt(item['id']) != excludeId).toList();
        return filtered.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro getRelatedTVShows: $e');
      return [];
    }
  }
  // URL da imagem (prioriza TMDB com melhor qualidade)
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/500x750/1F1D2B/FFFFFF?text=Sem+Imagem';
    }
    
    // Se já é uma URL completa, retorna como está
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    
    // Se é um path do TMDB (começa com /), adiciona a base URL do TMDB com melhor qualidade
    if (imagePath.startsWith('/')) {
      return 'https://image.tmdb.org/t/p/w780$imagePath'; // Melhor qualidade
    }
    
    return imagePath;
  }
}