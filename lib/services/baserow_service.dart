import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/tv_show.dart';

class BaserowService {
  // Servidor Baserow próprio
  static const String _baseUrl = 'http://213.199.56.115/api/database/rows/table';
  static const String _fieldsUrl = 'http://213.199.56.115/api/database/fields';
  static const String _token = 'LR1atLkF7ZXGJyay195JMnwGWAlkjPIZ';
  
  // IDs das tabelas no servidor próprio
  static const int _usersTableId = 4931;        // Tabela Usuarios
  static const int _moviesTableId = 4932;       // Tabela Filmes & Series
  static const int _categoriesTableId = 4933;   // Tabela Categorias
  static const int _notificationsTableId = 4934; // Tabela Enviar Notificações
  static const int _episodesTableId = 4935;     // Tabela Episodios
  static const int _categoryLibraryTableId = 4997; // Tabela Categoria Biblioteca
  static const int _userDataTableId = 5051;     // Tabela Dados do Usuario (favoritos, minha lista, progresso)
  
  // ID do campo Categoria na tabela Filmes & Series
  static const int _categoryFieldId = 33147;

  static Map<String, String> get _headers => {
    'Authorization': 'Token $_token',
    'Content-Type': 'application/json',
  };

  // Incrementar visualizações de um filme/série
  Future<bool> incrementViews(int contentId) async {
    try {
      // Primeiro busca o valor atual de Views
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/$contentId/?user_field_names=true'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentViews = _parseInt(data['Views']);
        
        // Atualiza com o novo valor
        final updateResponse = await http.patch(
          Uri.parse('$_baseUrl/$_moviesTableId/$contentId/?user_field_names=true'),
          headers: _headers,
          body: json.encode({'Views': currentViews + 1}),
        );

        return updateResponse.statusCode == 200;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Buscar filmes em alta (ordenados por data de criação - mais recentes)
  Future<List<Movie>> getTrendingMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&filter__Tipo__equal=Filmes&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar últimos conteúdos adicionados (filmes e séries - mais recentes)
  Future<List<dynamic>> getLatestContent() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        // Converte para Movie ou TVShow baseado no tipo
        return results.map((item) {
          final tipo = item['Tipo']?.toString() ?? '';
          if (tipo == 'Séries') {
            return _convertToTVShow(item);
          } else {
            return _convertToMovie(item);
          }
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar filmes escolhidos para você (melhor rating e mais views)
  Future<List<Movie>> getPickedForYou() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Imdb,-Views&filter__Tipo__equal=Filmes&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar filmes populares (ordenados por data de criação - mais recentes)
  Future<List<Movie>> getPopularMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&filter__Tipo__equal=Filmes&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Top 10 filmes por Views (mais assistidos)
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
      return [];
    }
  }

  // Top 10 séries por Views (mais assistidas)
  Future<List<TVShow>> getTop10TVShows() async {
    try {
      // Tenta primeiro com "Series" sem acento
      var response = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Views&filter__Tipo__equal=Series&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => _convertToTVShow(item)).toList();
        }
      }

      // Fallback: tenta com "Séries" com acento
      response = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Views&filter__Tipo__equal=Séries&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Séries em alta (ordenadas por data de criação - mais recentes)
  Future<List<TVShow>> getTrendingTVShows() async {
    try {
      // Tenta primeiro com "Series" sem acento
      var response = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&filter__Tipo__equal=Series&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => _convertToTVShow(item)).toList();
        }
      }

