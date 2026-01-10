import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../services/baserow_service.dart';
import '../services/watch_progress_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? category;
  final int? contentId;
  final String? posterPath;
  final String? backdropPath;
  final String type; // 'movie' ou 'tv'
  final int? startPositionMs; // Posição inicial para continuar

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.episodeNumber,
    this.seasonNumber,
    this.category,
    this.contentId,
    this.posterPath,
    this.backdropPath,
    this.type = 'movie',
    this.startPositionMs,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  final BaserowService _baserowService = BaserowService();
  final WatchProgressService _watchProgressService = WatchProgressService();
  bool _isLoading = true;
  bool _showControls = true;
  bool _viewCounted = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isDragging = false;
  int _fitModeIndex = 2; // Inicia em STRETCH
  double _dragValue = 0.0;
  String? _errorMessage;
  Timer? _hideControlsTimer;
  Timer? _hideCategoryTimer;
  Timer? _saveProgressTimer;
  late AnimationController _loadingController;
  late AnimationController _categoryAnimController;
  late Animation<Offset> _categorySlideAnimation;
  late Animation<double> _categoryFadeAnimation;
  bool _showCategoryBanner = false;

  final List<Map<String, dynamic>> _fitModes = [
    {'fit': BoxFit.contain, 'name': 'NORMAL', 'icon': Icons.fit_screen},
    {'fit': BoxFit.cover, 'name': 'COVER', 'icon': Icons.crop_free},
    {'fit': BoxFit.fill, 'name': 'STRETCH', 'icon': Icons.fullscreen},
    {'fit': BoxFit.fitWidth, 'name': 'LARGURA', 'icon': Icons.width_normal},
    {'fit': BoxFit.fitHeight, 'name': 'ALTURA', 'icon': Icons.height},
  ];

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Animação do banner de categoria
    _categoryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _categorySlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _categoryAnimController,
      curve: Curves.easeOutCubic,
    ));
    _categoryFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _categoryAnimController,
      curve: Curves.easeOut,
    ));
    
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0',
        },
      );

      _controller!.addListener(_videoListener);
      await _controller!.initialize();
      
      // Se tem posição inicial, pula para ela
      if (widget.startPositionMs != null && widget.startPositionMs! > 0) {
        await _controller!.seekTo(Duration(milliseconds: widget.startPositionMs!));
      }
      
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
        _startHideControlsTimer();
        _showCategoryBannerAnimation();
        _countView();
        _startSaveProgressTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar vídeo';
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null) return;
    final isBuffering = _controller!.value.isBuffering;
    final isPlaying = _controller!.value.isPlaying;
    if (isBuffering != _isBuffering || isPlaying != _isPlaying) {
      if (mounted) {
        setState(() {
          _isBuffering = isBuffering;
          _isPlaying = isPlaying;
        });
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) setState(() => _showControls = false);
    });
  }

  void _showCategoryBannerAnimation() {
    if (widget.category == null || widget.category!.isEmpty) return;
    
    setState(() => _showCategoryBanner = true);
    _categoryAnimController.forward();
    
    _hideCategoryTimer?.cancel();
    _hideCategoryTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        _categoryAnimController.reverse().then((_) {
          if (mounted) setState(() => _showCategoryBanner = false);
        });
      }
    });
  }

  // Inicia timer para salvar progresso a cada 10 segundos
  void _startSaveProgressTimer() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveCurrentProgress();
    });
  }

  // Salva o progresso atual
  Future<void> _saveCurrentProgress() async {
    if (_controller == null || widget.contentId == null) return;
    if (!_controller!.value.isInitialized) return;
    
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    
    if (duration.inMilliseconds <= 0) return;
    
    final progress = WatchProgress(
      contentId: widget.contentId!,
      title: widget.title,
      posterPath: widget.posterPath,
      backdropPath: widget.backdropPath,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      type: widget.type,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
      lastWatched: DateTime.now(),
    );
    
    await _watchProgressService.saveProgress(progress);
  }

  // Contar visualização no Baserow
  void _countView() async {
    if (_viewCounted || widget.contentId == null) return;
    _viewCounted = true;
    await _baserowService.incrementViews(widget.contentId!);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
        _startHideControlsTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final pos = _controller!.value.position;
    _controller!.seekTo(pos + Duration(seconds: seconds));
    _startHideControlsTimer();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getRemainingTime() {
    if (_controller == null) return '-00:00';
    final remaining = _controller!.value.duration - _controller!.value.position;
    return '-${_formatDuration(remaining)}';
  }

  void _toggleFitMode() {
    setState(() {
      _fitModeIndex = (_fitModeIndex + 1) % _fitModes.length;
    });
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _hideCategoryTimer?.cancel();
    _saveProgressTimer?.cancel();
    // Salva progresso ao sair
    _saveCurrentProgress();
    _loadingController.dispose();
    _categoryAnimController.dispose();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveCurrentProgress(); // Salva antes de sair
        Navigator.pop(context, _viewCounted);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              if (_controller != null && _controller!.value.isInitialized)
                Center(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: _fitModes[_fitModeIndex]['fit'] as BoxFit,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                ),
              if (_isLoading) _buildLoading(),
              if (_isBuffering && !_isLoading) _buildBufferingIndicator(),
              if (_errorMessage != null) _buildError(),
              if (_showCategoryBanner && !_isLoading && _errorMessage == null) _buildCategoryBanner(),
              if (_showControls && !_isLoading && _errorMessage == null) ...[
                // Overlay escuro quando controles estão visíveis
                Container(color: Colors.black.withOpacity(0.4)),
                _buildControls(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: Center(child: _buildDiamondLoader()),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(child: _buildDiamondLoader());
  }

  Widget _buildDiamondLoader() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _loadingController.value * 6.28,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF12CDD9),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF12CDD9).withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF12CDD9)),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBanner() {
    return Positioned(
      left: 16,
      top: 60,
      child: SlideTransition(
        position: _categorySlideAnimation,
        child: FadeTransition(
          opacity: _categoryFadeAnimation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF12CDD9),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF12CDD9).withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black),
                      ],
                    ),
                  ),
                  if (widget.seasonNumber != null && widget.episodeNumber != null)
                    Text(
                      'T${widget.seasonNumber} • E${widget.episodeNumber}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.7)],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
            const Spacer(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, _viewCounted), // Retorna se contou view
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Text(widget.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.seasonNumber != null && widget.episodeNumber != null)
                  Text('T${widget.seasonNumber}E${widget.episodeNumber}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _toggleFitMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_fitModes[_fitModeIndex]['icon'] as IconData, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _fitModes[_fitModeIndex]['name'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _seekRelative(-10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.flip(flipX: true, child: const Icon(Icons.refresh, color: Colors.white, size: 40)),
              const Text('10', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 50),
        GestureDetector(
          onTap: _togglePlayPause,
          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 55),
        ),
        const SizedBox(width: 50),
        GestureDetector(
          onTap: () => _seekRelative(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.refresh, color: Colors.white, size: 40),
              const Text('10', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final pos = _controller?.value.position ?? Duration.zero;
    final dur = _controller?.value.duration ?? Duration.zero;
    final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
    
    // Usa o valor do drag se estiver arrastando, senão usa o progresso real
    final displayProgress = _isDragging ? _dragValue : progress;
    final displayPosition = _isDragging 
        ? Duration(milliseconds: (_dragValue * dur.inMilliseconds).toInt())
        : pos;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(_formatDuration(displayPosition), style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF12CDD9),
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: const Color(0xFF12CDD9),
                    ),
                    child: Slider(
                      value: displayProgress.clamp(0.0, 1.0),
                      onChanged: (v) {
                        setState(() => _dragValue = v);
                      },
                      onChangeStart: (v) {
                        _hideControlsTimer?.cancel();
                        setState(() {
                          _isDragging = true;
                          _dragValue = v;
                        });
                      },
                      onChangeEnd: (v) {
                        _controller?.seekTo(Duration(milliseconds: (v * dur.inMilliseconds).toInt()));
                        setState(() => _isDragging = false);
                        _startHideControlsTimer();
                      },
                    ),
                  ),
                ),
              ),
              Text(_getRemainingTime(), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomBtn(Icons.lock_outline, 'BLOQUEAR'),
              if (widget.episodeNumber != null) _buildBottomBtn(Icons.video_library_outlined, 'EPISÓDIOS'),
              _buildBottomBtn(Icons.speed, 'NORMAL'),
              if (widget.episodeNumber != null) _buildBottomBtn(Icons.skip_next, 'PRÓX. EP.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBtn(IconData icon, String label) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
