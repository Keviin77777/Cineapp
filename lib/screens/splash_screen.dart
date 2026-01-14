import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tmdb_service.dart';
import '../services/baserow_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'profile_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _backgroundImage = 'assets/images/Splash.png';
  final TMDBService _tmdbService = TMDBService();
  final BaserowService _baserowService = BaserowService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Valida se o usuário ainda existe no servidor
  Future<bool> _validateUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('userEmail');
      final senha = prefs.getString('userPassword');
      
      if (email == null || senha == null) {
        return false;
      }
      
      // Valida no servidor
      final result = await _baserowService.login(email, senha);
      
      if (result['success'] == true) {
        // Atualiza dados do usuário localmente
        final user = result['user'];
        await prefs.setInt('userId', user['id']);
        await prefs.setString('userName', user['nome']);
        await prefs.setInt('userDias', user['dias']);
        await prefs.setInt('userRestam', user['restam']);
        return true;
      } else {
        // Usuário não existe mais ou senha mudou - limpa sessão
        await _clearSession(prefs);
        return false;
      }
    } catch (e) {
      // Em caso de erro de conexão, permite acesso offline
      // mas você pode mudar para retornar false se quiser bloquear
      return true;
    }
  }
  
  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userEmail');
    await prefs.remove('userPassword');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userDias');
    await prefs.remove('userRestam');
  }

  Future<void> _initializeApp() async {
    // Tempo mínimo de exibição da splash (2 segundos)
    final minDisplayTime = Future.delayed(const Duration(seconds: 2));
    
    try {
      // Carregar preferências
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      // Se está logado, valida a sessão no servidor
      bool sessionValid = false;
      if (isLoggedIn) {
        sessionValid = await _validateUserSession();
      }

      // Se primeira vez, pré-carregar conteúdo do onboarding
      List<Movie>? trendingMovies;
      List<TVShow>? trendingTVShows;
      
      if (!hasSeenOnboarding) {
        trendingMovies = await _tmdbService.getTrendingMovies();
        trendingTVShows = await _tmdbService.getTrendingTVShows();
        
        // Pré-carregar imagens dos posters e backdrops
        if (mounted) {
          await _precacheOnboardingImages(trendingMovies, trendingTVShows);
        }
      }
      
      // Aguardar tempo mínimo de exibição
      await minDisplayTime;

      if (!mounted) return;

      // Navegar para a tela correta
      if (!hasSeenOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingScreen(
              preloadedMovies: trendingMovies,
              preloadedTVShows: trendingTVShows,
            ),
          ),
        );
      } else if (!isLoggedIn || !sessionValid) {
        // Se não está logado OU sessão inválida, vai para login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
        );
      }
    } catch (e) {
      // Aguardar tempo mínimo mesmo em caso de erro
      await minDisplayTime;
      
      if (!mounted) return;
      
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (!hasSeenOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        // Em caso de erro, vai para login por segurança
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _precacheOnboardingImages(List<Movie>? movies, List<TVShow>? tvShows) async {
    final List<Future> futures = [];
    
    // Pré-carregar imagens dos filmes
    if (movies != null) {
      for (final movie in movies.take(6)) {
        if (movie.posterPath != null) {
          futures.add(
            precacheImage(
              NetworkImage(TMDBService.getImageUrl(movie.posterPath!)),
              context,
            ).catchError((_) {}),
          );
        }
        if (movie.backdropPath != null) {
          futures.add(
            precacheImage(
              NetworkImage(TMDBService.getOriginalImageUrl(movie.backdropPath!)),
              context,
            ).catchError((_) {}),
          );
        }
      }
    }
    
    // Pré-carregar imagens das séries
    if (tvShows != null) {
      for (final tvShow in tvShows.take(6)) {
        if (tvShow.posterPath != null) {
          futures.add(
            precacheImage(
              NetworkImage(TMDBService.getImageUrl(tvShow.posterPath!)),
              context,
            ).catchError((_) {}),
          );
        }
        if (tvShow.backdropPath != null) {
          futures.add(
            precacheImage(
              NetworkImage(TMDBService.getOriginalImageUrl(tvShow.backdropPath!)),
              context,
            ).catchError((_) {}),
          );
        }
      }
    }
    
    // Aguardar todas as imagens carregarem
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    // Status bar transparente
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              _backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          // Overlay gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Conteúdo
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Logo
                  Image.asset(
                    'assets/images/Logo.png',
                    width: 280,
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(flex: 2),
                  // Loading circular
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Color(0xFF12CDD9),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