      // Fallback: tenta com "Séries" com acento
      response = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&filter__Tipo__equal=Séries&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
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
      return null;
    }
  }

  // Episódios de uma série (paginação infinita)
  Future<List<Map<String, dynamic>>> getEpisodes(int seriesId) async {
    try {
      // Buscar o nome da série
      final seriesData = await _getSeriesData(seriesId);
      final seriesName = seriesData['name'] ?? '';
      
      if (seriesName.isEmpty) {
        return [];
      }
      
      // Buscar todos os episódios com paginação infinita
      List<dynamic> allResults = [];
      String? nextUrl = '$_baseUrl/$_episodesTableId/?user_field_names=true&size=200&filter__Nome__contains=$seriesName';
      
      while (nextUrl != null) {
        final response = await http.get(Uri.parse(nextUrl), headers: _headers);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List? ?? [];
          allResults.addAll(results);
          
          // Próxima página (null se não houver mais)
          nextUrl = data['next'] as String?;
        } else {
          break;
        }
      }
      
      // Se não encontrou com filtro, busca todos e filtra localmente
      if (allResults.isEmpty) {
        nextUrl = '$_baseUrl/$_episodesTableId/?user_field_names=true&size=200';
        
        while (nextUrl != null) {
          final response = await http.get(Uri.parse(nextUrl), headers: _headers);
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final results = data['results'] as List? ?? [];
            allResults.addAll(results);
            
            nextUrl = data['next'] as String?;
          } else {
            break;
          }
        }
        
        // Normalizar nome da série para comparação
        final seriesNameNormalized = _normalizeName(seriesName);
        
        // Filtrar episódios que pertencem à série
        allResults = allResults.where((item) {
          final episodeName = item['Nome']?.toString() ?? '';
          final episodeNameNormalized = _normalizeName(episodeName);
          
          // Match exato ou contém o nome da série
          return episodeNameNormalized == seriesNameNormalized ||
                 episodeNameNormalized.contains(seriesNameNormalized) ||
                 episodeNameNormalized.startsWith(seriesNameNormalized);
        }).toList();
      }
      
      if (allResults.isEmpty) {
        return [];
      }
      
      return allResults.map((item) => {
        'id': _parseInt(item['id']),
        'nome': item['Nome'] ?? '',
        'link': item['Link'] ?? '',
        'temporada': _parseInt(item['Temporada']),
        'episodio': _parseInt(item['Episódio']),
        'data': item['Data'] ?? '',
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Episódios de uma temporada específica
  Future<List<Map<String, dynamic>>> getEpisodesBySeason(int seriesId, int seasonNumber) async {
    try {
      // Buscar todos os episódios da série
      final allEpisodes = await getEpisodes(seriesId);
      
      // Filtrar pela temporada específica
      final seasonEpisodes = allEpisodes
          .where((ep) => ep['temporada'] == seasonNumber)
          .toList();
      
      // Ordenar por número do episódio
      seasonEpisodes.sort((a, b) => 
        (a['episodio'] as int).compareTo(b['episodio'] as int)
      );
      
      return seasonEpisodes;
    } catch (e) {
      return [];
    }
  }

  // Normalizar nome para comparação (remove acentos, espaços extras, lowercase)
  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')  // Remove espaços extras
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  // Helper para pegar o nome e UID da série
  Future<Map<String, dynamic>> _getSeriesData(int seriesId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/$seriesId/?user_field_names=true'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'name': data['Nome'] ?? '',
          'uid': data['UID'],
        };
      }
      return {'name': '', 'uid': null};
    } catch (e) {
      return {'name': '', 'uid': null};
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
      return [];
    }
  }

  // Buscar categorias da home
  Future<List<Map<String, dynamic>>> getHomeCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_categoriesTableId/?user_field_names=true&size=50'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => {
          'id': _parseInt(item['id']),
          'nome': item['Nome'] ?? '',
          'data': item['Data'] ?? '',
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar apenas categorias de séries (que começam com "Séries")
  Future<List<String>> getSeriesCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_categoriesTableId/?user_field_names=true&size=100'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final categories = <String>[];
        
        for (final item in results) {
          final nome = item['Nome'] as String? ?? '';
          // Pega TODAS as categorias que começam com "Séries"
          if (nome.startsWith('Séries')) {
            categories.add(nome);
          }
        }
        return categories;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar filmes por gênero/categoria
  // Formato da categoria no Baserow: "Filmes | Acao", "Filmes | Comedia", etc.
  Future<List<Movie>> getMoviesByGenre(String genre) async {
    try {
      // Mapeia o nome do gênero para o formato do Baserow
      final Map<String, String> genreMapping = {
        'Ação': 'Filmes | Acao',
        'Comédia': 'Filmes | Comedia',
        'Suspense': 'Filmes | Suspense',
        'Ficção': 'Filmes | Ficcao',
        'Romance': 'Filmes | Romance',
        'Família': 'Filmes | Família',
        'Terror': 'Filmes | Terror',
        'Drama': 'Filmes | Drama',
        'Aventura': 'Filmes | Aventura',
      };
      
      final searchTerm = genreMapping[genre] ?? 'Filmes | $genre';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar filmes por gênero com paginação (para tela de categoria)
  Future<Map<String, dynamic>> getMoviesByGenrePaginated(String genre, {int page = 1, int size = 30}) async {
    try {
      String searchTerm;
      
      // Se já é um valor do Baserow (contém "Filmes |"), usa direto
      if (genre.contains('Filmes |')) {
        searchTerm = genre;
      } else {
        // Senão, mapeia o nome do gênero para o formato do Baserow
        final Map<String, String> genreMapping = {
          'Ação': 'Filmes | Acao',
          'Comédia': 'Filmes | Comedia',
          'Suspense': 'Filmes | Suspense',
          'Ficção': 'Filmes | Ficcao',
          'Romance': 'Filmes | Romance',
          'Família': 'Filmes | Família',
          'Terror': 'Filmes | Terror',
          'Drama': 'Filmes | Drama',
          'Aventura': 'Filmes | Aventura',
          'Animação': 'Filmes | Animacao',
          'Lançamentos': 'Filmes | Lancamentos',
          'Lançamentos 2025': 'Filmes | Lancamentos 2025',
          'Cinema': 'Filmes | Cinema',
          'Nacionais': 'Filmes | Nacionais',
          'Documentarios': 'Filmes | Documentarios',
          'Religiosos': 'Filmes | Religiosos',
          'Guerra': 'Filmes | Guerra',
          'Faroeste': 'Filmes | Faroeste',
          'Fantasia': 'Filmes | Fantasia',
        };
        
        searchTerm = genreMapping[genre] ?? 'Filmes | $genre';
      }
      
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=$size&page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'movies': results.map((item) => _convertToMovie(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'movies': <Movie>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'movies': <Movie>[], 'hasNext': false, 'total': 0};
    }
  }

  // Buscar séries por categoria com paginação
  Future<Map<String, dynamic>> getTVShowsByCategoryPaginated(String category, {int page = 1, int size = 30}) async {
    try {
      String searchTerm;
      
      // Se já contém "Series |", usa direto (vem do Baserow)
      if (category.contains('Series |')) {
        searchTerm = category;
      } else {
        // Senão, mapeia ou adiciona o prefixo
        final Map<String, String> categoryMapping = {
          'Disney': 'Series | Disney Plus',
          'Netflix': 'Series | Netflix',
          'GloboPlay': 'Series | Globoplay',
          'Novelas': 'Series | Novelas',
          'Ultimas': '', // Busca todas as séries ordenadas por data
        };
        
        searchTerm = categoryMapping[category] ?? 'Series | $category';
      }
      
      String url;
      if (category == 'Ultimas' || searchTerm.isEmpty) {
        // Últimas séries - busca todas ordenadas por data
        url = '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Tipo__equal=Series&order_by=-Data&size=$size&page=$page';
      } else {
        url = '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=$size&page=$page';
      }
      
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        
        return {
          'tvShows': results.map((item) => _convertToTVShow(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    }
  }

  // Buscar novelas com paginação
  Future<Map<String, dynamic>> getNovelsPaginated({int page = 1, int size = 30}) async {
    try {
      // Busca por "Series | Novelas" ou "Novelas"
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=Novelas&size=$size&page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'tvShows': results.map((item) => _convertToTVShow(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    }
  }

  // Buscar TODOS os filmes com paginação (para biblioteca)
  // sortBy: 'Recentes', 'A-Z', 'Z-A', 'Mais vistos'
  // category: valor exato do Baserow (ex: 'Filmes | Acao') ou null para todos
  Future<Map<String, dynamic>> getAllMoviesPaginated({
    int page = 1,
    int size = 30,
    String sortBy = 'Recentes',
    String? category,
  }) async {
    try {
      // Monta a ordenação
      String orderBy;
      switch (sortBy) {
        case 'A-Z':
          orderBy = 'Nome';
          break;
        case 'Z-A':
          orderBy = '-Nome';
          break;
        case 'Mais vistos':
          orderBy = '-Views';
          break;
        default: // Recentes
          orderBy = '-Data';
      }

      String url =
          '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Tipo__equal=Filmes&order_by=$orderBy&size=$size&page=$page';

      // Adiciona filtro de categoria se especificado (usa valor direto do Baserow)
      if (category != null && category.isNotEmpty) {
        url += '&filter__Categoria__contains=$category';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'movies': results.map((item) => _convertToMovie(item)).toList(),
          'hasMore': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'movies': <Movie>[], 'hasMore': false, 'total': 0};
    } catch (e) {
      return {'movies': <Movie>[], 'hasMore': false, 'total': 0};
    }
  }

  // Buscar TODAS as séries com paginação (para biblioteca)
  // sortBy: 'Recentes', 'A-Z', 'Z-A', 'Mais vistos'
  // category: categoria específica (ex: 'Netflix', 'Disney Plus')
  Future<Map<String, dynamic>> getAllSeriesPaginated({
    int page = 1, 
    int size = 30,
    String sortBy = 'Recentes',
    String? category,
  }) async {
    try {
      // Monta a ordenação
      String orderBy;
      switch (sortBy) {
        case 'A-Z':
          orderBy = 'Nome';
          break;
        case 'Z-A':
          orderBy = '-Nome';
          break;
        case 'Mais vistos':
          orderBy = '-Views';
          break;
        default: // Recentes
          orderBy = '-Data';
      }
      
      String url = '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Tipo__equal=Series&order_by=$orderBy&size=$size&page=$page';
      
      // Adiciona filtro de categoria se especificado
      if (category != null && category.isNotEmpty) {
        final searchTerm = 'Series | $category';
        url += '&filter__Categoria__contains=$searchTerm';
      }
      
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'tvShows': results.map((item) => _convertToTVShow(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    }
  }

  // Buscar animes (Crunchyroll) com paginação
  Future<Map<String, dynamic>> getAnimesPaginated({int page = 1, int size = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=Series | Crunchyroll&size=$size&page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'tvShows': results.map((item) => _convertToTVShow(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    }
  }

  // Buscar categorias de séries da tabela Categoria Biblioteca (4997)
  Future<List<Map<String, String>>> getAllSeriesCategories() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/$_categoryLibraryTableId/?user_field_names=true&size=100'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final List<Map<String, String>> categories = [];

        for (final item in results) {
          final nome = item['Nome']?.toString() ?? '';
          // Pega categorias que começam com "Series |"
          if (nome.startsWith('Series |')) {
            // Extrai o nome legível (ex: "Series | Disney Plus" -> "Disney Plus")
            final parts = nome.split('|');
            if (parts.length > 1) {
              final catName = parts[1].trim();
              categories.add({
                'name': catName,
                'value': nome, // Valor exato do Baserow
              });
            }
          }
        }
        return categories;
      }
      return [];
    } catch (e) {
      print('Erro ao buscar categorias de séries: $e');
      return [];
    }
  }

  // Buscar categorias da tabela Categoria Biblioteca (4997)
  // Retorna lista de mapas com 'name' (nome legível) e 'value' (valor exato do Baserow)
  Future<List<Map<String, String>>> getMovieCategoriesWithValues() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/$_categoryLibraryTableId/?user_field_names=true&size=100'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final List<Map<String, String>> categories = [];

        for (final item in results) {
          final nome = item['Nome']?.toString() ?? '';
          // Pega categorias que começam com "Filmes |"
          if (nome.startsWith('Filmes |')) {
            // Extrai o nome legível (ex: "Filmes | Acao" -> "Ação")
            final parts = nome.split('|');
            if (parts.length > 1) {
              final catName = parts[1].trim();
              // Mapeia para nome legível com acentos
              final Map<String, String> reverseMapping = {
                'Acao': 'Ação',
                'Comedia': 'Comédia',
                'Ficcao': 'Ficção',
                'Familia': 'Família',
                'Família': 'Família',
                'Animacao': 'Animação',
                'Lancamentos': 'Lançamentos',
                'Lancamentos 2025': 'Lançamentos 2025',
              };
              categories.add({
                'name': reverseMapping[catName] ?? catName,
                'value': nome, // Valor exato do Baserow
              });
            }
          }
        }
        return categories;
      }
      return [];
    } catch (e) {
      print('Erro ao buscar categorias de filmes: $e');
      return [];
    }
  }

  // Método legado para compatibilidade
  Future<List<String>> getMovieCategories() async {
    final categories = await getMovieCategoriesWithValues();
    return categories.map((c) => c['name']!).toList();
  }

  // Buscar categorias de séries da tabela Categoria Biblioteca (4997)
  Future<List<String>> getSeriesCategoriesForLibrary() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_categoryLibraryTableId/?user_field_names=true&size=100'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final List<String> categories = [];
        
        for (final item in results) {
          final nome = item['Nome']?.toString() ?? '';
          // Pega categorias que começam com "Series |"
          if (nome.startsWith('Series |')) {
            final parts = nome.split('|');
            if (parts.length > 1) {
              categories.add(parts[1].trim());
            }
          }
        }
        return categories;
      }
      return [];
    } catch (e) {
      print('Erro ao buscar categorias de séries: $e');
      return [];
    }
  }

  // Buscar filmes por categoria específica com paginação
  Future<Map<String, dynamic>> getMoviesByCategoryPaginated(String category, {int page = 1, int size = 30}) async {
    try {
      final Map<String, String> categoryMapping = {
        'Ação': 'Filmes | Acao',
        'Comédia': 'Filmes | Comedia',
        'Ficção': 'Filmes | Ficcao',
        'Família': 'Filmes | Familia',
      };
      
      final searchTerm = categoryMapping[category] ?? 'Filmes | $category';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=$size&page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'movies': results.map((item) => _convertToMovie(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'movies': <Movie>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'movies': <Movie>[], 'hasNext': false, 'total': 0};
    }
  }

  // Buscar séries por categoria específica com paginação (para biblioteca)
  Future<Map<String, dynamic>> getSeriesByCategoryPaginated(String category, {int page = 1, int size = 30}) async {
    try {
      final searchTerm = 'Series | $category';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=$size&page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final hasNext = data['next'] != null;
        return {
          'tvShows': results.map((item) => _convertToTVShow(item)).toList(),
          'hasNext': hasNext,
          'total': data['count'] ?? 0,
        };
      }
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    } catch (e) {
      return {'tvShows': <TVShow>[], 'hasNext': false, 'total': 0};
    }
  }

  Future<List<Movie>> getAllMoviesByGenre(String genre) async {
    try {
      final Map<String, String> genreMapping = {
        'Ação': 'Filmes | Acao',
        'Comédia': 'Filmes | Comedia',
        'Suspense': 'Filmes | Suspense',
        'Ficção': 'Filmes | Ficcao',
        'Romance': 'Filmes | Romance',
        'Família': 'Filmes | Família',
        'Terror': 'Filmes | Terror',
        'Drama': 'Filmes | Drama',
        'Aventura': 'Filmes | Aventura',
      };
      
      final searchTerm = genreMapping[genre] ?? 'Filmes | $genre';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=200'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar TODAS as séries por categoria (sem limite)
  Future<List<TVShow>> getAllTVShowsByCategory(String category) async {
    try {
      final Map<String, String> categoryMapping = {
        'Disney': 'Series | Disney Plus',
        'Netflix': 'Series | Netflix',
        'GloboPlay': 'Series | Globoplay',
        'Novelas': 'Series | Novelas',
        'Ultimas': '', // Caso especial - busca todas as séries recentes
      };
      
      // Caso especial para "Últimas Séries"
      if (category == 'Ultimas') {
        var response = await http.get(
          Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&filter__Tipo__equal=Series&size=200'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List results = data['results'] ?? [];
          if (results.isNotEmpty) {
            return results.map((item) => _convertToTVShow(item)).toList();
          }
        }

        // Fallback com acento
        response = await http.get(
          Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=-Data&filter__Tipo__equal=Séries&size=200'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List results = data['results'] ?? [];
          return results.map((item) => _convertToTVShow(item)).toList();
        }
        return [];
      }
      
      final searchTerm = categoryMapping[category] ?? 'Series | $category';
      
      var response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=200'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => _convertToTVShow(item)).toList();
        }
      }

      // Fallback: tenta com has
      response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__has=$searchTerm&size=200'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar todas as séries por categoria $category: $e');
      return [];
    }
  }

  // Buscar TODAS as novelas (sem limite)
  Future<List<TVShow>> getAllNovelas() async {
    try {
      final Set<int> addedIds = {};
      final List<TVShow> allNovelas = [];

      // Busca por "Series | Novelas"
      final response1 = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=Series | Novelas&size=200'),
        headers: _headers,
      );

      if (response1.statusCode == 200) {
        final data = json.decode(response1.body);
        final List results = data['results'] ?? [];
        for (final item in results) {
          final id = _parseInt(item['id']);
          if (!addedIds.contains(id)) {
            addedIds.add(id);
            allNovelas.add(_convertToTVShow(item));
          }
        }
      }

      // Busca por "Novelas"
      final response2 = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=Novelas&size=200'),
        headers: _headers,
      );

      if (response2.statusCode == 200) {
        final data = json.decode(response2.body);
        final List results = data['results'] ?? [];
        for (final item in results) {
          final id = _parseInt(item['id']);
          if (!addedIds.contains(id)) {
            addedIds.add(id);
            allNovelas.add(_convertToTVShow(item));
          }
        }
      }

      return allNovelas;
    } catch (e) {
      print('Erro ao buscar todas as novelas: $e');
      return [];
    }
  }

  // Buscar TODOS os filmes (para seções como "Escolhidos para você", "Esta semana", etc)
  Future<List<Movie>> getAllMovies({String? orderBy}) async {
    try {
      final order = orderBy ?? '-Data';
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=$order&filter__Tipo__equal=Filmes&size=200'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar TODAS as séries (para Top 10, etc)
  Future<List<TVShow>> getAllTVShows({String? orderBy}) async {
    try {
      final order = orderBy ?? '-Data';
      
      var response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=$order&filter__Tipo__equal=Series&size=200'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => _convertToTVShow(item)).toList();
        }
      }

      // Fallback com acento
      response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&order_by=$order&filter__Tipo__equal=Séries&size=200'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Buscar filmes adicionados esta semana
  Future<List<Movie>> getMoviesThisWeek() async {
    try {
      // Calcular data de 7 dias atrás
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Data__date_after=$weekAgoStr&filter__Tipo__equal=Filmes&order_by=-Data&size=10'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToMovie(item)).toList();
      }
      return [];
    } catch (e) {
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
      addedDate: item['Data']?.toString(),
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
          ? 'https://api.themoviedb.org/3/movie/$tmdbId?api_key=$apiKey&language=pt-BR&append_to_response=credits,similar,images&include_image_language=pt,en,null'
          : 'https://api.themoviedb.org/3/tv/$tmdbId?api_key=$apiKey&language=pt-BR&append_to_response=credits,similar,images&include_image_language=pt,en,null';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Pegar o poster original (primeiro da lista de posters ou o padrão)
        final images = data['images'] as Map<String, dynamic>?;
        if (images != null) {
          final posters = images['posters'] as List?;
          final backdrops = images['backdrops'] as List?;
          
          // Usar o primeiro poster da lista (geralmente o original/padrão)
          if (posters != null && posters.isNotEmpty) {
            data['original_poster_path'] = posters[0]['file_path'];
          }
          
          // Usar o primeiro backdrop da lista
          if (backdrops != null && backdrops.isNotEmpty) {
            data['original_backdrop_path'] = backdrops[0]['file_path'];
          }
        }
        
        return data;
      }
      return null;
    } catch (e) {
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
          // Helper para pegar valor do TMDB apenas se válido
          String? getTmdbImage(String? tmdbPath, String? baserowPath) {
            if (tmdbPath != null && tmdbPath.isNotEmpty) {
              return tmdbPath;
            }
            return baserowPath;
          }
          
          // Combina dados do Baserow com TMDB (Baserow como fallback)
          return Movie(
            id: baserowMovie.id,
            title: (tmdbData['title'] as String?)?.isNotEmpty == true 
                ? tmdbData['title'] 
                : baserowMovie.title,
            overview: (tmdbData['overview'] as String?)?.isNotEmpty == true 
                ? tmdbData['overview'] 
                : baserowMovie.overview,
            posterPath: getTmdbImage(tmdbData['poster_path'], baserowMovie.posterPath),
            backdropPath: getTmdbImage(tmdbData['backdrop_path'], baserowMovie.backdropPath),
            releaseDate: (tmdbData['release_date'] as String?)?.isNotEmpty == true 
                ? tmdbData['release_date'] 
                : baserowMovie.releaseDate,
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
      return [];
    }
  }
  Future<List<Movie>> getRelatedMovies(String category, int excludeId) async {
    try {
      // Se tem categoria, busca apenas pela primeira
      if (category.isNotEmpty) {
        final firstCategory = category.split(',').first.trim();
        
        final url = '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$firstCategory&filter__Tipo__equal=Filmes&size=10';
        
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
        Uri.parse('$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categorias__contains=$category&filter__Tipo__equal=Séries&size=10'),
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
      return [];
    }
  }

  // Buscar séries por categoria específica (Disney+, Netflix, GloboPlay)
  // Formato da categoria no Baserow: "Series | Disney Plus", "Series | Netflix", "Series | Globoplay"
  Future<List<TVShow>> getTVShowsByCategory(String category) async {
    try {
      // Mapeia o nome da categoria para o formato do Baserow (sem acento em "Series")
      final Map<String, String> categoryMapping = {
        'Disney': 'Series | Disney Plus',
        'Netflix': 'Series | Netflix',
        'GloboPlay': 'Series | Globoplay',
      };
      
      final searchTerm = categoryMapping[category] ?? 'Series | $category';
      
      // Busca pela categoria (campo Categoria contém o termo)
      var response = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=$searchTerm&size=15'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => _convertToTVShow(item)).toList();
        }
      }

      // Se não encontrou, tenta com filtro para multiple select (has)
      response = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__has=$searchTerm&size=15'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) => _convertToTVShow(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar séries por categoria $category: $e');
      return [];
    }
  }

  // Buscar novelas (busca por "Series | Novelas" e "Novelas" e combina resultados)
  Future<List<TVShow>> getNovelas() async {
    try {
      final Set<int> addedIds = {};
      final List<TVShow> allNovelas = [];

      // Busca por "Series | Novelas" (formato padrão, sem acento)
      final response1 = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=Series | Novelas&size=15'),
        headers: _headers,
      );

      if (response1.statusCode == 200) {
        final data = json.decode(response1.body);
        final List results = data['results'] ?? [];
        for (final item in results) {
          final id = _parseInt(item['id']);
          if (!addedIds.contains(id)) {
            addedIds.add(id);
            allNovelas.add(_convertToTVShow(item));
          }
        }
      }

      // Busca por "Novelas" (formato alternativo) - pode ter registros diferentes
      final response2 = await http.get(
        Uri.parse(
            '$_baseUrl/$_moviesTableId/?user_field_names=true&filter__Categoria__contains=Novelas&size=15'),
        headers: _headers,
      );

      if (response2.statusCode == 200) {
        final data = json.decode(response2.body);
        final List results = data['results'] ?? [];
        for (final item in results) {
          final id = _parseInt(item['id']);
          if (!addedIds.contains(id)) {
            addedIds.add(id);
            allNovelas.add(_convertToTVShow(item));
          }
        }
      }

      return allNovelas;
    } catch (e) {
      print('Erro ao buscar novelas: $e');
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

  // ==================== AUTENTICAÇÃO ====================

  // Login do usuário
  Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      // Busca usuário pelo email
      final response = await http.get(
        Uri.parse('$_baseUrl/$_usersTableId/?user_field_names=true&filter__Email__equal=$email'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isEmpty) {
          return {'success': false, 'message': 'Email não encontrado'};
        }

        final user = results.first;
        final storedPassword = user['Senha']?.toString() ?? '';
        
        if (storedPassword == senha) {
          return {
            'success': true,
            'user': {
              'id': user['id'],
              'nome': user['Nome'] ?? '',
              'email': user['Email'] ?? '',
              'dias': _parseInt(user['Dias']),
              'restam': _parseInt(user['Restam']),
            }
          };
        } else {
          return {'success': false, 'message': 'Senha incorreta'};
        }
      }
      return {'success': false, 'message': 'Erro ao conectar com o servidor'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // Criar nova conta
  Future<Map<String, dynamic>> createAccount(String nome, String email, String senha) async {
    try {
      // Verifica se email já existe
      final checkResponse = await http.get(
        Uri.parse('$_baseUrl/$_usersTableId/?user_field_names=true&filter__Email__equal=$email'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (checkResponse.statusCode == 200) {
        final checkData = json.decode(checkResponse.body);
        final List existingUsers = checkData['results'] ?? [];
        
        if (existingUsers.isNotEmpty) {
          // Email já existe - faz login automático se a senha bater
          final existingUser = existingUsers.first;
          final storedPassword = existingUser['Senha']?.toString() ?? '';
          
          if (storedPassword == senha) {
            // Senha correta - retorna sucesso (login automático)
            return {
              'success': true,
              'user': {
                'id': existingUser['id'],
                'nome': existingUser['Nome'] ?? nome,
                'email': existingUser['Email'] ?? email,
                'dias': _parseInt(existingUser['Dias']),
                'restam': _parseInt(existingUser['Restam']),
              }
            };
          }
          return {'success': false, 'message': 'Este email já está cadastrado'};
        }
      }

      // Cria o novo usuário com 1 dia de teste
      // Calcula a data de vencimento (hoje + dias)
      final hoje = DateTime.now();
      final pagamento = hoje.add(const Duration(days: 1));
      final pagamentoStr = '${pagamento.year}-${pagamento.month.toString().padLeft(2, '0')}-${pagamento.day.toString().padLeft(2, '0')}';
      
      // Nota: "Restam" é uma fórmula no Baserow, não enviamos
      final response = await http.post(
        Uri.parse('$_baseUrl/$_usersTableId/?user_field_names=true'),
        headers: _headers,
        body: json.encode({
          'Nome': nome,
          'Email': email,
          'Senha': senha,
          'Dias': 1,
          'Pagamento': pagamentoStr,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userData = json.decode(response.body);
        return {
          'success': true,
          'user': {
            'id': userData['id'],
            'nome': userData['Nome'] ?? nome,
            'email': userData['Email'] ?? email,
            'dias': userData['Dias'] ?? 1,
            'restam': userData['Restam'] ?? 1,
          }
        };
      }
      return {'success': false, 'message': 'Erro ao criar conta. Código: ${response.statusCode}'};
    } catch (e) {
      // Se deu timeout ou erro, verifica se a conta foi criada mesmo assim
      // Aguarda um pouco mais para o servidor processar
      await Future.delayed(const Duration(seconds: 2));
      
      try {
        final verifyResponse = await http.get(
          Uri.parse('$_baseUrl/$_usersTableId/?user_field_names=true&filter__Email__equal=$email'),
          headers: _headers,
        ).timeout(const Duration(seconds: 15));
        
        if (verifyResponse.statusCode == 200) {
          final verifyData = json.decode(verifyResponse.body);
          final List users = verifyData['results'] ?? [];
          
          if (users.isNotEmpty) {
            // Conta foi criada! Retorna sucesso
            final user = users.first;
            return {
              'success': true,
              'user': {
                'id': user['id'],
                'nome': user['Nome'] ?? nome,
                'email': user['Email'] ?? email,
                'dias': _parseInt(user['Dias']),
                'restam': _parseInt(user['Restam']),
              }
            };
          }
        }
      } catch (verifyError) {
        // Verificação também falhou - problema de rede real
      }
      
      return {'success': false, 'message': 'Erro de conexão. Tente novamente.'};
    }
  }

  // Verificar se email existe
  Future<bool> emailExists(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_usersTableId/?user_field_names=true&filter__Email__equal=$email'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==================== SINCRONIZAÇÃO DE DADOS DO USUÁRIO ====================
  
  // Salvar favoritos do usuário no Baserow
  Future<bool> syncFavorites(int userId, List<String> favorites) async {
    try {
      // Busca se já existe registro para este usuário
      final response = await http.get(
        Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true&filter__Usuario_ID__equal=$userId'),
        headers: _headers,
      );

      final favoritesJson = json.encode(favorites);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isNotEmpty) {
          // Atualiza registro existente
          final recordId = results.first['id'];
          final updateResponse = await http.patch(
            Uri.parse('$_baseUrl/$_userDataTableId/$recordId/?user_field_names=true'),
            headers: _headers,
            body: json.encode({'Favoritos': favoritesJson}),
          );
          return updateResponse.statusCode == 200;
        } else {
          // Cria novo registro
          final createResponse = await http.post(
            Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true'),
            headers: _headers,
            body: json.encode({
              'Usuario_ID': userId,
              'Favoritos': favoritesJson,
            }),
          );
          return createResponse.statusCode == 200;
        }
      }
      return false;
    } catch (e) {
      print('Erro ao sincronizar favoritos: $e');
      return false;
    }
  }

  // Buscar favoritos do usuário do Baserow
  Future<List<String>> getFavorites(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true&filter__Usuario_ID__equal=$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isNotEmpty) {
          final favoritesStr = results.first['Favoritos']?.toString() ?? '[]';
          final List decoded = json.decode(favoritesStr);
          return decoded.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Erro ao buscar favoritos: $e');
      return [];
    }
  }

  // Salvar "Minha Lista" do usuário no Baserow
  Future<bool> syncMyList(int userId, List<String> myList) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true&filter__Usuario_ID__equal=$userId'),
        headers: _headers,
      );

      final myListJson = json.encode(myList);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isNotEmpty) {
          // Atualiza registro existente
          final recordId = results.first['id'];
          final updateResponse = await http.patch(
            Uri.parse('$_baseUrl/$_userDataTableId/$recordId/?user_field_names=true'),
            headers: _headers,
            body: json.encode({'Minha_List': myListJson}),
          );
          return updateResponse.statusCode == 200;
        } else {
          // Cria novo registro
          final createResponse = await http.post(
            Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true'),
            headers: _headers,
            body: json.encode({
              'Usuario_ID': userId,
              'Minha_List': myListJson,
            }),
          );
          return createResponse.statusCode == 200;
        }
      }
      return false;
    } catch (e) {
      print('Erro ao sincronizar minha lista: $e');
      return false;
    }
  }

  // Buscar "Minha Lista" do usuário do Baserow
  Future<List<String>> getMyList(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true&filter__Usuario_ID__equal=$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isNotEmpty) {
          final myListValue = results.first['Minha_List'];
          
          // Se for null ou vazio, retorna lista vazia
          if (myListValue == null || myListValue.toString().isEmpty) {
            return [];
          }
          
          final myListStr = myListValue.toString();
          
          try {
            final List decoded = json.decode(myListStr);
            return decoded.map((e) => e.toString()).toList();
          } catch (e) {
            print('Erro ao decodificar Minha Lista: $e');
            return [];
          }
        }
      }
      return [];
    } catch (e) {
      print('Erro ao buscar minha lista: $e');
      return [];
    }
  }

  // Salvar progresso de visualização do usuário no Baserow
  Future<bool> syncWatchProgress(int userId, List<Map<String, dynamic>> progressList) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true&filter__Usuario_ID__equal=$userId'),
        headers: _headers,
      );

      final progressJson = json.encode(progressList);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isNotEmpty) {
          // Atualiza registro existente
          final recordId = results.first['id'];
          final updateResponse = await http.patch(
            Uri.parse('$_baseUrl/$_userDataTableId/$recordId/?user_field_names=true'),
            headers: _headers,
            body: json.encode({'Progresso': progressJson}),
          );
          return updateResponse.statusCode == 200;
        } else {
          // Cria novo registro
          final createResponse = await http.post(
            Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true'),
            headers: _headers,
            body: json.encode({
              'Usuario_ID': userId,
              'Progresso': progressJson,
            }),
          );
          return createResponse.statusCode == 200;
        }
      }
      return false;
    } catch (e) {
      print('Erro ao sincronizar progresso: $e');
      return false;
    }
  }

  // Buscar progresso de visualização do usuário do Baserow
  Future<List<Map<String, dynamic>>> getWatchProgress(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_userDataTableId/?user_field_names=true&filter__Usuario_ID__equal=$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        if (results.isNotEmpty) {
          final progressStr = results.first['Progresso']?.toString() ?? '[]';
          final List decoded = json.decode(progressStr);
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      print('Erro ao buscar progresso: $e');
      return [];
    }
  }
}
