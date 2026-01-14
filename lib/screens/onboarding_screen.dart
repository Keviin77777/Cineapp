import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login_screen.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';

class OnboardingScreen extends StatefulWidget {
  final List<Movie>? preloadedMovies;
  final List<TVShow>? preloadedTVShows;
  
  const OnboardingScreen({
    super.key,
    this.preloadedMovies,
    this.preloadedTVShows,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TMDBService _tmdbService = TMDBService();
  int _currentPage = 0;
  
  List<Movie>? _trendingMovies;
  List<TVShow>? _trendingTVShows;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initContent();
  }

  void _initContent() {
    // Usar dados pré-carregados se disponíveis
    if (widget.preloadedMovies != null && widget.preloadedTVShows != null) {
      setState(() {
        _trendingMovies = widget.preloadedMovies!.take(6).toList();
        _trendingTVShows = widget.preloadedTVShows!.take(6).toList();
        _isLoading = false;
      });
    } else {
      _loadTrendingContent();
    }
  }

  Future<void> _loadTrendingContent() async {
    try {
      final movies = await _tmdbService.getTrendingMovies();
      final tvShows = await _tmdbService.getTrendingTVShows();
      
      if (mounted) {
        setState(() {
          _trendingMovies = movies.take(6).toList();
          _trendingTVShows = tvShows.take(6).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<OnboardingPage> get _pages => [
    OnboardingPage(
      title: 'Descubra Filmes\nIncríveis',
      description: 'Explore milhares de filmes de todos os gêneros',
      gradient: [Color(0xFF12CDD9), Color(0xFF1F4068)],
      type: OnboardingType.movies,
    ),
    OnboardingPage(
      title: 'Séries para\nMaratonar',
      description: 'Encontre as melhores séries para assistir',
      gradient: [Color(0xFFFF8700), Color(0xFFE85D04)],
      type: OnboardingType.tvShows,
    ),
    OnboardingPage(
      title: 'Avaliações e\nRecomendações',
      description: 'Veja avaliações e descubra novos conteúdos',
      gradient: [Color(0xFFB5179E), Color(0xFF7209B7)],
      type: OnboardingType.mixed,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Status bar transparente
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // PageView com fundo em tela cheia
          _isLoading
              ? Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
          // Header com botão pular
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Pular',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 16,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Footer com indicador e botão
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLoading)
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: _pages.length,
                        effect: ExpandingDotsEffect(
                          activeDotColor: Theme.of(context).colorScheme.primary,
                          dotColor: Colors.grey[700]!,
                          dotHeight: 8,
                          dotWidth: 8,
                          expansionFactor: 4,
                        ),
                      ),
                    if (_isLoading)
                      const SizedBox(height: 8),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          if (_currentPage < _pages.length - 1) {
                            if (_pageController.hasClients) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          } else {
                            _completeOnboarding();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? 'Próximo'
                              : 'Começar',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    List<String> posterPaths = [];
    String? backdropPath;
    
    if (page.type == OnboardingType.movies && _trendingMovies != null) {
      posterPaths = _trendingMovies!
          .where((m) => m.posterPath != null)
          .map((m) => m.posterPath!)
          .toList();
      backdropPath = _trendingMovies!.firstWhere(
        (m) => m.backdropPath != null,
        orElse: () => _trendingMovies!.first,
      ).backdropPath;
    } else if (page.type == OnboardingType.tvShows && _trendingTVShows != null) {
      posterPaths = _trendingTVShows!
          .where((tv) => tv.posterPath != null)
          .map((tv) => tv.posterPath!)
          .toList();
      backdropPath = _trendingTVShows!.firstWhere(
        (tv) => tv.backdropPath != null,
        orElse: () => _trendingTVShows!.first,
      ).backdropPath;
    } else if (page.type == OnboardingType.mixed) {
      if (_trendingMovies != null && _trendingTVShows != null) {
        posterPaths = [
          ..._trendingMovies!.take(3).where((m) => m.posterPath != null).map((m) => m.posterPath!),
          ..._trendingTVShows!.take(3).where((tv) => tv.posterPath != null).map((tv) => tv.posterPath!),
        ];
        backdropPath = _trendingMovies!.firstWhere(
          (m) => m.backdropPath != null,
          orElse: () => _trendingMovies!.first,
        ).backdropPath;
      }
    }

    return Stack(
      children: [
        // Background com imagem em alta qualidade
        if (backdropPath != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: TMDBService.getOriginalImageUrl(backdropPath),
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) => Container(
                color: Colors.black,
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
              ),
            ),
          ),
        // Blur para dar foco no conteúdo
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // Conteúdo
        Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPosterGrid(posterPaths, page.gradient),
              const SizedBox(height: 60),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[100],
                  height: 1.5,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPosterGrid(List<String> posterPaths, List<Color> gradient) {
    if (posterPaths.isEmpty) {
      return Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.movie_outlined,
          size: 100,
          color: Colors.white,
        ),
      );
    }

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        children: [
          // Poster 1 - Top Left
          Positioned(
            top: 0,
            left: 20,
            child: _buildPosterCard(posterPaths[0], 100, 140, 0.1, gradient),
          ),
          // Poster 2 - Top Right
          if (posterPaths.length > 1)
            Positioned(
              top: 20,
              right: 0,
              child: _buildPosterCard(posterPaths[1], 90, 130, -0.05, gradient),
            ),
          // Poster 3 - Center (Destaque)
          if (posterPaths.length > 2)
            Positioned(
              top: 60,
              left: 80,
              child: _buildPosterCard(posterPaths[2], 120, 170, 0, gradient, isMain: true),
            ),
          // Poster 4 - Bottom Left
          if (posterPaths.length > 3)
            Positioned(
              bottom: 20,
              left: 0,
              child: _buildPosterCard(posterPaths[3], 85, 120, 0.08, gradient),
            ),
          // Poster 5 - Bottom Right
          if (posterPaths.length > 4)
            Positioned(
              bottom: 0,
              right: 30,
              child: _buildPosterCard(posterPaths[4], 95, 135, -0.1, gradient),
            ),
        ],
      ),
    );
  }

  Widget _buildPosterCard(String posterPath, double width, double height, double rotation, List<Color> gradient, {bool isMain = false}) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: isMain ? 25 : 15,
              spreadRadius: isMain ? 3 : 1,
            ),
            if (isMain)
              BoxShadow(
                color: gradient[0].withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: TMDBService.getImageUrl(posterPath),
                fit: BoxFit.cover,
                width: width,
                height: height,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                ),
              ),
              // Borda com gradiente sutil
              if (isMain)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: gradient[0].withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum OnboardingType { movies, tvShows, mixed }

class OnboardingPage {
  final String title;
  final String description;
  final List<Color> gradient;
  final OnboardingType type;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.gradient,
    required this.type,
  });
}
