import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../services/baserow_service.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String title;
  final String categoryType; // 'movie', 'tv'
  final String? genre; // Para filmes por gênero
  final String? tvCategory; // Para séries por categoria (Netflix, Disney, etc)
  final List<Movie>? initialMovies;
  final List<TVShow>? initialTVShows;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.categoryType,
    this.genre,
    this.tvCategory,
    this.initialMovies,
    this.initialTVShows,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final BaserowService _baserowService = BaserowService();
  final ScrollController _scrollController = ScrollController();
  
  List<Movie> _movies = [];
  List<TVShow> _tvShows = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalCount = 0;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);

    try {
      if (widget.categoryType == 'movie') {
        await _loadMovies();
      } else if (widget.categoryType == 'tv') {
        await _loadTVShows();
      }
    } catch (e) {
      print('Erro ao carregar conteúdo: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMovies() async {
    if (widget.genre != null) {
      final result = await _baserowService.getMoviesByGenrePaginated(
        widget.genre!,
        page: _currentPage,
        size: _pageSize,
      );
      _movies = List<Movie>.from(result['movies']);
      _hasMore = result['hasNext'];
      _totalCount = result['total'] ?? _movies.length;
    } else if (widget.initialMovies != null) {
      _movies = widget.initialMovies!;
      _hasMore = false;
      _totalCount = _movies.length;
    }
  }

  Future<void> _loadTVShows() async {
    if (widget.tvCategory != null) {
      Map<String, dynamic> result;
      if (widget.tvCategory == 'Novelas') {
        result = await _baserowService.getNovelsPaginated(
          page: _currentPage,
          size: _pageSize,
        );
      } else {
        result = await _baserowService.getTVShowsByCategoryPaginated(
          widget.tvCategory!,
          page: _currentPage,
          size: _pageSize,
        );
      }
      _tvShows = List<TVShow>.from(result['tvShows']);
      _hasMore = result['hasNext'];
      _totalCount = result['total'] ?? _tvShows.length;
    } else if (widget.initialTVShows != null) {
      _tvShows = widget.initialTVShows!;
      _hasMore = false;
      _totalCount = _tvShows.length;
    }
  }


  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      if (widget.categoryType == 'movie' && widget.genre != null) {
        final result = await _baserowService.getMoviesByGenrePaginated(
          widget.genre!,
          page: _currentPage,
          size: _pageSize,
        );
        final newMovies = List<Movie>.from(result['movies']);
        setState(() {
          _movies.addAll(newMovies);
          _hasMore = result['hasNext'];
        });
      } else if (widget.categoryType == 'tv' && widget.tvCategory != null) {
        Map<String, dynamic> result;
        if (widget.tvCategory == 'Novelas') {
          result = await _baserowService.getNovelsPaginated(
            page: _currentPage,
            size: _pageSize,
          );
        } else {
          result = await _baserowService.getTVShowsByCategoryPaginated(
            widget.tvCategory!,
            page: _currentPage,
            size: _pageSize,
          );
        }
        final newTVShows = List<TVShow>.from(result['tvShows']);
        setState(() {
          _tvShows.addAll(newTVShows);
          _hasMore = result['hasNext'];
        });
      }
    } catch (e) {
      print('Erro ao carregar mais: $e');
      _currentPage--;
    }

    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_totalCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalCount',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.categoryType == 'movie') {
      return _buildMovieGrid();
    } else if (widget.categoryType == 'tv') {
      return _buildTVShowGrid();
    }
    return const SizedBox.shrink();
  }

  Widget _buildMovieGrid() {
    if (_movies.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _movies.length,
              itemBuilder: (context, index) {
                return _buildMovieCard(_movies[index]);
              },
            ),
          ),
        ),
        if (_isLoadingMore) _buildLoadingIndicator(),
      ],
    );
  }

  Widget _buildTVShowGrid() {
    if (_tvShows.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _tvShows.length,
              itemBuilder: (context, index) {
                return _buildTVShowCard(_tvShows[index]);
              },
            ),
          ),
        ),
        if (_isLoadingMore) _buildLoadingIndicator(),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
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
          fadeOutDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            color: Colors.grey[850],
          ),
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
          fadeOutDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            color: Colors.grey[850],
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: const Icon(Icons.tv, size: 40, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.categoryType == 'movie' ? Icons.movie_outlined : Icons.tv,
            size: 64,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum conteúdo encontrado',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
