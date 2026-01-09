import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? category;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.episodeNumber,
    this.seasonNumber,
    this.category,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isDragging = false;
  int _fitModeIndex = 0;
  double _dragValue = 0.0;
  String? _errorMessage;
  Timer? _hideControlsTimer;
  double _brightness = 0.5;
  double _volume = 1.0;
  late AnimationController _loadingController;

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
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
        _startHideControlsTimer();
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
    _loadingController.dispose();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            if (_showControls && !_isLoading && _errorMessage == null) _buildControls(),
          ],
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
            if (widget.category != null)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(width: 3, height: 14, color: const Color(0xFF12CDD9)),
                      const SizedBox(width: 8),
                      Text(widget.category!.toUpperCase(), style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
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
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Brilho
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.brightness_6, color: Colors.white, size: 20),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: Colors.white, inactiveTrackColor: Colors.grey[700], thumbColor: Colors.white),
                    child: Slider(value: _brightness, onChanged: (v) => setState(() => _brightness = v)),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Play controls
          Row(
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
              const SizedBox(width: 40),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 55),
              ),
              const SizedBox(width: 40),
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
          ),
          const Spacer(),
          // Volume
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 20),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: Colors.white, inactiveTrackColor: Colors.grey[700], thumbColor: Colors.white),
                    child: Slider(value: _volume, onChanged: (v) { setState(() => _volume = v); _controller?.setVolume(v); }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
              _buildBottomBtn(Icons.video_library_outlined, 'EPISÓDIOS'),
              _buildBottomBtn(Icons.speed, 'NORMAL'),
              _buildBottomBtn(Icons.skip_next, 'PRÓX. EP.'),
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
