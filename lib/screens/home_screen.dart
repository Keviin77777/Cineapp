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
            // Tendências em Filmes
            if (_trendingMovies.isNotEmpty) ...[
              _buildMovieSection('Em Alta', _trendingMovies),
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
              _buildTVSection('Últimas Séries', _trendingTVShows),
              const SizedBox(height: 30),
            ],
            // Novelas
            if (_novelas.isNotEmpty) ...[
              _buildTVSection('Novelas', _novelas),
              const SizedBox(height: 30),
            ],
            // Séries Disney+
            if (_seriesDisney.isNotEmpty) ...[
              _buildTVSection('Séries Disney+', _seriesDisney),
              const SizedBox(height: 30),
            ],
            // Séries Netflix
            if (_seriesNetflix.isNotEmpty) ...[
              _buildTVSection('Séries Netflix', _seriesNetflix),
              const SizedBox(height: 30),
            ],
            // Séries GloboPlay
            if (_seriesGloboPlay.isNotEmpty) ...[
              _buildTVSection('Séries GloboPlay', _seriesGloboPlay),
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
        sections.add(_buildTVSection(category, shows));
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
          sections.add(_buildTVSection('Últimas Séries', _trendingTVShows));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Escolhidos para você') {
        sections.add(_buildPickedForYouSection());
        sections.add(const SizedBox(height: 30));
      } else if (categoryName == 'Novelas') {
        if (_novelas.isNotEmpty) {
          sections.add(_buildTVSection('Novelas', _novelas));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Séries Disney+') {
        if (_seriesDisney.isNotEmpty) {
          sections.add(_buildTVSection('Séries Disney+', _seriesDisney));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Séries Netflix') {
        if (_seriesNetflix.isNotEmpty) {
          sections.add(_buildTVSection('Séries Netflix', _seriesNetflix));
          sections.add(const SizedBox(height: 30));
        }
      } else if (categoryName == 'Séries GloboPlay') {
        if (_seriesGloboPlay.isNotEmpty) {
          sections.add(_buildTVSection('Séries GloboPlay', _seriesGloboPlay));
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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

  Widget _buildTVSection(String title, List<TVShow> tvShows) {
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
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
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Biblioteca',
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
                    Icon(Icons.dashboard_outlined, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Sua biblioteca está vazia',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Baixe filmes e séries para assistir offline',
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
