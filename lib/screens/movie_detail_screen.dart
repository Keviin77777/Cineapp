import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../models/movie.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/movie_card.dart';

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
  Movie? _movie;
  Map<String, dynamic>? _tmdbData;
  List<Movie> _relatedMovies = [];
  bool _isLoading = true;
  bool _isLoadingRelated = true;
  bool _isOverviewExpanded = false;

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
      backgroundColor: Colors.black,
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
    // Priorizar backdrop do TMDB para o header (melhor qualidade)
    final imageUrl = _movie!.backdropPath ?? _movie!.posterPath;
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
                      color: Colors.grey[900],
                      child: const Icon(Icons.movie, size: 80, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Center(child: Icon(Icons.movie, size: 80, color: Colors.grey)),
                  ),
          ),
          // Overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
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
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.85),
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
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      if (_movie!.categories != null && _movie!.categories!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          _movie!.categories!.split(',').first.trim(),
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                      if (_movie!.duration != null && _movie!.duration!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          _movie!.duration!,
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                          color: Colors.grey[300],
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
                          onPressed: () {
                            // TODO: Abrir player com streamUrl
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Assistir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800]?.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.list_alt, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800]?.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.favorite_border, color: Colors.white),
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
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 10,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
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
                                color: Colors.grey[800],
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
                                color: Colors.grey[400],
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
                color: Colors.grey[400],
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
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                : _relatedMovies.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum filme relacionado encontrado',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _relatedMovies.take(10).length,
                        itemBuilder: (context, index) {
                          return MovieCard(movie: _relatedMovies[index]);
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
              Colors.black.withOpacity(0.6),
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
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}