import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/baserow_service.dart';
import '../screens/movie_detail_screen.dart';
import '../utils/page_transitions.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final bool replaceRoute; // Se true, substitui a rota atual

  const MovieCard({
    super.key,
    required this.movie,
    this.replaceRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    String releaseYear = '';
    if (movie.releaseDate.isNotEmpty) {
      try {
        releaseYear = movie.releaseDate.split('-')[0];
      } catch (e) {
        releaseYear = '';
      }
    }

    return GestureDetector(
      onTap: () {
        final route = FadeSlidePageRoute(
          page: MovieDetailScreen(
            movieId: movie.id,
            posterPath: movie.posterPath,
          ),
        );
        
        if (replaceRoute) {
          Navigator.pushReplacement(context, route);
        } else {
          Navigator.push(context, route);
        }
      },
      child: Container(
        width: 125,
        height: 166,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 0.5,
          ),
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
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: BaserowService.getImageUrl(movie.posterPath),
                height: 166,
                width: 125,
                fit: BoxFit.cover,
                memCacheWidth: 250, // Cache otimizado
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => Container(
                  color: const Color(0xFF151820),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF151820),
                  child: const Icon(Icons.movie, size: 40),
                ),
              ),
              // Rating - estilo Em Alta
              if (movie.voteAverage > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0F12).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 10,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          movie.voteAverage.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
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










