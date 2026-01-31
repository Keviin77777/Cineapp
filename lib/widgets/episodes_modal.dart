import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';

class EpisodesModal extends StatefulWidget {
  final int tvShowId;
  final int? tmdbId;
  final int currentSeason;
  final int? currentEpisode;
  final String tvShowName;
  final String? posterPath;
  final String? backdropPath;
  final Function(int seasonNumber, int episodeNumber, String videoUrl, String? stillPath) onEpisodeSelected;

  const EpisodesModal({
    super.key,
    required this.tvShowId,
    this.tmdbId,
    required this.currentSeason,
    this.currentEpisode,
    required this.tvShowName,
    this.posterPath,
    this.backdropPath,
    required this.onEpisodeSelected,
  });

  @override
  State<EpisodesModal> createState() => _EpisodesModalState();
}

class _EpisodesModalState extends State<EpisodesModal> {
  final BaserowService _baserowService = BaserowService();
  late int _selectedSeason;
  Map<int, List<Map<String, dynamic>>> _episodesBySeason = {};
  List<int> _availableSeasons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.currentSeason;
    _loadAllEpisodes();
  }

  Future<void> _loadAllEpisodes() async {
    setState(() => _isLoading = true);
    
    try {
      // Carregar todos os episódios do Baserow
      final baserowEpisodes = await _baserowService.getEpisodes(widget.tvShowId);
      
      // Agrupar por temporada
      final Map<int, List<Map<String, dynamic>>> episodesBySeason = {};
      for (final ep in baserowEpisodes) {
        final season = ep['temporada'] as int? ?? 1;
        final epNumber = ep['episodio'] as int? ?? 1;
        
        episodesBySeason.putIfAbsent(season, () => []).add({
          ...ep,
          'name': ep['nome'] ?? 'Episódio $epNumber',
          'overview': '',
          'still_path': null,
          'runtime': 0,
        });
      }
      
      // Ordenar episódios dentro de cada temporada
      episodesBySeason.forEach((season, episodes) {
        episodes.sort((a, b) => 
          (a['episodio'] as int).compareTo(b['episodio'] as int)
        );
      });
      
      final seasons = episodesBySeason.keys.toList()..sort();
      
      setState(() {
        _episodesBySeason = episodesBySeason;
        _availableSeasons = seasons;
        _isLoading = false;
      });
      
      // Carregar dados do TMDB em background
      if (widget.tmdbId != null && widget.tmdbId! > 0) {
        _loadTMDBData();
      }
    } catch (e) {
      print('Erro ao carregar episódios: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTMDBData() async {
    if (widget.tmdbId == null) return;
    
    for (final season in _availableSeasons) {
      try {
        final tmdbEpisodes = await _baserowService.getTMDBSeasonEpisodes(
          widget.tmdbId!,
          season,
        );
        
        if (tmdbEpisodes.isNotEmpty) {
          final seasonEps = _episodesBySeason[season] ?? [];
          for (int i = 0; i < seasonEps.length; i++) {
            final epNumber = seasonEps[i]['episodio'] as int? ?? (i + 1);
            final tmdbEp = tmdbEpisodes.firstWhere(
              (t) => t['episode_number'] == epNumber,
              orElse: () => <String, dynamic>{},
            );
            
            seasonEps[i] = {
              ...seasonEps[i],
              'still_path': tmdbEp['still_path'],
              'overview': tmdbEp['overview'] ?? seasonEps[i]['overview'] ?? '',
              'name': tmdbEp['name'] ?? seasonEps[i]['name'] ?? 'Episódio $epNumber',
              'runtime': tmdbEp['runtime'] ?? 0,
            };
          }
          
          if (mounted) {
            setState(() {
              _episodesBySeason[season] = seasonEps;
            });
          }
        }
      } catch (e) {
        print('Erro ao carregar TMDB para temporada $season: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEpisodes = _episodesBySeason[_selectedSeason] ?? [];
    
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Overlay semi-transparente preenchendo toda a tela
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: const Color(0xFF0E0F12).withOpacity(0.85),
              ),
            ),
          ),
          // Conteúdo
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // Header com botão fechar e filtro de temporadas
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Botão fechar
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0E0F12).withOpacity(0.5),
                          ),
                        ),
                        const Spacer(),
                        // Filtro de temporadas
                        if (_availableSeasons.length > 1)
                          GestureDetector(
                            onTap: _showSeasonPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.filter_list, size: 18, color: const Color(0xFF0E0F12)),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.tvShowName,
                                    style: const TextStyle(
                                      color: const Color(0xFF0E0F12),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Lista de episódios preenchendo toda a largura
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : currentEpisodes.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: currentEpisodes.length,
                                itemBuilder: (context, index) {
                                  final episode = currentEpisodes[index];
                                  final episodeNumber = episode['episodio'] ?? (index + 1);
                                  final isCurrentEpisode = episodeNumber == widget.currentEpisode && 
                                                           _selectedSeason == widget.currentSeason;
                                  
                                  return _buildEpisodeCard(
                                    context,
                                    episode,
                                    episodeNumber,
                                    isCurrentEpisode,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSeasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF6F7385),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Selecionar Temporada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Lista de temporadas com scroll
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _availableSeasons.map((season) => ListTile(
                      leading: Icon(
                        _selectedSeason == season ? Icons.check_circle : Icons.circle_outlined,
                        color: _selectedSeason == season ? const Color(0xFF7C4DFF) : Colors.grey,
                      ),
                      title: Text(
                        'Temporada $season',
                        style: TextStyle(
                          color: _selectedSeason == season ? const Color(0xFF7C4DFF) : Colors.white,
                          fontWeight: _selectedSeason == season ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        '${(_episodesBySeason[season] ?? []).length} eps',
                        style: TextStyle(
                          color: const Color(0xFFB0B3C6),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedSeason = season);
                        Navigator.pop(context);
                      },
                    )).toList(),
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

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        width: 300,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFF151820)?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 16,
              width: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF151820)?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF151820)?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 60, color: const Color(0xFF6F7385)),
          const SizedBox(height: 16),
          Text(
            'Nenhum episódio disponível',
            style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(
    BuildContext context,
    Map<String, dynamic> episode,
    int episodeNumber,
    bool isCurrentEpisode,
  ) {
    final stillPath = episode['still_path'] as String?;
    final name = episode['name'] as String? ?? 'Episódio $episodeNumber';
    final overview = episode['overview'] as String? ?? '';
    final link = episode['link'] as String? ?? '';
    final runtime = episode['runtime'] as int? ?? 0;
    
    // Usar still_path do TMDB, ou backdrop da série como fallback
    final imageUrl = stillPath != null && stillPath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$stillPath'
        : widget.backdropPath != null && widget.backdropPath!.isNotEmpty
            ? BaserowService.getImageUrl(widget.backdropPath)
            : null;
    
    return GestureDetector(
      onTap: link.isNotEmpty
          ? () {
              Navigator.pop(context);
              widget.onEpisodeSelected(_selectedSeason, episodeNumber, link, stillPath);
            }
          : null,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail do episódio
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF151820)?.withOpacity(0.3),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF151820)?.withOpacity(0.3),
                              child: const Icon(
                                Icons.play_circle_outline,
                                size: 50,
                                color: Colors.white54,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF151820)?.withOpacity(0.3),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 50,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                  ),
                  // Overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0E0F12).withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play icon
                  if (link.isNotEmpty)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0F12).withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            size: 40,
                            color: isCurrentEpisode ? const Color(0xFF7C4DFF) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Duração no canto superior esquerdo (azul)
                  if (runtime > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${runtime}min',
                          style: const TextStyle(
                            color: const Color(0xFF0E0F12),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Badge ATUAL no canto superior direito
                  if (isCurrentEpisode)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ASSISTINDO',
                          style: TextStyle(
                            color: const Color(0xFF0E0F12),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Indisponível overlay
                  if (link.isEmpty)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF0E0F12).withOpacity(0.7),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, color: const Color(0xFFB0B3C6), size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Indisponível',
                                style: TextStyle(
                                  color: const Color(0xFFB0B3C6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Número e nome do episódio
            Text(
              '$episodeNumber - $name',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isCurrentEpisode ? const Color(0xFF7C4DFF) : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Sinopse
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                overview,
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFFB0B3C6),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}










