import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/baserow_service.dart';
import '../screens/movie_detail_screen.dart';
import '../utils/page_transitions.dart';

class VerticalBanner extends StatefulWidget {
  final List<Movie> movies;

  const VerticalBanner({super.key, required this.movies});

  @override
  State<VerticalBanner> createState() => _VerticalBannerState();
}

class _VerticalBannerState extends State<VerticalBanner> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < widget.movies.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.50,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: widget.movies.length,
        itemBuilder: (context, index) {
          return _buildBannerItem(widget.movies[index]);
        },
      ),
    );
  }

  String _getHighQualityImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/1280x720/1F1D2B/FFFFFF?text=Sem+Imagem';
    }
    
    // Se já é uma URL completa, retorna como está
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    
    // Se é um path do TMDB, usar qualidade original
    if (imagePath.startsWith('/')) {
      return 'https://image.tmdb.org/t/p/original$imagePath'; // Qualidade máxima
    }
    
    return imagePath;
  }

  String _getFirstParagraph(String text) {
    if (text.isEmpty) return '';
    
    // Divide por quebras de linha duplas ou pontos seguidos de espaço
    final paragraphs = text.split(RegExp(r'\n\n|\. (?=[A-Z])'));
    
    // Retorna o primeiro parágrafo
    return paragraphs.first.trim();
  }

  Widget _buildBannerItem(Movie movie) {
    // Priorizar posterPath para banner vertical (melhor composição)
    final imageUrl = movie.posterPath ?? movie.backdropPath;
    
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo em alta qualidade
          CachedNetworkImage(
            imageUrl: _getHighQualityImageUrl(imageUrl),
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, -0.3),
            placeholder: (context, url) => Container(
              color: const Color(0xFF151820),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF151820),
              child: const Icon(Icons.movie, size: 80, color: Colors.grey),
            ),
          ),
          
          // Gradiente na parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0E0F12).withOpacity(0.6),
                    const Color(0xFF0E0F12),
                  ],
                ),
              ),
            ),
          ),
          
          // Informações do filme
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sinopse - apenas primeiro parágrafo
                Text(
                  _getFirstParagraph(movie.overview),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[200],
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Indicadores de página
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.movies.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF6F7385),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}










