import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../screens/movie_detail_screen.dart';
import '../utils/page_transitions.dart';

class Top10Card extends StatelessWidget {
  final int position;
  final String posterPath;
  final int? movieId;

  const Top10Card({
    super.key,
    required this.position,
    required this.posterPath,
    this.movieId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: movieId != null
          ? () {
              Navigator.push(
                context,
                FadeSlidePageRoute(
                  page: MovieDetailScreen(
                    movieId: movieId!,
                    posterPath: posterPath,
                  ),
                ),
              );
            }
          : null,
      child: Container(
        width: position >= 10 ? 215 : 185,
        height: 185,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Número grande atrás do card - estilo Netflix
            Positioned(
              left: position >= 10 ? -10 : 5,
              bottom: -15,
              child: Stack(
                children: [
                  // Sombra do número para dar profundidade
                  Text(
                    position.toString(),
                    style: TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Arial',
                      height: 0.8,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ),
                  // Contorno do número (stroke) - mais visível
                  Transform.translate(
                    offset: const Offset(-2, -2),
                    child: Text(
                      position.toString(),
                      style: TextStyle(
                        fontSize: 110,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Arial',
                        height: 0.8,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = Colors.grey[500]!,
                      ),
                    ),
                  ),
                  // Preenchimento do número (escuro embutido)
                  Transform.translate(
                    offset: const Offset(-2, -2),
                    child: Text(
                      position.toString(),
                      style: const TextStyle(
                        fontSize: 110,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Arial',
                        height: 0.8,
                        color: Color(0xFF0F0F0F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Poster do filme/série (fica na frente do número)
            Positioned(
              left: position >= 10 ? 75 : 45,
              top: 0,
              child: Container(
                width: 145,
                height: 185,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: BaserowService.getImageUrl(posterPath),
                    width: 145,
                    height: 185,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
