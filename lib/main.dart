import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/tv_show_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CinemaxApp());
}

class CinemaxApp extends StatelessWidget {
  const CinemaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinemax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF12CDD9),
          secondary: const Color(0xFFFF8700),
          surface: const Color(0xFF252836),
        ),
        fontFamily: 'Poppins',
      ),
      navigatorObservers: [tvShowRouteObserver],
      home: const SplashScreen(),
    );
  }
}
