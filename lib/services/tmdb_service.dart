import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/tv_show.dart';

class TMDBService {
  static const String _apiKey = '279e039eafd4ccc7c289a589c9b613e3';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String _imageOriginalUrl = 'https://image.tmdb.org/t/p/original';

  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBaseUrl$path';
  }

  static String getOriginalImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$_imageOriginalUrl$path';
  }

  Future<List<Movie>> getTrendingMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/movie/week?api_key=$_apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => Movie.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar filmes em alta');
  }

  Future<List<Movie>> getPopularMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => Movie.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar filmes populares');
  }

  Future<List<Movie>> getTopRatedMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/top_rated?api_key=$_apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => Movie.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar filmes mais bem avaliados');
  }

  Future<List<TVShow>> getTrendingTVShows() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/tv/week?api_key=$_apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => TVShow.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar séries em alta');
  }

  Future<List<TVShow>> getPopularTVShows() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/popular?api_key=$_apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => TVShow.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar séries populares');
  }

  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId?api_key=$_apiKey&language=pt-BR&append_to_response=credits,videos,similar'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Falha ao carregar detalhes do filme');
  }

  Future<Map<String, dynamic>> getTVShowDetails(int tvShowId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tvShowId?api_key=$_apiKey&language=pt-BR&append_to_response=credits,videos,similar'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Falha ao carregar detalhes da série');
  }

  Future<Map<String, dynamic>> getSeasonDetails(int tvShowId, int seasonNumber) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tvShowId/season/$seasonNumber?api_key=$_apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Falha ao carregar detalhes da temporada');
  }
}
