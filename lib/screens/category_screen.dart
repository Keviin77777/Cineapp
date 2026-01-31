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
  final TextEditingController _searchController = TextEditingController();
  
  List<Movie> _movies = [];
  List<TVShow> _tvShows = [];
  List<Movie> _filteredMovies = [];
  List<TVShow> _filteredTVShows = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalCount = 0;
  static const int _pageSize = 30;
  String _sortBy = 'Recentes'; // 'Recentes', 'Mais vistos', 'A-Z', 'Z-A'
  bool _showFilterMenu = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (widget.categoryType == 'movie') {
        _filteredMovies = _movies.where((movie) {
          return movie.title.toLowerCase().contains(query);
        }).toList();
      } else {
        _filteredTVShows = _tvShows.where((show) {
          return show.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });

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

  void _changeSortOrder(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      _showFilterMenu = false;
    });
    _loadContent();
  }

  Future<void> _loadMovies() async {
    if (widget.genre != null) {
      final result = await _baserowService.getMoviesByGenrePaginated(
        widget.genre!,
        page: _currentPage,
        size: _pageSize,
      );
      _movies = List<Movie>.from(result['movies']);
      _applySortToMovies();
      _filteredMovies = List.from(_movies);
      _hasMore = result['hasNext'];
      _totalCount = result['total'] ?? _movies.length;
    } else if (widget.initialMovies != null) {
      _movies = widget.initialMovies!;
      _applySortToMovies();
      _filteredMovies = List.from(_movies);
      _hasMore = false;
      _totalCount = _movies.length;
    }
  }

  void _applySortToMovies() {
    switch (_sortBy) {
      case 'Mais vistos':
        _movies.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
        break;
      case 'A-Z':
        _movies.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Z-A':
        _movies.sort((a, b) => b.title.compareTo(a.title));
        break;
      case 'Recentes':
      default:
        _movies.sort((a, b) {
          final dateA = a.addedDate ?? '';
          final dateB = b.addedDate ?? '';
          return dateB.compareTo(dateA);
        });
        break;
    }
  }

  void _applySortToTVShows() {
    switch (_sortBy) {
      case 'Mais vistos':
        _tvShows.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
        break;
      case 'A-Z':
        _tvShows.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Z-A':
        _tvShows.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Recentes':
      default:
        // Mantém ordem padrão do Baserow (por data)
        break;
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
      _applySortToTVShows();
      _filteredTVShows = List.from(_tvShows);
      _hasMore = result['hasNext'];
      _totalCount = result['total'] ?? _tvShows.length;
    } else if (widget.initialTVShows != null) {
      _tvShows = widget.initialTVShows!;
      _applySortToTVShows();
      _filteredTVShows = List.from(_tvShows);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
            pinned: true,
            expandedHeight: 50,
            collapsedHeight: 170, // Reduzido de 180 para 170
            automaticallyImplyLeading: false,
            flexibleSpace: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 6), // Reduzido padding inferior
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botão de voltar + Título
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_totalCount > 0) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$_totalCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4), // Reduzido de 6 para 4
                  // Subtítulo
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      'Explore por categorias e gêneros',
                      style: TextStyle(
                        color: const Color(0xFFB0B3C6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10), // Reduzido de 12 para 10
                  // Barra de busca e filtro
                  Row(
                    children: [
                      // Campo de busca
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF151820),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Buscar ${widget.categoryType == 'movie' ? 'filmes' : 'séries'}...',
                              hintStyle: TextStyle(color: const Color(0xFF6F7385)),
                              prefixIcon: Icon(Icons.search, color: const Color(0xFF6F7385)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botão de filtro
                      GestureDetector(
                        onTap: () {
                          setState(() => _showFilterMenu = !_showFilterMenu);
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF151820),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: const Color(0xFFB0B3C6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Menu de filtros (se aberto) - aparece logo abaixo do header fixo
          if (_showFilterMenu)
            SliverPersistentHeader(
              pinned: false,
              delegate: _FilterMenuDelegate(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF151820),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterOption('Recentes', Icons.access_time),
                        _buildFilterOption('Mais vistos', Icons.visibility),
                        _buildFilterOption('A-Z', Icons.sort_by_alpha),
                        _buildFilterOption('Z-A', Icons.sort_by_alpha),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Conteúdo principal
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildSliverContent(),
        ],
      ),
    );
  }

  Widget _buildSliverContent() {
    if (widget.categoryType == 'movie') {
      return _buildSliverMovieGrid();
    } else if (widget.categoryType == 'tv') {
      return _buildSliverTVShowGrid();
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildSliverMovieGrid() {
    final displayMovies = _searchController.text.isEmpty ? _movies : _filteredMovies;
    
    if (displayMovies.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < displayMovies.length) {
              return _buildMovieCard(displayMovies[index]);
            } else if (_isLoadingMore) {
              return _buildLoadingIndicator();
            }
            return null;
          },
          childCount: displayMovies.length + (_isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildSliverTVShowGrid() {
    final displayShows = _searchController.text.isEmpty ? _tvShows : _filteredTVShows;
    
    if (displayShows.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < displayShows.length) {
              return _buildTVShowCard(displayShows[index]);
            } else if (_isLoadingMore) {
              return _buildLoadingIndicator();
            }
            return null;
          },
          childCount: displayShows.length + (_isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, IconData icon) {
    final isSelected = _sortBy == label;
    return InkWell(
      onTap: () => _changeSortOrder(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF1C2030)!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.primary : const Color(0xFFB0B3C6),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
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
            color: const Color(0xFF151820),
          ),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF151820),
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
            color: const Color(0xFF151820),
          ),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF151820),
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
            color: const Color(0xFF1C2030),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum conteúdo encontrado',
            style: TextStyle(
              color: const Color(0xFFB0B3C6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Delegate para o menu de filtros fixo
class _FilterMenuDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _FilterMenuDelegate({required this.child});

  @override
  double get minExtent => 194; // Ajustado para caber exatamente

  @override
  double get maxExtent => 194;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_FilterMenuDelegate oldDelegate) {
    return false;
  }
}










