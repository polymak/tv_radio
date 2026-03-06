import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:tv_radio/screens/radio_screen.dart';
import 'package:tv_radio/screens/splash_screen.dart';
import 'package:tv_radio/services/radio_player_service.dart';
import 'package:tv_radio/services/background_audio_service.dart';

void main() {
  runApp(const TVRadioApp());
}

/// Main application widget for TV-Radio app
class TVRadioApp extends StatelessWidget {
  const TVRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RadioPlayerService(),
      child: MaterialApp(
        title: 'TV-Radio',
        locale: const Locale('fr'),
        theme: ThemeData(
          // TV-friendly theme with high contrast and clear typography
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            bodySmall: TextStyle(color: Colors.white54),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        home: const SplashScreen(),
        routes: {'/radio': (context) => const RadioScreen()},
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
