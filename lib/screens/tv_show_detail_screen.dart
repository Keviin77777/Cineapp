import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../services/watch_progress_service.dart';
import '../models/tv_show.dart';
import '../widgets/skeleton_loading.dart';
import 'video_player_screen.dart';

class TVShowDetailScreen extends StatefulWidget {
  final int tvShowId;
  final String? posterPath;

  const TVShowDetailScreen({
    super.key,
    required this.tvShowId,
    this.posterPath,
  });

  @override
  State<TVShowDetailScreen> createState() => _TVShowDetailScreenState();
}

class _TVShowDetailScreenState extends State<TVShowDetailScreen> {
  final BaserowService _baserowService = BaserowService();
  final WatchProgressService _watchProgressService = WatchProgressService();
  TVShow? _tvShow;
  Map<String, dynamic>? _tmdbData;
  List<TVShow> _relatedTVShows = [];
  Map<int, List<Map<String, dynamic>>> _episodesBySeason = {};
  bool _isLoading = true;
  bool _isLoadingEpisodes = true;
  bool _isLoadingRelated = true;
  bool _isOverviewExpanded = false;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _loadTVShowDetails();
  }

  Future<void> _loadTVShowDetails() async {
    try {
      // Carregar apenas os dados básicos da série primeiro
      final tvShow = await _baserowService.getTVShowDetails(widget.tvShowId);
      
      if (tvShow != null && mounted) {
        setState(() {
          _tvShow = tvShow;
          _isLoading = false;
        });
        
        // Carregar episódios em background
        _loadEpisodes(tvShow);
        
        // Carregar dados secundários em background
        _loadSecondaryData(tvShow);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEpisodes(TVShow tvShow) async {
    try {
      print('Carregando episódios para série ID: ${widget.tvShowId}, Nome: ${tvShow.name}');
      
      // Carregar episódios do Baserow
      final baserowEpisodes = await _baserowService.getEpisodes(widget.tvShowId);
      
      print('Episódios recebidos do Baserow: ${baserowEpisodes.length}');
      
      // Agrupar por temporada
      final Map<int, List<Map<String, dynamic>>> episodesBySeason = {};
      for (final ep in baserowEpisodes) {
        final season = ep['temporada'] as int? ?? 1;
        final epNumber = ep['episodio'] as int? ?? 1;
        
        // Adicionar dados do Baserow com fallback
        episodesBySeason.putIfAbsent(season, () => []).add({
          ...ep,
          'name': ep['nome'] ?? 'Episódio $epNumber',
          'overview': '',
          'still_path': null,
        });
      }
      
      print('Temporadas encontradas: ${episodesBySeason.keys.toList()}');
      
      // Definir temporada inicial
      final seasons = episodesBySeason.keys.toList()..sort();
      final initialSeason = seasons.isNotEmpty ? seasons.first : 1;
      
      if (mounted) {
        setState(() {
          _episodesBySeason = episodesBySeason;
          _selectedSeason = initialSeason;
          _isLoadingEpisodes = false;
        });
      }
      
      // Carregar dados do TMDB para complementar episódios em background
      if (tvShow.tmdbId != null && tvShow.tmdbId! > 0) {
        for (final season in seasons) {
          try {
            final tmdbEpisodes = await _baserowService.getTMDBSeasonEpisodes(
              tvShow.tmdbId!,
              season,
            );
            
            // Se TMDB retornou episódios, complementar com os dados
            if (tmdbEpisodes.isNotEmpty) {
              final seasonEps = episodesBySeason[season] ?? [];
              for (int i = 0; i < seasonEps.length; i++) {
                final epNumber = seasonEps[i]['episodio'] as int? ?? (i + 1);
                final tmdbEp = tmdbEpisodes.firstWhere(
                  (t) => t['episode_number'] == epNumber,
                  orElse: () => <String, dynamic>{},
                );
                
                // Usar dados do TMDB se disponíveis, senão manter do Baserow
                seasonEps[i] = {
                  ...seasonEps[i],
                  'still_path': tmdbEp['still_path'],
                  'overview': tmdbEp['overview'] ?? seasonEps[i]['overview'] ?? '',
                  'name': tmdbEp['name'] ?? seasonEps[i]['name'] ?? 'Episódio $epNumber',
                };
              }
              
              // Atualizar UI após cada temporada
              if (mounted) {
                setState(() {
                  _episodesBySeason = episodesBySeason;
                });
              }
            }
          } catch (e) {
            // Ignora erro do TMDB, mantém dados do Baserow
            print('Erro ao carregar episódios do TMDB para temporada $season: $e');
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar episódios: $e');
      if (mounted) {
        setState(() => _isLoadingEpisodes = false);
      }
    }
  }

  Future<void> _loadSecondaryData(TVShow tvShow) async {
    // Elenco do TMDB
    if (tvShow.tmdbId != null && tvShow.tmdbId! > 0) {
      final tmdbData = await _baserowService.getTMDBDetails(tvShow.tmdbId!, 'tv');
      if (mounted) setState(() => _tmdbData = tmdbData);
    }
    
    // Séries relacionadas
    final related = await _baserowService.getRelatedTVShows(tvShow.categories ?? '', tvShow.id);
    if (mounted) {
      setState(() {
        _relatedTVShows = related;
        _isLoadingRelated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const SkeletonLoading()
          : _tvShow == null
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
              _buildEpisodesSection(),
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
    imageUrl ??= _tvShow!.backdropPath ?? _tvShow!.posterPath;
    
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final overview = _tvShow!.overview;

    return SizedBox(
      height: 650,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: _getHighQualityImageUrl(imageUrl),
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.tv, size: 80, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Center(child: Icon(Icons.tv, size: 80, color: Colors.grey)),
                  ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
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
                    _tvShow!.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Ano, Gênero e Temporadas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_tvShow!.firstAirDate.isNotEmpty)
                        Text(
                          _tvShow!.firstAirDate.split('-')[0],
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      if (_tvShow!.categories != null && _tvShow!.categories!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          _tvShow!.categories!.split(',').first.trim(),
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                      if (_tvShow!.seasons != null && _tvShow!.seasons! > 0) ...[
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          '${_tvShow!.seasons} Temp.',
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
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
    if (imagePath.startsWith('http')) return imagePath;
    if (imagePath.startsWith('/')) {
      return 'https://image.tmdb.org/t/p/original$imagePath';
    }
    return imagePath;
  }

  Widget _buildEpisodesSection() {
    // Sempre mostrar a seção, mesmo durante o carregamento
    final seasons = _episodesBySeason.keys.toList()..sort();
    final currentEpisodes = _episodesBySeason[_selectedSeason] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título da seção
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 12),
          child: Text(
            'Episódios',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Botão seletor de temporada (só mostra se tiver temporadas)
        if (seasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: GestureDetector(
              onTap: () => _showSeasonPicker(seasons),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[700]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Temporada $_selectedSeason',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Lista horizontal de episódios
        SizedBox(
          height: 200,
          child: _isLoadingEpisodes
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 3,
                  itemBuilder: (context, index) => Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 10,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : currentEpisodes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Nenhum episódio disponível',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: currentEpisodes.length,
                      itemBuilder: (context, index) {
                        final ep = currentEpisodes[index];
                        final epNumber = ep['episodio'] ?? (index + 1);
                        return _buildEpisodeCard(ep, epNumber);
                      },
                    ),
        ),
      ],
    );
  }

  void _showSeasonPicker(List<int> seasons) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
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
                'Selecionar Temporada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...seasons.map((season) => ListTile(
                leading: Icon(
                  _selectedSeason == season ? Icons.check_circle : Icons.circle_outlined,
                  color: _selectedSeason == season ? const Color(0xFF12CDD9) : Colors.grey,
                ),
                title: Text(
                  'Temporada $season',
                  style: TextStyle(
                    color: _selectedSeason == season ? const Color(0xFF12CDD9) : Colors.white,
                    fontWeight: _selectedSeason == season ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedSeason = season);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEpisodeCard(Map<String, dynamic> episode, int episodeNumber) {
    final stillPath = episode['still_path'] as String?;
    final overview = episode['overview'] as String? ?? '';
    final name = episode['name'] as String? ?? 'Episódio $episodeNumber';
    final link = episode['link'] as String? ?? '';
    
    // Usar still_path do TMDB, ou backdrop da série como fallback
    final imageUrl = stillPath != null && stillPath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$stillPath'
        : _tvShow?.backdropPath != null && _tvShow!.backdropPath!.isNotEmpty
            ? BaserowService.getImageUrl(_tvShow!.backdropPath)
            : null;
    
    return GestureDetector(
      onTap: () async {
        if (link.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                videoUrl: link,
                title: _tvShow?.name ?? 'Série',
                episodeNumber: episodeNumber,
                seasonNumber: _selectedSeason,
                contentId: _tvShow?.id,
                tmdbId: _tvShow?.tmdbId,
                posterPath: _tvShow?.posterPath,
                backdropPath: stillPath ?? _tvShow?.backdropPath,
                type: 'tv',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link do episódio não disponível'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail do episódio
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.play_circle_outline, size: 40, color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.play_circle_outline, size: 40, color: Colors.white54),
                            ),
                          ),
                  ),
                  // Overlay com play
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_filled, size: 45, color: Colors.white),
                      ),
                    ),
                  ),
                  // Número do episódio no canto
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Text(
                      '$episodeNumber. $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Sinopse do episódio
            Text(
              overview.isNotEmpty ? overview : 'Sem descrição disponível',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
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
              Text(
                'Ver Todos',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: _isLoadingRelated
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (context, index) => Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : _relatedTVShows.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma série relacionada encontrada',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _relatedTVShows.take(10).length,
                        itemBuilder: (context, index) {
                          final tvShow = _relatedTVShows[index];
                          final hasImage = tvShow.posterPath != null && tvShow.posterPath!.isNotEmpty;

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
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: BaserowService.getImageUrl(tvShow.posterPath),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.tv, size: 40, color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.tv, size: 40, color: Colors.grey),
                                      ),
                              ),
                            ),
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
