import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/tv_show.dart';
import '../services/baserow_service.dart';
import '../screens/tv_show_detail_screen.dart';
import '../utils/page_transitions.dart';

class TVShowCard extends StatelessWidget {
  final TVShow tvShow;
  final bool replaceRoute;

  const TVShowCard({
    super.key,
    required this.tvShow,
    this.replaceRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    String releaseYear = '';
    if (tvShow.firstAirDate.isNotEmpty) {
      try {
        releaseYear = tvShow.firstAirDate.split('-')[0];
      } catch (e) {
        releaseYear = '';
      }
    }

    return GestureDetector(
      onTap: () {
        final route = FadeSlidePageRoute(
          page: TVShowDetailScreen(
            tvShowId: tvShow.id,
            posterPath: tvShow.posterPath,
          ),
        );
        
        if (replaceRoute) {
          Navigator.pushReplacement(context, route);
        } else {
          Navigator.push(context, route);
        }
      },
      child: Container(
        width: 118,
        height: 166,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: BaserowService.getImageUrl(tvShow.posterPath),
                height: 166,
                width: 118,
                fit: BoxFit.cover,
                memCacheWidth: 250, // Cache otimizado
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => Container(
                  color: Colors.grey[850],
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.tv, size: 40),
                ),
              ),
              // Rating - estilo Em Alta
              if (tvShow.voteAverage > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
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
                          tvShow.voteAverage.toStringAsFixed(1),
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
