import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../services/watch_progress_service.dart';
import '../services/favorites_service.dart';
import '../models/movie.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/movie_card.dart';
import 'video_player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final String? posterPath;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.posterPath,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final BaserowService _baserowService = BaserowService();
  final WatchProgressService _watchProgressService = WatchProgressService();
  final FavoritesService _favoritesService = FavoritesService();
  Movie? _movie;
  Map<String, dynamic>? _tmdbData;
  List<Movie> _relatedMovies = [];
  WatchProgress? _watchProgress;
  bool _isLoading = true;
  bool _isLoadingRelated = true;
  bool _isOverviewExpanded = false;
  bool _isFavorite = false;
  bool _isInMyList = false;

  @override
  void initState() {
    super.initState();
    // Configurar status bar transparente
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadMovieDetails();
    _loadWatchProgress();
    _loadFavoritesStatus();
  }

  Future<void> _loadFavoritesStatus() async {
    final isFav = await _favoritesService.isFavorite(widget.movieId, 'movie');
    final isInList = await _favoritesService.isInMyList(widget.movieId, 'movie');
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isInMyList = isInList;
      });
    }
  }

  Future<void> _loadWatchProgress() async {
    final progress = await _watchProgressService.getProgress(widget.movieId);
    if (mounted) {
      setState(() => _watchProgress = progress);
    }
  }

  @override
  void dispose() {
    // Restaurar status bar ao sair
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  Future<void> _loadMovieDetails() async {
    try {
      // Carregar dados principais primeiro
      final movie = await _baserowService.getEnhancedMovieDetails(widget.movieId);
      if (movie != null && mounted) {
        setState(() {
          _movie = movie;
          _isLoading = false; // Mostra a tela assim que tiver os dados principais
        });
        
        // Carregar elenco e relacionados em paralelo (background)
        _loadSecondaryData(movie);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Erro ao carregar detalhes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSecondaryData(Movie movie) async {
    // Carregar elenco e relacionados em paralelo
    final futures = <Future>[];
    
    // Elenco do TMDB
    if (movie.tmdbId != null && movie.tmdbId! > 0) {
      futures.add(_baserowService.getTMDBDetails(movie.tmdbId!, 'movie').then((data) {
        if (mounted) setState(() => _tmdbData = data);
      }));
    }
    
    // Filmes relacionados do Baserow
    futures.add(_baserowService.getRelatedMovies(movie.categories ?? '', movie.id).then((related) {
      if (mounted) {
        setState(() {
          _relatedMovies = related;
          _isLoadingRelated = false;
        });
      }
    }));
    
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const SkeletonLoading()
          : _movie == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Erro ao carregar detalhes', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCastSection(),
              const SizedBox(height: 24),
              _buildRelatedSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
        _buildAppBar(),
      ],
    );
  }

  Widget _buildHeader() {
    // Priorizar poster/backdrop original do TMDB
    String? imageUrl;
    
    // Primeiro tenta pegar o original do TMDB (da lista de images)
    if (_tmdbData != null) {
      final originalBackdrop = _tmdbData!['original_backdrop_path'] as String?;
      final originalPoster = _tmdbData!['original_poster_path'] as String?;
      final tmdbBackdrop = _tmdbData!['backdrop_path'] as String?;
      final tmdbPoster = _tmdbData!['poster_path'] as String?;
      
      // Prioridade: backdrop original > backdrop padrão > poster original > poster padrão
      imageUrl = originalBackdrop ?? tmdbBackdrop ?? originalPoster ?? tmdbPoster;
    }
    
    // Se não tem do TMDB, usa do Baserow
    imageUrl ??= _movie!.backdropPath ?? _movie!.posterPath;
    
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final overview = _movie!.overview;

    return SizedBox(
      height: 650,
      child: Stack(
        children: [
          // Imagem de fundo com melhor qualidade - vai até o topo
          Positioned.fill(
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: _getHighQualityImageUrl(imageUrl),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF151820),
                      child: const Icon(Icons.movie, size: 80, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: const Color(0xFF151820),
                    child: const Center(child: Icon(Icons.movie, size: 80, color: Colors.grey)),
                  ),
          ),
          // Overlay
          Positioned.fill(
            child: Container(color: const Color(0xFF0E0F12).withOpacity(0.25)),
          ),
          // Gradiente
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 450,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0E0F12).withOpacity(0.5),
                    const Color(0xFF0E0F12).withOpacity(0.85),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Informações
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título centralizado
                  Text(
                    _movie!.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Ano, Gênero e Duração
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_movie!.releaseDate.isNotEmpty)
                        Text(
                          _movie!.releaseDate.split('-')[0],
                          style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 14),
                        ),
                      if (_movie!.categories != null && _movie!.categories!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: BoxDecoration(color: const Color(0xFFB0B3C6), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          _movie!.categories!.split(',').first.trim(),
                          style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 14),
                        ),
                      ],
                      if (_movie!.duration != null && _movie!.duration!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: BoxDecoration(color: const Color(0xFFB0B3C6), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_movie!.duration),
                          style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Sinopse compacta
                  if (overview.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        if (overview.length > 100) {
                          setState(() => _isOverviewExpanded = !_isOverviewExpanded);
                        }
                      },
                      child: Text(
                        overview,
                        style: TextStyle(
                          color: const Color(0xFFB0B3C6),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: _isOverviewExpanded ? null : 2,
                        overflow: _isOverviewExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Botões de ação
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final streamUrl = _movie!.streamUrl;
                            if (streamUrl != null && streamUrl.isNotEmpty) {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(
                                    videoUrl: streamUrl,
                                    title: _movie!.title,
                                    category: _movie!.categories?.split(',').first.trim(),
                                    contentId: _movie!.id,
                                    posterPath: _movie!.posterPath,
                                    backdropPath: _movie!.backdropPath,
                                    type: 'movie',
                                    startPositionMs: _watchProgress?.positionMs,
                                  ),
                                ),
                              );
                              // Recarrega o progresso ao voltar
                              _loadWatchProgress();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link do filme não disponível'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow, size: 22),
                          label: Text(
                            _watchProgress != null ? 'Continuar' : 'Assistir',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 3,
                            shadowColor: const Color(0xFFC62828).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF151820)?.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () async {
                            await _favoritesService.toggleMyList(widget.movieId, 'movie');
                            final isInList = await _favoritesService.isInMyList(widget.movieId, 'movie');
                            setState(() => _isInMyList = isInList);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isInList ? 'Adicionado à Minha Lista' : 'Removido da Minha Lista'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            _isInMyList ? Icons.bookmark : Icons.bookmark_border,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF151820)?.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () async {
                            await _favoritesService.toggleFavorite(widget.movieId, 'movie');
                            final isFav = await _favoritesService.isFavorite(widget.movieId, 'movie');
                            setState(() => _isFavorite = isFav);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isFav ? 'Adicionado aos Favoritos' : 'Removido dos Favoritos'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  String _formatDuration(String? duration) {
    if (duration == null || duration.isEmpty) return '';
    
    // Tenta converter para número (minutos)
    final minutes = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), ''));
    if (minutes == null) return duration;
    
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${mins}min';
    }
    return '${mins}min';
  }

  String _getHighQualityImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/1280x720/1F1D2B/FFFFFF?text=Sem+Imagem';
    }
    
    // Se já é uma URL completa, retorna como está
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    
    // Se é um path do TMDB, usar qualidade original para backdrop
    if (imagePath.startsWith('/')) {
      return 'https://image.tmdb.org/t/p/original$imagePath'; // Qualidade máxima
    }
    
    return imagePath;
  }

  Widget _buildCastSection() {
    final credits = _tmdbData?['credits'] as Map<String, dynamic>?;
    final cast = credits?['cast'] as List? ?? [];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Elenco',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: cast.isEmpty
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    itemBuilder: (context, index) => Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFF151820),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF151820),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 10,
                            width: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF151820),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: cast.take(10).length,
                    itemBuilder: (context, index) {
                      final actor = cast[index];
                      final profilePath = actor['profile_path'] as String?;
                      final name = actor['name'] as String? ?? '';
                      final character = actor['character'] as String? ?? '';
                      final hasImage = profilePath != null && profilePath.isNotEmpty;
                      
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                color: const Color(0xFF151820),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(35),
                                child: hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: 'https://image.tmdb.org/t/p/w200$profilePath',
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => 
                                            const Icon(Icons.person, size: 30, color: Colors.grey),
                                      )
                                    : const Icon(Icons.person, size: 30, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              character,
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFFB0B3C6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Relacionados',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: const Color(0xFFB0B3C6),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 175,
            child: _isLoadingRelated
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (context, index) => Container(
                      width: 125,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151820),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                : _relatedMovies.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum filme relacionado encontrado',
                          style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _relatedMovies.take(10).length,
                        itemBuilder: (context, index) {
                          return MovieCard(
                            movie: _relatedMovies[index],
                            replaceRoute: true,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0E0F12).withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}





