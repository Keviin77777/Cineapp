import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../services/watch_progress_service.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/tv_show_detail_screen.dart';
import '../utils/page_transitions.dart';

class ContinueWatchingCard extends StatelessWidget {
  final WatchProgress progress;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const ContinueWatchingCard({
    super.key,
    required this.progress,
    this.onTap,
    this.onRemove,
  });

  void _showRemoveDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF6F7385),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              progress.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE50914)),
              title: const Text(
                'Remover de Continue Assistindo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onRemove?.call();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        if (progress.type == 'movie') {
          Navigator.push(
            context,
            FadeSlidePageRoute(
              page: MovieDetailScreen(
                movieId: progress.contentId,
                posterPath: progress.posterPath,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            FadeSlidePageRoute(
              page: TVShowDetailScreen(
                tvShowId: progress.contentId,
                posterPath: progress.posterPath,
                scrollToSeason: progress.seasonNumber,
                scrollToEpisode: progress.episodeNumber,
              ),
            ),
          );
        }
      },
      onLongPress: () => _showRemoveDialog(context),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem de fundo (backdrop)
              CachedNetworkImage(
                imageUrl: BaserowService.getImageUrl(
                  progress.backdropPath ?? progress.posterPath,
                ),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: const Color(0xFF151820)),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF151820),
                  child: const Icon(Icons.movie, size: 40, color: Colors.white54),
                ),
              ),
              // Gradiente inferior
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0E0F12).withOpacity(0.4),
                      const Color(0xFF0E0F12).withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Título e info
              Positioned(
                bottom: 24,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      progress.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (progress.seasonNumber != null && progress.episodeNumber != null)
                      Text(
                        'T${progress.seasonNumber} E${progress.episodeNumber}',
                        style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              // Barra de progresso
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1a1a1a),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        progress.formattedPosition,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress.progress,
                            backgroundColor: const Color(0xFF1C2030),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        progress.formattedDuration,
                        style: TextStyle(color: const Color(0xFFB0B3C6), fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    ],
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










