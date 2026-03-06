import 'package:flutter/material.dart';
import 'package:tv_radio/models/radio_station.dart';
import 'package:tv_radio/services/radio_player_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

/// Premium Spotify-like radio player with smooth animations and glass design
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late RadioPlayerService _playerService;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _playerService = Provider.of<RadioPlayerService>(context, listen: false);

    // Animation controller for live pulse
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xFFFFFFFF), // white center
              Color(0xFFE5E7EB), // light slate edges
            ],
            center: Alignment.topLeft,
            radius: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Background blur effects
            _buildBackgroundEffects(),

            // Main content
            Column(
              children: [
                // Top bar with time and location
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 40,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      _buildBackButton(),

                      // Time and location
                      _buildTimeAndLocation(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Station logo and info with animated transitions
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Large station logo with animation
                      _buildAnimatedLogo(),

                      const SizedBox(height: 40),

                      // Station name with animation
                      _buildAnimatedStationName(),

                      const SizedBox(height: 60),

                      // Controls with animations
                      _buildAnimatedControls(),

                      const SizedBox(height: 40),

                      // Progress bar
                      _buildProgressBar(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
        // Blue blur circle
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 100,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),

        // Subtle overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.1)),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return AnimatedScale(
      scale: 1.0,
      duration: Duration(milliseconds: 200),
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildTimeAndLocation() {
    return Row(
      children: [
        Text(
          _getCurrentTime(),
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(width: 8),
        const Text(
          'KINSHASA',
          style: TextStyle(
            fontSize: 14,
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    return Consumer<RadioPlayerService>(
      builder: (context, service, child) {
        final station = service.currentStation;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: Container(
            key: ValueKey(station?.name ?? 'default'),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: station?.logoAsset != null
                  ? Image.asset(
                      station!.logoAsset!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                    )
                  : Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.radio,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStationName() {
    return Consumer<RadioPlayerService>(
      builder: (context, service, child) {
        final station = service.currentStation;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: Text(
            station?.name ?? 'Unknown Station',
            key: ValueKey(station?.name ?? 'default'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        _buildControlButton(
          icon: Icons.skip_previous,
          onPressed: () => _playerService.previous(),
          isLarge: false,
        ),

        const SizedBox(width: 30),

        // Play/Pause button with scale animation
        Consumer<RadioPlayerService>(
          builder: (context, service, child) {
            return GestureDetector(
              onTapDown: (_) {
                // Scale down on press
              },
              onTapUp: (_) {
                // Scale up on release
              },
              onTapCancel: () {
                // Scale up on cancel
              },
              onTap: () => service.togglePlayPause(),
              child: AnimatedScale(
                scale: 1.0,
                duration: Duration(milliseconds: 150),
                child: _buildControlButton(
                  icon: service.isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: () => service.togglePlayPause(),
                  isLarge: true,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 30),

        // Next button
        _buildControlButton(
          icon: Icons.skip_next,
          onPressed: () => _playerService.next(),
          isLarge: false,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 80 : 60,
      height: isLarge ? 80 : 60,
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: isLarge ? 36 : 28),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      width: 300,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Container(
            width: 150, // Simulated progress
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
