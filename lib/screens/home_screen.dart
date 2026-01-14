import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../services/watch_progress_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../models/profile.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/banner_carousel_tv.dart';
import '../widgets/trending_carousel.dart';
import '../widgets/top10_card.dart';
import '../widgets/top10_tv_card.dart';
import '../widgets/home_skeleton_loading.dart';
import '../widgets/tv_show_card.dart';
import '../widgets/movie_card.dart';
import '../widgets/featured_card.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/picked_for_you_card.dart';
import '../widgets/new_release_card.dart';
import '../utils/page_transitions.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final BaserowService _baserowService = BaserowService();
  final WatchProgressService _watchProgressService = WatchProgressService();
  int _selectedIndex = 0;
  int _selectedTab = 0;
  Profile? _currentProfile;
  PageController? _pageController;
  bool _isLoading = true;

  // Dados carregados
  List<Movie> _trendingMovies = [];
  List<Movie> _popularMovies = [];
  List<Movie> _top10Movies = [];
  List<TVShow> _top10TVShows = [];
  List<TVShow> _trendingTVShows = [];
  List<dynamic> _latestContent = [];
  List<WatchProgress> _continueWatching = [];
  List<Map<String, dynamic>> _homeCategories = [];
  List<Movie> _pickedForYou = [];
  List<Movie> _thisWeekMovies = [];
  Map<String, List<Movie>> _genreMovies = {};

  // Séries por categoria
  List<TVShow> _novelas = [];
  List<TVShow> _seriesDisney = [];
  List<TVShow> _seriesNetflix = [];
  List<TVShow> _seriesGloboPlay = [];
  
  // Categorias dinâmicas de séries (carregadas do Baserow)
  List<String> _seriesCategories = [];
  Map<String, List<TVShow>> _seriesByCategory = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedTab);
    _loadCurrentProfile();
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega quando volta para esta tela
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _loadAllData();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recarrega quando o app volta ao foreground
      _loadAllData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    // Só mostra loading se não tiver dados ainda
    if (_top10Movies.isEmpty && _top10TVShows.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Carregar continue watching primeiro (local, rápido)
      // Usa getForHomeDisplay para mostrar apenas 1 card por série
      final continueWatching = await _watchProgressService.getForHomeDisplay();
      
      // Carregar todos os dados em paralelo
      final results = await Future.wait([
        _baserowService.getTrendingMovies(),
        _baserowService.getPopularMovies(),
        _baserowService.getTop10Movies(),
        _baserowService.getTop10TVShows(),
        _baserowService.getTrendingTVShows(),
        _baserowService.getLatestContent(),
        _baserowService.getHomeCategories(),
        _baserowService.getPickedForYou(),
        _baserowService.getMoviesThisWeek(),
        _baserowService.getMoviesByGenre('Ação'),
        _baserowService.getMoviesByGenre('Comédia'),
        _baserowService.getMoviesByGenre('Suspense'),
        _baserowService.getMoviesByGenre('Ficção'),
        _baserowService.getMoviesByGenre('Romance'),
        _baserowService.getMoviesByGenre('Família'),
        _baserowService.getNovelas(),
        _baserowService.getTVShowsByCategory('Disney'),
        _baserowService.getTVShowsByCategory('Netflix'),
        _baserowService.getTVShowsByCategory('GloboPlay'),
      ]);

      if (mounted) {
        setState(() {
          _continueWatching = continueWatching;
          _trendingMovies = results[0] as List<Movie>;
          _popularMovies = results[1] as List<Movie>;
          _top10Movies = results[2] as List<Movie>;
          _top10TVShows = results[3] as List<TVShow>;
          _trendingTVShows = results[4] as List<TVShow>;
          _latestContent = results[5] as List<dynamic>;
          _homeCategories = results[6] as List<Map<String, dynamic>>;
          _pickedForYou = results[7] as List<Movie>;
          _thisWeekMovies = results[8] as List<Movie>;
          _genreMovies = {
            'Ação': results[9] as List<Movie>,
            'Comédia': results[10] as List<Movie>,
            'Suspense': results[11] as List<Movie>,
            'Ficção': results[12] as List<Movie>,
            'Romance': results[13] as List<Movie>,
            'Família': results[14] as List<Movie>,
          };
          _novelas = results[15] as List<TVShow>;
          _seriesDisney = results[16] as List<TVShow>;
          _seriesNetflix = results[17] as List<TVShow>;
          _seriesGloboPlay = results[18] as List<TVShow>;
          _isLoading = false;
        });

        // Pré-carregar imagens em background
        _precacheImages(context);

        // Carregar categorias dinâmicas de séries em background
        _loadSeriesCategories();
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Carrega as categorias de séries do Baserow e suas séries
  Future<void> _loadSeriesCategories() async {
    try {
      final categories = await _baserowService.getSeriesCategories();
      if (mounted) {
        setState(() => _seriesCategories = categories);
      }

      // Carregar séries de cada categoria em paralelo
      final futures = <Future<MapEntry<String, List<TVShow>>>>[];
      for (final category in categories) {
        // Extrai o nome da categoria (ex: "Séries Turcas" -> "Turcas")
        final searchTerm = category.replaceFirst('Séries ', '');
        futures.add(_baserowService
            .getTVShowsByCategory(searchTerm)
            .then((shows) => MapEntry(category, shows)));
      }

      final results = await Future.wait(futures);
      final Map<String, List<TVShow>> seriesMap = {};
      for (final entry in results) {
        if (entry.value.isNotEmpty) {
          seriesMap[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() => _seriesByCategory = seriesMap);
      }
    } catch (e) {
      print('Erro ao carregar categorias de séries: $e');
    }
  }

  // Pré-carrega as imagens dos posters para evitar loading durante scroll
  void _precacheImages(BuildContext context) {
    // Filmes
    for (final movie in _trendingMovies) {
      if (movie.posterPath != null) {
        precacheImage(
          CachedNetworkImageProvider(BaserowService.getImageUrl(movie.posterPath)),
          context,
        );
      }
    }
    for (final movie in _top10Movies) {
      if (movie.posterPath != null) {
        precacheImage(
          CachedNetworkImageProvider(BaserowService.getImageUrl(movie.posterPath)),
          context,
        );
      }
    }
    for (final movie in _thisWeekMovies) {
      if (movie.posterPath != null) {
        precacheImage(
          CachedNetworkImageProvider(BaserowService.getImageUrl(movie.posterPath)),
          context,
        );
      }
    }
    
    // Séries
    for (final tvShow in _top10TVShows) {
      if (tvShow.posterPath != null) {
        precacheImage(
          CachedNetworkImageProvider(BaserowService.getImageUrl(tvShow.posterPath)),
          context,
        );
      }
    }
    for (final tvShow in _trendingTVShows) {
      if (tvShow.posterPath != null) {
        precacheImage(
          CachedNetworkImageProvider(BaserowService.getImageUrl(tvShow.posterPath)),
          context,
        );
      }
    }
    for (final tvShow in _novelas) {
      if (tvShow.posterPath != null) {
        precacheImage(
          CachedNetworkImageProvider(BaserowService.getImageUrl(tvShow.posterPath)),
          context,
        );
      }
    }
    
    // Gêneros
    for (final movies in _genreMovies.values) {
      for (final movie in movies) {
        if (movie.posterPath != null) {
          precacheImage(
            CachedNetworkImageProvider(BaserowService.getImageUrl(movie.posterPath)),
            context,
          );
        }
      }
    }
  }

  Future<void> _loadCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('currentProfile');
    if (profileJson != null && mounted) {
      setState(() {
        _currentProfile = Profile.fromJson(jsonDecode(profileJson));
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: HomeSkeletonLoading(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _selectedIndex == 0
          ? _buildHomeContent()
          : _selectedIndex == 1
              ? _buildLibraryTab()
              : _selectedIndex == 2
                  ? _buildFavoritesTab()
                  : _buildProfileTab(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.dashboard_outlined, 'Biblioteca', 1),
              _buildNavItem(Icons.favorite_border, 'Favoritos', 2),
              _buildNavItem(Icons.person_outline, 'Perfil', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        // Header fixo no topo
        Container(
          color: Colors.black,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoriesBar(),
              ],
            ),
          ),
        ),
        // Conteúdo com scroll abaixo do header
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _selectedTab = index),
              children: [
                _buildExplorarContent(),
                _buildFilmesContent(),
                _buildSeriesContent(),
                _buildMinhaListaContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          if (_currentProfile != null)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(int.parse(_currentProfile!.backgroundColor)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _currentProfile!.avatarUrl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentProfile != null)
                  Row(
                    children: [
                      Text(
                        'Olá, ${_currentProfile!.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      const Text('👋', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400]?.withOpacity(0.6),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesBar() {
    final categories = ['Explorar', 'Filmes', 'Séries', 'Minha Lista'];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedTab;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedTab = index);
              _pageController?.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    categories[index],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isSelected)
                    Container(
                      height: 3,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== CONTEÚDO DA ABA EXPLORAR (TUDO) =====
  Widget _buildExplorarContent() {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            // Banner carousel horizontal
            if (_trendingMovies.isNotEmpty)
              BannerCarousel(movies: _trendingMovies.take(5).toList()),
            const SizedBox(height: 20),
            // Continue Assistindo (acima de Novidades)
            if (_continueWatching.isNotEmpty) ...[
              _buildContinueWatchingSection(),
              const SizedBox(height: 30),
            ],
            // Renderizar seções dinâmicas baseadas nas categorias do Baserow
            ..._buildDynamicSections(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ===== CONTEÚDO DA ABA FILMES =====
  Widget _buildFilmesContent() {
    final filmesProgress = _continueWatching.where((p) => p.type == 'movie').toList();
    
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            // Banner de filmes
            if (_trendingMovies.isNotEmpty)
              BannerCarousel(movies: _trendingMovies.take(5).toList()),
            const SizedBox(height: 20),
            // Continue Assistindo - só filmes
            if (filmesProgress.isNotEmpty) ...[
              _buildContinueWatchingSectionFiltered(filmesProgress, 'Continue Assistindo'),
              const SizedBox(height: 30),
            ],
            // Top 10 Filmes
            if (_top10Movies.isNotEmpty) ...[
              _buildTop10Section('Top 10 Filmes', _top10Movies),
              const SizedBox(height: 30),
            ],
            // Chegou esta semana
            if (_thisWeekMovies.isNotEmpty) ...[
              _buildThisWeekSection(),
              const SizedBox(height: 30),
            ],
            // Gêneros de filmes
            ..._buildFilmesGenreSections(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ===== CONTEÚDO DA ABA SÉRIES =====
  Widget _buildSeriesContent() {
    final seriesProgress = _continueWatching.where((p) => p.type == 'tv').toList();
    
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            // Banner de séries em destaque
            if (_trendingTVShows.isNotEmpty)
              BannerCarouselTV(tvShows: _trendingTVShows.take(5).toList()),
            const SizedBox(height: 20),
            // Continue Assistindo - só séries
            if (seriesProgress.isNotEmpty) ...[
              _buildContinueWatchingSectionFiltered(
                  seriesProgress, 'Continue Assistindo'),
              const SizedBox(height: 30),
            ],
            // Top 10 Séries
            if (_top10TVShows.isNotEmpty) ...[
              _buildTop10TVSection('Top 10 Séries', _top10TVShows),
              const SizedBox(height: 30),
            ],
            // Últimas Séries
            if (_trendingTVShows.isNotEmpty) ...[
              _buildTVSection('Últimas Séries', _trendingTVShows, tvCategory: 'Ultimas'),
              const SizedBox(height: 30),
            ],
            // Novelas
            if (_novelas.isNotEmpty) ...[
              _buildTVSection('Novelas', _novelas, tvCategory: 'Novelas'),
              const SizedBox(height: 30),
            ],
            // Séries Disney+
            if (_seriesDisney.isNotEmpty) ...[
              _buildTVSection('Séries Disney+', _seriesDisney, tvCategory: 'Disney'),
              const SizedBox(height: 30),
            ],
            // Séries Netflix
            if (_seriesNetflix.isNotEmpty) ...[
              _buildTVSection('Séries Netflix', _seriesNetflix, tvCategory: 'Netflix'),
              const SizedBox(height: 30),
            ],
            // Séries GloboPlay
            if (_seriesGloboPlay.isNotEmpty) ...[
              _buildTVSection('Séries GloboPlay', _seriesGloboPlay, tvCategory: 'GloboPlay'),
              const SizedBox(height: 30),
            ],
            // Categorias dinâmicas de séries (carregadas do Baserow)
            ..._buildDynamicSeriesSections(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ===== CONTEÚDO DA ABA MINHA LISTA =====
  Widget _buildMinhaListaContent() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Sua lista está vazia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione filmes e séries aos favoritos',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Continue Assistindo filtrado (para abas Filmes e Séries)
  Widget _buildContinueWatchingSectionFiltered(List<WatchProgress> items, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 145,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final progress = items[index];
              return ContinueWatchingCard(
                progress: progress,
                onRemove: () async {
                  await _watchProgressService.removeProgress(
                    progress.contentId,
                    seasonNumber: progress.seasonNumber,
                    episodeNumber: progress.episodeNumber,
                  );
                  _loadAllData();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Seções de gêneros só para filmes
  List<Widget> _buildFilmesGenreSections() {
    final sections = <Widget>[];
    
    final genreNames = {
      'Ação': 'Adrenalina Máxima',
      'Comédia': 'Rir é Obrigatório',
      'Suspense': 'Suspense que Prende',
      'Ficção': 'Realidades Alternativas',
      'Romance': 'Amores que Marcam',
      'Família': 'Para Assistir em Família',
    };

    for (final entry in _genreMovies.entries) {
      if (entry.value.isNotEmpty) {
        final displayName = genreNames[entry.key] ?? entry.key;
        sections.add(_buildGenreSection(displayName, entry.key));
        sections.add(const SizedBox(height: 30));
      }
    }

    return sections;
  }

  // Seções dinâmicas de séries (carregadas do Baserow)
  List<Widget> _buildDynamicSeriesSections() {
    final sections = <Widget>[];

    for (final category in _seriesCategories) {
      final shows = _seriesByCategory[category];
      if (shows != null && shows.isNotEmpty) {
        // Extrai o nome da categoria para busca (ex: "Séries Turcas" -> "Turcas")
        final searchTerm = category.replaceFirst('Séries ', '');
        sections.add(_buildTVSection(category, shows, tvCategory: searchTerm));
        sections.add(const SizedBox(height: 30));
      }
    }

    return sections;
  }

  List<Widget> _buildDynamicSections() {
    final sections = <Widget>[];
    
    for (final category in _homeCategories) {
      final categoryName = category['nome'] as String;
      
      // Mapear nomes das categorias para as seções correspondentes
      if (categoryName == 'Tendências Agora') {
        // Substituir "Em Alta" por "Tendências Agora" usando FeaturedCards
        sections.add(_buildExclusiveSection());
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Chegou esta semana') {
        sections.add(_buildThisWeekSection());
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Top 10 em Filmes') {
        if (_top10Movies.isNotEmpty) {
          sections.add(_buildTop10Section('Top 10 Filmes', _top10Movies));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Top 10 em Séries') {
        if (_top10TVShows.isNotEmpty) {
          sections.add(_buildTop10TVSection('Top 10 Séries', _top10TVShows));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Adrenalina Máxima') {
        sections.add(_buildGenreSection('Adrenalina Máxima', 'Ação'));
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Rir é Obrigatório') {
        sections.add(_buildGenreSection('Rir é Obrigatório', 'Comédia'));
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Suspense que Prende') {
        sections.add(_buildGenreSection('Suspense que Prende', 'Suspense'));
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Realidades Alternativas') {
        sections.add(_buildGenreSection('Realidades Alternativas', 'Ficção'));
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Amores que Marcam') {
        sections.add(_buildGenreSection('Amores que Marcam', 'Romance'));
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Para Assistir em Família') {
        sections.add(_buildGenreSection('Para Assistir em Família', 'Família'));
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Novidades Recém Adicionadas') {
        sections.add(_buildLatestSection());
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Últimas Séries') {
        if (_trendingTVShows.isNotEmpty) {
          sections.add(_buildTVSection('Últimas Séries', _trendingTVShows, tvCategory: 'Ultimas'));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Escolhidos para você') {
        sections.add(_buildPickedForYouSection());
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Novelas') {
        if (_novelas.isNotEmpty) {
          sections.add(_buildTVSection('Novelas', _novelas, tvCategory: 'Novelas'));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Séries Disney+') {
        if (_seriesDisney.isNotEmpty) {
          sections.add(_buildTVSection('Séries Disney+', _seriesDisney, tvCategory: 'Disney'));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Séries Netflix') {
        if (_seriesNetflix.isNotEmpty) {
          sections.add(_buildTVSection('Séries Netflix', _seriesNetflix, tvCategory: 'Netflix'));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Séries GloboPlay') {
        if (_seriesGloboPlay.isNotEmpty) {
          sections.add(_buildTVSection('Séries GloboPlay', _seriesGloboPlay, tvCategory: 'GloboPlay'));
          sections.add(const SizedBox(height: 30));
        }
      }
    }
    
    return sections;
  }

  Widget _buildPickedForYouSection() {
    if (_pickedForYou.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Escolhidos para você',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: 'Escolhidos para você',
                        categoryType: 'movie',
                        initialMovies: _pickedForYou,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _pickedForYou.length,
            itemBuilder: (context, index) =>
                PickedForYouCard(movie: _pickedForYou[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildThisWeekSection() {
    if (_thisWeekMovies.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chegou esta semana',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: 'Chegou esta semana',
                        categoryType: 'movie',
                        initialMovies: _thisWeekMovies,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _thisWeekMovies.length,
            itemBuilder: (context, index) => MovieCard(movie: _thisWeekMovies[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreSection(String title, String genre) {
    final movies = _genreMovies[genre] ?? [];
    
    if (movies.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: title,
                        categoryType: 'movie',
                        genre: genre,
                        initialMovies: movies,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: movies.length,
            itemBuilder: (context, index) => MovieCard(movie: movies[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Continue Assistindo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _continueWatching.length,
            itemBuilder: (context, index) {
              final progress = _continueWatching[index];
              return ContinueWatchingCard(
                progress: progress,
                onRemove: () async {
                  await _watchProgressService.removeProgress(
                    progress.contentId,
                    seasonNumber: progress.seasonNumber,
                    episodeNumber: progress.episodeNumber,
                  );
                  _loadAllData();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExclusiveSection() {
    // Mistura filmes e séries sem duplicados
    final List<Widget> cards = [];
    final Set<int> usedMovieIds = {};
    final Set<int> usedTVShowIds = {};
    
    // Adiciona filmes do top 10 (com badge)
    for (final movie in _top10Movies.take(4)) {
      if (!usedMovieIds.contains(movie.id) && cards.length < 10) {
        usedMovieIds.add(movie.id);
        cards.add(FeaturedMovieCard(movie: movie, showTop10Badge: true));
      }
    }
    
    // Adiciona séries do top 10 (com badge)
    for (final tvShow in _top10TVShows.take(4)) {
      if (!usedTVShowIds.contains(tvShow.id) && cards.length < 10) {
        usedTVShowIds.add(tvShow.id);
        cards.add(FeaturedTVShowCard(tvShow: tvShow, showTop10Badge: true));
      }
    }
    
    // Adiciona filmes populares (sem badge) - evita duplicados
    for (final movie in _popularMovies) {
      if (!usedMovieIds.contains(movie.id) && cards.length < 10) {
        usedMovieIds.add(movie.id);
        cards.add(FeaturedMovieCard(movie: movie, showTop10Badge: false));
      }
    }
    
    // Adiciona séries em alta (sem badge) - evita duplicados
    for (final tvShow in _trendingTVShows) {
      if (!usedTVShowIds.contains(tvShow.id) && cards.length < 10) {
        usedTVShowIds.add(tvShow.id);
        cards.add(FeaturedTVShowCard(tvShow: tvShow, showTop10Badge: false));
      }
    }
    
    // Embaralha para misturar
    cards.shuffle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tendências Agora',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 334,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cards.length,
            itemBuilder: (context, index) => cards[index],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Movie> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: title,
                        categoryType: 'movie',
                        initialMovies: movies,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: movies.length,
            itemBuilder: (context, index) => MovieCard(movie: movies[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTVSection(String title, List<TVShow> tvShows, {String? tvCategory}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: title,
                        categoryType: 'tv',
                        tvCategory: tvCategory,
                        initialTVShows: tvShows,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tvShows.length,
            itemBuilder: (context, index) => TVShowCard(tvShow: tvShows[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieSection(String title, List<Movie> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: title,
                        categoryType: 'movie',
                        initialMovies: movies,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: movies.length,
            itemBuilder: (context, index) => MovieCard(movie: movies[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTop10Section(String title, List<Movie> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: title,
                        categoryType: 'movie',
                        initialMovies: movies,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: movies.take(10).length,
            itemBuilder: (context, index) => Top10Card(
              position: index + 1,
              posterPath: movies[index].posterPath ?? '',
              movieId: movies[index].id,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTop10TVSection(String title, List<TVShow> tvShows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: title,
                        categoryType: 'tv',
                        initialTVShows: tvShows,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tvShows.take(10).length,
            itemBuilder: (context, index) => Top10TVCard(
              position: index + 1,
              posterPath: tvShows[index].posterPath ?? '',
              tvShowId: tvShows[index].id,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestSection() {
    // Usa os filmes populares invertidos como "novidades"
    final latestMovies = _popularMovies.reversed.take(15).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Novidades Recém Adicionadas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryScreen(
                        title: 'Novidades Recém Adicionadas',
                        categoryType: 'movie',
                        initialMovies: latestMovies,
                      ),
                    ),
                  );
                },
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: latestMovies.length,
            itemBuilder: (context, index) => MovieCard(movie: latestMovies[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryTab() {
    final categories = ['Filmes', 'Séries', 'Novelas', 'Animes'];

    return Container(
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // Logo que colapsa ao rolar
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF1A1A2E),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.78,
                      child: Image.asset(
                        'assets/images/Logo.png',
                        width: 260,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              // Categorias que ficam fixas
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverCategoriesDelegate(
                  categories: categories,
                  selectedIndex: _librarySelectedCategory,
                  onTap: (index) {
                    setState(() => _librarySelectedCategory = index);
                  },
                ),
              ),
            ];
          },
          body: Container(
            color: Colors.black,
            child: _LibraryContentWidget(
              key: ValueKey(_librarySelectedCategory),
              selectedCategory: _librarySelectedCategory,
              baserowService: _baserowService,
              useExternalScroll: true,
            ),
          ),
        ),
      ),
    );
  }

  int _librarySelectedCategory = 0;

  Widget _buildFavoritesTab() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Favoritos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum favorito ainda',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adicione filmes e séries aos favoritos',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentProfile != null) ...[
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(int.parse(_currentProfile!.backgroundColor)),
                        ),
                        child: Center(
                          child: Text(
                            _currentProfile!.avatarUrl,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentProfile!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.person_outline, size: 80, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'Perfil não configurado',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
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

// Widget separado para o conteúdo da biblioteca com paginação
class _LibraryContentWidget extends StatefulWidget {
  final int selectedCategory;
  final BaserowService baserowService;
  final bool useExternalScroll;

  const _LibraryContentWidget({
    super.key,
    required this.selectedCategory,
    required this.baserowService,
    this.useExternalScroll = false,
  });

  @override
  State<_LibraryContentWidget> createState() => _LibraryContentWidgetState();
}

class _LibraryContentWidgetState extends State<_LibraryContentWidget> {
  final ScrollController _scrollController = ScrollController();
  List<Movie> _movies = [];
  List<TVShow> _tvShows = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalCount = 0;
  int _lastCategory = -1;
  static const int _pageSize = 30;

  // Filtros
  String _selectedSort = 'Recentes';
  String? _selectedGenre;
  List<String> _availableGenres = [];
  final List<String> _sortOptions = ['Recentes', 'A-Z', 'Z-A', 'Mais vistos'];
  
  // Categorias padrão para aparecer instantaneamente (baseadas na tabela Categoria Biblioteca)
  static const List<String> _defaultMovieCategories = [
    'Ação', 'Animação', 'Aventura', 'Cinema', 'Comédia', 
    'Documentarios', 'Drama', 'Família', 'Fantasia', 'Faroeste',
    'Ficção', 'Guerra', 'Lançamentos', 'Lançamentos 2025',
    'Nacionais', 'Religiosos', 'Romance', 'Suspense', 'Terror'
  ];
  static const List<String> _defaultSeriesCategories = [
    'Disney Plus', 'Globoplay', 'Netflix', 'Novelas', 'Crunchyroll'
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.useExternalScroll) {
      _scrollController.addListener(_onScroll);
    }
    _setDefaultGenres();
    _loadAvailableGenres();
  }

  void _setDefaultGenres() {
    if (widget.selectedCategory == 0) {
      _availableGenres = List.from(_defaultMovieCategories);
    } else if (widget.selectedCategory == 1) {
      _availableGenres = List.from(_defaultSeriesCategories);
    } else {
      _availableGenres = [];
    }
  }

  @override
  void didUpdateWidget(_LibraryContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      // Define categorias padrão imediatamente
      setState(() {
        _selectedGenre = null;
        _setDefaultGenres();
      });
      _loadAvailableGenres();
      _resetAndLoad();
    }
  }

  Future<void> _loadAvailableGenres() async {
    List<String> genres = [];
    if (widget.selectedCategory == 0) {
      // Filmes
      genres = await widget.baserowService.getMovieCategories();
    } else if (widget.selectedCategory == 1) {
      // Séries
      genres = await widget.baserowService.getSeriesCategoriesForLibrary();
    }
    // Só atualiza se tiver categorias do servidor
    if (mounted && genres.isNotEmpty) {
      setState(() => _availableGenres = genres);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetAndLoad() {
    setState(() {
      _movies = [];
      _tvShows = [];
      _currentPage = 1;
      _hasMore = true;
      _isLoading = true;
    });
    _loadContent();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastCategory != widget.selectedCategory) {
      _lastCategory = widget.selectedCategory;
      _resetAndLoad();
    }
  }

  Future<void> _loadContent() async {
    try {
      Map<String, dynamic> result;

      switch (widget.selectedCategory) {
        case 0: // Filmes
          result = await widget.baserowService.getAllMoviesPaginated(
            page: _currentPage,
            size: _pageSize,
            sortBy: _selectedSort,
            category: _selectedGenre,
          );
          _movies = List<Movie>.from(result['movies']);
          break;
        case 1: // Séries
          result = await widget.baserowService.getAllSeriesPaginated(
            page: _currentPage,
            size: _pageSize,
            sortBy: _selectedSort,
            category: _selectedGenre,
          );
          _tvShows = List<TVShow>.from(result['tvShows']);
          break;
        case 2: // Novelas
          result = await widget.baserowService.getNovelsPaginated(
            page: _currentPage,
            size: _pageSize,
          );
          _tvShows = List<TVShow>.from(result['tvShows']);
          break;
        case 3: // Animes
          result = await widget.baserowService.getAnimesPaginated(
            page: _currentPage,
            size: _pageSize,
          );
          _tvShows = List<TVShow>.from(result['tvShows']);
          break;
        default:
          result = {'hasNext': false, 'total': 0};
      }

      if (mounted) {
        setState(() {
          _hasMore = result['hasNext'] ?? false;
          _totalCount = result['total'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      Map<String, dynamic> result;

      switch (widget.selectedCategory) {
        case 0: // Filmes
          result = await widget.baserowService.getAllMoviesPaginated(
            page: _currentPage,
            size: _pageSize,
            sortBy: _selectedSort,
            category: _selectedGenre,
          );
          final newMovies = List<Movie>.from(result['movies']);
          setState(() => _movies.addAll(newMovies));
          break;
        case 1: // Séries
          result = await widget.baserowService.getAllSeriesPaginated(
            page: _currentPage,
            size: _pageSize,
            sortBy: _selectedSort,
            category: _selectedGenre,
          );
          final newSeries = List<TVShow>.from(result['tvShows']);
          setState(() => _tvShows.addAll(newSeries));
          break;
        case 2: // Novelas
          result = await widget.baserowService.getNovelsPaginated(
            page: _currentPage,
            size: _pageSize,
          );
          final newNovelas = List<TVShow>.from(result['tvShows']);
          setState(() => _tvShows.addAll(newNovelas));
          break;
        case 3: // Animes
          result = await widget.baserowService.getAnimesPaginated(
            page: _currentPage,
            size: _pageSize,
          );
          final newAnimes = List<TVShow>.from(result['tvShows']);
          setState(() => _tvShows.addAll(newAnimes));
          break;
        default:
          result = {'hasNext': false};
      }

      setState(() {
        _hasMore = result['hasNext'] ?? false;
        _isLoadingMore = false;
      });
    } catch (e) {
      _currentPage--;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isEmpty =
        widget.selectedCategory == 0 ? _movies.isEmpty : _tvShows.isEmpty;
    final itemCount =
        widget.selectedCategory == 0 ? _movies.length : _tvShows.length;

    // Mostrar filtros apenas para Filmes (0) e Séries (1)
    final showFilters =
        widget.selectedCategory == 0 || widget.selectedCategory == 1;

    if (isEmpty && _selectedGenre == null) {
      return _buildEmptyState();
    }

    // Se usa scroll externo (NestedScrollView)
    if (widget.useExternalScroll) {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
              _loadMore();
            }
          }
          return false;
        },
        child: Column(
          children: [
            // Filtros fixos no topo (não scrollam)
            if (showFilters) _buildFiltersRow(),
            // Grid que scrolla
            Expanded(
              child: isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: itemCount + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == itemCount) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (widget.selectedCategory == 0) {
                          return _buildMovieCard(_movies[index]);
                        } else {
                          return _buildTVShowCard(_tvShows[index]);
                        }
                      },
                    ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Espaço para os filtros flutuantes
            if (showFilters)
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            // Grid de conteúdo
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (widget.selectedCategory == 0) {
                      return _buildMovieCard(_movies[index]);
                    } else {
                      return _buildTVShowCard(_tvShows[index]);
                    }
                  },
                  childCount: itemCount,
                ),
              ),
            ),
            // Loading indicator
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
          ],
        ),
        // Filtros flutuantes no topo
        if (showFilters)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFiltersRow(),
          ),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(
              movieId: movie.id,
              posterPath: movie.posterPath,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: BaserowService.getImageUrl(movie.posterPath),
          fit: BoxFit.cover,
          memCacheWidth: 250,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(color: Colors.grey[850]),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: const Icon(Icons.movie, size: 40, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildTVShowCard(TVShow tvShow) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TVShowDetailScreen(
              tvShowId: tvShow.id,
              posterPath: tvShow.posterPath,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: BaserowService.getImageUrl(tvShow.posterPath),
          fit: BoxFit.cover,
          memCacheWidth: 250,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(color: Colors.grey[850]),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: const Icon(Icons.tv, size: 40, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.black,
      child: Row(
        children: [
          // Filtro de ordenação (esquerda)
          GestureDetector(
            onTap: _showSortPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF252836),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    _selectedSort,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Filtro de categoria (direita)
          if (_availableGenres.isNotEmpty)
            GestureDetector(
              onTap: _showGenrePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedGenre != null
                      ? const Color(0xFF12CDD9)
                      : const Color(0xFF252836),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list,
                        size: 18,
                        color:
                            _selectedGenre != null ? Colors.black : Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _selectedGenre ?? 'Categoria',
                      style: TextStyle(
                        color:
                            _selectedGenre != null ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down,
                        size: 18,
                        color:
                            _selectedGenre != null ? Colors.black : Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSortPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ordenar por',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ..._sortOptions.map((option) => ListTile(
                    leading: Icon(
                      _selectedSort == option
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: _selectedSort == option
                          ? const Color(0xFF12CDD9)
                          : Colors.grey,
                    ),
                    title: Text(
                      option,
                      style: TextStyle(
                        color: _selectedSort == option
                            ? const Color(0xFF12CDD9)
                            : Colors.white,
                        fontWeight: _selectedSort == option
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedSort = option);
                      Navigator.pop(context);
                      _resetAndLoad();
                    },
                  )),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showGenrePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filtrar por categoria',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Opção "Todas"
                      ListTile(
                        leading: Icon(
                          _selectedGenre == null
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _selectedGenre == null
                              ? const Color(0xFF12CDD9)
                              : Colors.grey,
                        ),
                        title: Text(
                          'Todas',
                          style: TextStyle(
                            color: _selectedGenre == null
                                ? const Color(0xFF12CDD9)
                                : Colors.white,
                            fontWeight: _selectedGenre == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedGenre = null);
                          Navigator.pop(context);
                          _resetAndLoad();
                        },
                      ),
                      ..._availableGenres.map((genre) => ListTile(
                            leading: Icon(
                              _selectedGenre == genre
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: _selectedGenre == genre
                                  ? const Color(0xFF12CDD9)
                                  : Colors.grey,
                            ),
                            title: Text(
                              genre,
                              style: TextStyle(
                                color: _selectedGenre == genre
                                    ? const Color(0xFF12CDD9)
                                    : Colors.white,
                                fontWeight: _selectedGenre == genre
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              setState(() => _selectedGenre = genre);
                              Navigator.pop(context);
                              _resetAndLoad();
                            },
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final categories = ['Filmes', 'Séries', 'Novelas', 'Animes'];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.selectedCategory == 0
                ? Icons.movie_outlined
                : widget.selectedCategory == 1
                    ? Icons.tv
                    : widget.selectedCategory == 2
                        ? Icons.live_tv
                        : Icons.animation,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum conteúdo em ${categories[widget.selectedCategory]}',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// Delegate para as categorias fixas
class _SliverCategoriesDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final int selectedIndex;
  final Function(int) onTap;

  _SliverCategoriesDelegate({
    required this.categories,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  double get minExtent => 55;

  @override
  double get maxExtent => 55;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(categories.length, (index) {
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onTap(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? const Color(0xFF12CDD9)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF12CDD9)
                        : Colors.grey[500],
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverCategoriesDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}
