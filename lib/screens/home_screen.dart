import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/baserow_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../models/profile.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/trending_carousel.dart';
import '../widgets/top10_card.dart';
import '../widgets/top10_tv_card.dart';
import '../widgets/home_skeleton_loading.dart';
import '../widgets/tv_show_card.dart';
import '../widgets/movie_card.dart';
import '../widgets/featured_card.dart';
import '../utils/page_transitions.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BaserowService _baserowService = BaserowService();
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
    _loadCurrentProfile();
    _loadAllData();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // Carregar todos os dados em paralelo
      final results = await Future.wait([
        _baserowService.getTrendingMovies(),
        _baserowService.getPopularMovies(),
        _baserowService.getTop10Movies(),
        _baserowService.getTop10TVShows(),
        _baserowService.getTrendingTVShows(),
      ]);

      if (mounted) {
        setState(() {
          _trendingMovies = results[0] as List<Movie>;
          _popularMovies = results[1] as List<Movie>;
          _top10Movies = results[2] as List<Movie>;
          _top10TVShows = results[3] as List<TVShow>;
          _trendingTVShows = results[4] as List<TVShow>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
              ? _buildFavoritesTab()
              : _buildProfileTab(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.favorite_border, 'Favoritos', 1),
              _buildNavItem(Icons.person_outline, 'Perfil', 2),
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
              children: List.generate(4, (_) => _buildCategoryContent()),
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

  Widget _buildCategoryContent() {
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
            _buildCategoriesSection(),
            const SizedBox(height: 30),
            if (_trendingMovies.isNotEmpty)
              TrendingCarousel(movies: _trendingMovies.take(10).toList()),
            const SizedBox(height: 30),
            if (_top10Movies.isNotEmpty)
              _buildTop10Section('Top 10 Filmes', _top10Movies),
            const SizedBox(height: 30),
            if (_popularMovies.isNotEmpty)
              _buildSection('Nos Cinemas', _popularMovies),
            const SizedBox(height: 30),
            if (_top10Movies.isNotEmpty || _top10TVShows.isNotEmpty)
              _buildExclusiveSection(),
            const SizedBox(height: 30),
            if (_top10TVShows.isNotEmpty)
              _buildTop10TVSection('Top 10 Séries', _top10TVShows),
            const SizedBox(height: 30),
            if (_trendingMovies.isNotEmpty)
              _buildSection('Mais Bem Avaliados', _trendingMovies),
            const SizedBox(height: 20),
            if (_trendingTVShows.isNotEmpty)
              _buildTVSection('Séries em Alta', _trendingTVShows),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {'name': 'Ação', 'icon': Icons.local_fire_department},
      {'name': 'Comédia', 'icon': Icons.theater_comedy},
      {'name': 'Terror', 'icon': Icons.sentiment_very_dissatisfied},
      {'name': 'Romance', 'icon': Icons.favorite},
      {'name': 'Fantasia', 'icon': Icons.auto_awesome},
      {'name': 'Ficção', 'icon': Icons.rocket_launch},
    ];

    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            margin: const EdgeInsets.only(right: 5),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(category['icon'] as IconData, size: 20),
              label: Text(
                category['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExclusiveSection() {
    // Mistura filmes e séries sem duplicados
    final List<Widget> cards = [];
    final Set<int> usedMovieIds = {};
    final Set<int> usedTVShowIds = {};
    
    // Adiciona alguns filmes do top 10 (com badge)
    for (final movie in _top10Movies.take(3)) {
      if (!usedMovieIds.contains(movie.id)) {
        usedMovieIds.add(movie.id);
        cards.add(FeaturedMovieCard(movie: movie, showTop10Badge: true));
      }
    }
    
    // Adiciona algumas séries do top 10 (com badge)
    for (final tvShow in _top10TVShows.take(3)) {
      if (!usedTVShowIds.contains(tvShow.id)) {
        usedTVShowIds.add(tvShow.id);
        cards.add(FeaturedTVShowCard(tvShow: tvShow, showTop10Badge: true));
      }
    }
    
    // Adiciona filmes populares (sem badge) - evita duplicados
    for (final movie in _popularMovies.take(4)) {
      if (!usedMovieIds.contains(movie.id)) {
        usedMovieIds.add(movie.id);
        cards.add(FeaturedMovieCard(movie: movie, showTop10Badge: false));
        if (cards.where((c) => c is FeaturedMovieCard && !(c as FeaturedMovieCard).showTop10Badge).length >= 2) break;
      }
    }
    
    // Adiciona séries em alta (sem badge) - evita duplicados
    for (final tvShow in _trendingTVShows.take(4)) {
      if (!usedTVShowIds.contains(tvShow.id)) {
        usedTVShowIds.add(tvShow.id);
        cards.add(FeaturedTVShowCard(tvShow: tvShow, showTop10Badge: false));
        if (cards.where((c) => c is FeaturedTVShowCard && !(c as FeaturedTVShowCard).showTop10Badge).length >= 2) break;
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
                'Exclusivos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 364,
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

  Widget _buildFavoritesTab() {
    return Container(
      color: Colors.black,
      child: const Center(child: Text('Favoritos')),
    );
  }

  Widget _buildProfileTab() {
    return Container(
      color: Colors.black,
      child: const Center(child: Text('Perfil')),
    );
  }
}