import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/baserow_service.dart';
import '../screens/tv_show_detail_screen.dart';
import '../utils/page_transitions.dart';

class Top10TVCard extends StatelessWidget {
  final int position;
  final String posterPath;
  final int? tvShowId;

  const Top10TVCard({
    super.key,
    required this.position,
    required this.posterPath,
    this.tvShowId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tvShowId != null
          ? () {
              Navigator.push(
                context,
                FadeSlidePageRoute(
                  page: TVShowDetailScreen(
                    tvShowId: tvShowId!,
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
                      color: const Color(0xFF0E0F12).withOpacity(0.8),
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
                          ..color = const Color(0xFFB0B3C6)!,
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
            // Poster da série (fica na frente do número)
            Positioned(
              left: position >= 10 ? 75 : 45,
              top: 0,
              child: Container(
                width: 145,
                height: 185,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.15),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                      spreadRadius: -2,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}











