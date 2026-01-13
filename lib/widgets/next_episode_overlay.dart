import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../services/baserow_service.dart';

class NextEpisodeOverlay extends StatefulWidget {
  final Map<String, dynamic> nextEpisode;
  final int nextEpisodeNumber;
  final int seasonNumber;
  final String tvShowName;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  const NextEpisodeOverlay({
    super.key,
    required this.nextEpisode,
    required this.nextEpisodeNumber,
    required this.seasonNumber,
    required this.tvShowName,
    required this.onPlay,
    required this.onCancel,
  });

  @override
  State<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<NextEpisodeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Timer? _autoPlayTimer;
  int _countdown = 5;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        widget.onPlay();
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stillPath = widget.nextEpisode['still_path'] as String?;
    final name = widget.nextEpisode['name'] as String? ?? 'Episódio ${widget.nextEpisodeNumber}';
    final overview = widget.nextEpisode['overview'] as String? ?? '';
    final runtime = widget.nextEpisode['runtime'] as int? ?? 0;
    
    final imageUrl = stillPath != null && stillPath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/original$stillPath'
        : null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Imagem de fundo do próximo episódio
            if (imageUrl != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black),
                  errorWidget: (context, url, error) => Container(color: Colors.black),
                ),
              )
            else
              Positioned.fill(
                child: Container(color: Colors.black),
              ),
            
            // Overlay gradient para legibilidade
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.3, 0.9],
                  ),
                ),
              ),
            ),
            
            // Conteúdo
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botão fechar
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close, color: Colors.white, size: 32),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Informações do próximo episódio
                    Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contador e label
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF12CDD9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PRÓXIMO EM $_countdown S',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (runtime > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${runtime}min',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Número e nome do episódio
                          Text(
                            'EP${widget.nextEpisodeNumber}: ${name.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Temporada
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.yellow[700],
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TEMPORADA ${widget.seasonNumber}',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Sinopse
                          if (overview.isNotEmpty)
                            Text(
                              overview,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 15,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                          const SizedBox(height: 32),
                          
                          // Botões de ação
                          Row(
                            children: [
                              // Botão Play
                              ElevatedButton.icon(
                                onPressed: widget.onPlay,
                                icon: const Icon(Icons.play_arrow, size: 28),
                                label: const Text(
                                  'ASSISTIR AGORA',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF12CDD9),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Botão Cancelar
                              OutlinedButton.icon(
                                onPressed: widget.onCancel,
                                icon: const Icon(Icons.close, size: 24),
                                label: const Text(
                                  'CANCELAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                  ],
                ),
              ),
            ),
            
            // Barra de progresso do countdown
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(seconds: 1),
                tween: Tween(begin: 1.0, end: 0.0),
                onEnd: () {
                  if (mounted && _countdown > 1) {
                    setState(() {});
                  }
                },
                builder: (context, value, child) {
                  final progress = (_countdown - 1 + value) / 5;
                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF12CDD9)),
                    minHeight: 4,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
