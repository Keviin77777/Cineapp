import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../services/baserow_service.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/tv_show_detail_screen.dart';
import '../utils/page_transitions.dart';

// Matrix para ajuste de contraste +15%, saturação -8%, brilho -2% (cinema look)
const List<double> _cinemaColorMatrix = [
  1.15, 0.0, 0.0, 0.0, -12.0,
  0.0, 1.07, 0.0, 0.0, -12.0,
  0.0, 0.0, 1.07, 0.0, -12.0,
  0.0, 0.0, 0.0, 1.0, 0.0,
];

class FeaturedMovieCard extends StatelessWidget {
  final Movie movie;
  final bool showTop10Badge;

  const FeaturedMovieCard({
    super.key,
    required this.movie,
    this.showTop10Badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          FadeSlidePageRoute(
            page: MovieDetailScreen(
              movieId: movie.id,
              posterPath: movie.posterPath,
            ),
          ),
        );
      },
      child: Container(
        width: 190,
        height: 250,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF1C2030)!.withOpacity(0.5),
            width: 1,
          ),
          // Sombra Netflix: blur alto, offset vertical, opacidade forte
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E0F12).withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem com tratamento cinema (contraste/saturação)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(_cinemaColorMatrix),
                child: CachedNetworkImage(
                  imageUrl: BaserowService.getImageUrl(movie.posterPath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF151820),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF151820),
                    child: const Icon(Icons.movie, size: 40),
                  ),
                ),
              ),
              // Overlay degradê vertical (segredo Netflix)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.45, 0.75, 1.0],
                    colors: [
                      Color(0x0D000000), // 5% preto
                      Color(0x4D000000), // 30% preto
                      Color(0xB3000000), // 70% preto
                      Color(0xE6000000), // 90% preto
                    ],
                  ),
                ),
              ),
              // Badge TOP 10 - vermelho forte
              if (showTop10Badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9A0007),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        Text(
                          '10',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
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


class FeaturedTVShowCard extends StatelessWidget {
  final TVShow tvShow;
  final bool showTop10Badge;

  const FeaturedTVShowCard({
    super.key,
    required this.tvShow,
    this.showTop10Badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          FadeSlidePageRoute(
            page: TVShowDetailScreen(
              tvShowId: tvShow.id,
              posterPath: tvShow.posterPath,
            ),
          ),
        );
      },
      child: Container(
        width: 190,
        height: 250,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF1C2030)!.withOpacity(0.5),
            width: 1,
          ),
          // Sombra Netflix: blur alto, offset vertical, opacidade forte
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E0F12).withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem com tratamento cinema (contraste/saturação)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(_cinemaColorMatrix),
                child: CachedNetworkImage(
                  imageUrl: BaserowService.getImageUrl(tvShow.posterPath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF151820),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF151820),
                    child: const Icon(Icons.tv, size: 40),
                  ),
                ),
              ),
              // Overlay degradê vertical (segredo Netflix)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.45, 0.75, 1.0],
                    colors: [
                      Color(0x0D000000), // 5% preto
                      Color(0x4D000000), // 30% preto
                      Color(0xB3000000), // 70% preto
                      Color(0xE6000000), // 90% preto
                    ],
                  ),
                ),
              ),
              // Badge TOP 10 - vermelho forte
              if (showTop10Badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9A0007),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        Text(
                          '10',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
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










