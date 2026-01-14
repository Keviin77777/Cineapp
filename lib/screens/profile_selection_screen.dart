import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/profile.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import 'create_profile_screen.dart';
import 'profile_intro_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
    with TickerProviderStateMixin {
  List<Profile> _profiles = [];
  bool _isLoading = true;
  final TMDBService _tmdbService = TMDBService();
  List<Movie> _backgroundMovies = [];
  int _currentBackgroundIndex = 0;
  Timer? _backgroundTimer;
  final PageController _backgroundPageController = PageController();
  final PageController _profilePageController =
      PageController(viewportFraction: 0.85);
  Color _backgroundColor = const Color(0xFF1a1a2e);
  final Map<int, Color> _colorCache = {};
  int _currentProfileIndex = 0;
  late AnimationController _floatingController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _loadProfiles();
    _loadBackgroundMovies();
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _backgroundPageController.dispose();
    _profilePageController.dispose();
    _floatingController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadBackgroundMovies() async {
    try {
      final movies = await _tmdbService.getTrendingMovies();
      if (mounted) {
        setState(() {
          _backgroundMovies = movies.take(4).toList();
        });
      }
      _startBackgroundAnimation();
    } catch (e) {
      // Handle error silently
      if (mounted) {
        setState(() {
          _backgroundMovies = [];
        });
      }
    }
  }

  Future<void> _extractColor(int index) async {
    if (index >= _backgroundMovies.length) return;

    try {
      // Usar cores pré-definidas ao invés de extrair dos posters
      final colors = [
        const Color(0xFF1a1a2e),
        const Color(0xFF16213e),
        const Color(0xFF0f3460),
        const Color(0xFF1f4068),
      ];
      
      _colorCache[index] = colors[index % colors.length];

      if (index == _currentBackgroundIndex && mounted) {
        setState(() {
          _backgroundColor = _colorCache[index]!;
        });
      }
    } catch (e) {
      _colorCache[index] = const Color(0xFF1a1a2e);
    }
  }

  void _startBackgroundAnimation() {
    if (_backgroundMovies.isEmpty) return;
    
    _backgroundTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_backgroundMovies.isNotEmpty && mounted) {
        final nextIndex =
            (_currentBackgroundIndex + 1) % _backgroundMovies.length;
        if (mounted) {
          setState(() {
            _currentBackgroundIndex = nextIndex;
            if (_colorCache.containsKey(nextIndex)) {
              _backgroundColor = _colorCache[nextIndex]!;
            }
          });
        }
        if (_backgroundPageController.hasClients) {
          _backgroundPageController.animateToPage(
            _currentBackgroundIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    
    // Carrega perfis vinculados ao usuário atual
    final profilesJson = prefs.getStringList('profiles_$userId') ?? [];

    setState(() {
      _profiles = profilesJson
          .map((json) => Profile.fromJson(jsonDecode(json)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _selectProfile(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentProfile', jsonEncode(profile.toJson()));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileIntroScreen(profile: profile),
      ),
    );
  }

  void _createNewProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateProfileScreen(),
      ),
    ).then((_) => _loadProfiles());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background com blur e gradiente animado
          if (_backgroundMovies.isNotEmpty)
            Positioned.fill(
              child: PageView.builder(
                controller: _backgroundPageController,
                itemCount: _backgroundMovies.length,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentBackgroundIndex = index;
                      if (_colorCache.containsKey(index)) {
                        _backgroundColor = _colorCache[index]!;
                      }
                    });
                  }
                },
                itemBuilder: (context, index) {
                  final movie = _backgroundMovies[index];
                  final imageUrl = movie.backdropPath ?? movie.posterPath ?? '';
                  
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: TMDBService.getOriginalImageUrl(imageUrl),
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 300),
                          placeholder: (context, url) => Container(
                            color: Colors.black,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black,
                          ),
                        )
                      else
                        Container(color: Colors.black),
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.5,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.8),
                              Colors.black.withOpacity(0.95),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Gradiente de fundo animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _backgroundColor.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  _backgroundColor.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.8),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'CINEMAX',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                onPressed: () {},
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Título com animação
                      AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                                0,
                                math.sin(_floatingController.value * 2 *
                                        math.pi) *
                                    5),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              'Bem-vindo de volta!',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.7),
                                    ],
                                  ).createShader(
                                      const Rect.fromLTWH(0, 0, 200, 70)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Escolha seu perfil para continuar',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Carrossel de perfis
                      if (_profiles.isEmpty)
                        _buildEmptyState()
                      else
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            controller: _profilePageController,
                            itemCount: _profiles.length + 1,
                            onPageChanged: (index) {
                              setState(() {
                                _currentProfileIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              if (index == _profiles.length) {
                                return _buildAddProfileCard3D(index);
                              }
                              return _buildProfileCard3D(
                                  _profiles[index], index);
                            },
                          ),
                        ),

                      const SizedBox(height: 25),

                      // Indicadores
                      if (_profiles.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _profiles.length + 1,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentProfileIndex == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: _currentProfileIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),

                      const Spacer(),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_add_outlined,
              size: 50,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhum perfil criado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque abaixo para criar seu primeiro perfil',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _createNewProfile,
            icon: const Icon(Icons.add),
            label: const Text('Criar Perfil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard3D(Profile profile, int index) {
    return AnimatedBuilder(
      animation: _profilePageController,
      builder: (context, child) {
        double value = 1.0;
        if (_profilePageController.position.haveDimensions) {
          value = _profilePageController.page! - index;
          value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
        }

        return Center(
          child: Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _selectProfile(profile),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(int.parse(profile.backgroundColor)).withOpacity(0.2),
                Color(int.parse(profile.backgroundColor)).withOpacity(0.05),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(int.parse(profile.backgroundColor)),
                            Color(int.parse(profile.backgroundColor))
                                .withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          profile.avatarUrl,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddProfileCard3D(int index) {
    return AnimatedBuilder(
      animation: _profilePageController,
      builder: (context, child) {
        double value = 1.0;
        if (_profilePageController.position.haveDimensions) {
          value = _profilePageController.page! - index;
          value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
        }

        return Center(
          child: Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: _createNewProfile,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 36,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Adicionar Perfil',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Criar novo',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
