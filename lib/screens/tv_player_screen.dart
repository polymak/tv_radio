import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tv_radio/services/tele50_radio_stream_resolver.dart';
import 'package:tv_radio/services/audio_manager.dart';
import 'package:tv_radio/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:tv_radio/models/media_item.dart';

/// Enhanced TV Player Screen with robust initialization and auto-retry for Tele50
class TvPlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;
  final MediaItemModel? mediaItem;

  const TvPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.mediaItem,
  });

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  // Safe nullable controllers to prevent LateInitializationError
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late Tele50RadioStreamResolver _resolver;

  // State management
  bool _isLoading = true;
  String? _errorMessage;
  bool _isReconnecting = false;
  bool _isSoftRefreshing = false;
  Timer? _softRefreshTimer;
  Timer? _reconnectTimer;
  Timer? _autoRetryTimer;

  // Reconnect backoff
  int _reconnectAttempts = 0;
  final List<int> _backoffDelays = [1, 2, 5, 10, 20, 30, 30, 30]; // seconds
  String? _currentResolvedUrl;

  // Télé50 static URL as fallback
  static const String _tele50FallbackUrl =
      'https://stream-195689.castr.net/63dea568fbc24884706157bb/live_08637130250e11f0afb3a374844fe15e/index.fmp4.m3u8';

  @override
  void initState() {
    super.initState();
    _resolver = Tele50RadioStreamResolver();
    _initializePlayer();
    _startSoftRefreshTimer();

    // Enable wakelock to keep screen on during TV playback
    WakelockPlus.enable();

    // Set landscape orientation for TV playback
    _setLandscapeOrientation();
  }

  @override
  void dispose() {
    _disposeControllers();
    _resolver.dispose();
    _softRefreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _autoRetryTimer?.cancel();

    // Disable wakelock when leaving TV player screen
    WakelockPlus.disable();

    super.dispose();
  }

  /// Safe disposal of controllers
  Future<void> _disposeControllers() async {
    final chewie = _chewieController;
    final video = _videoController;
    _chewieController = null;
    _videoController = null;
    chewie?.dispose();
    video?.dispose();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isReconnecting = false;
    });

    await _disposeControllers();

    // Determine the URL to use
    String streamUrl;
    if (widget.mediaItem?.isDynamic == true) {
      // Tele50: resolve URL first
      streamUrl = await _resolveTele50Url();
    } else {
      // Static stream: use provided URL
      streamUrl = widget.streamUrl;
    }

    await _setupPlayer(streamUrl);
  }

  /// Resolve Tele50 URL with fallback
  Future<String> _resolveTele50Url() async {
    try {
      final resolvedUrl = await _resolver.resolve(
        widget.mediaItem?.resolvePageUrl ?? '',
      );
      _currentResolvedUrl = resolvedUrl;
      return resolvedUrl;
    } catch (e) {
      debugPrint('Tele50 URL resolution failed: $e');
      // Fallback to static URL
      return _tele50FallbackUrl;
    }
  }

  /// Setup player with error handling and auto-retry
  Future<void> _setupPlayer(String streamUrl) async {
    try {
      final controller = VideoPlayerController.network(
        streamUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize();

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        allowPlaybackSpeedChanging: false,
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.white,
          backgroundColor: Colors.black26,
          bufferedColor: Colors.black12,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Erreur de lecture\n$errorMessage',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        },
      );

      if (!mounted) {
        await controller.dispose();
        chewie.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _isLoading = false;
        _errorMessage = null;
      });

      // Use AudioManager to coordinate with radio playback
      final audioManager = AudioManager();
      await audioManager.playVideo(controller);

      // Listen for video player events
      controller.addListener(() {
        if (!mounted) return;

        if (controller.value.hasError) {
          // Only auto-reconnect for Tele50 dynamic streams
          if (widget.mediaItem?.isDynamic == true) {
            _handlePlayerError('Video player error');
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = "Impossible de lire le flux Télé50.";
        _isLoading = false;
      });

      // Auto-retry after 2 seconds
      _autoRetryTimer?.cancel();
      _autoRetryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _errorMessage != null) {
          _retryPlayer();
        }
      });
    }
  }

  /// Handle player errors with reconnection logic
  void _handlePlayerError(String error) {
    // Avoid immediate reconnection loops
    if (_isReconnecting) return;

    _handleReconnectError(error);
  }

  /// Handle reconnection with backoff
  void _handleReconnectError(String error) {
    if (!mounted) return;

    _reconnectAttempts++;
    final delaySeconds = _backoffDelays.length > _reconnectAttempts
        ? _backoffDelays[_reconnectAttempts]
        : _backoffDelays.last;

    setState(() {
      _isReconnecting = true;
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      _retryPlayer();
    });
  }

  /// Retry player with fallback URL
  Future<void> _retryPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isReconnecting = false;
    });

    await _disposeControllers();

    // Use fallback URL for retry
    await _setupPlayer(_tele50FallbackUrl);
  }

  /// Start soft refresh timer for Tele50
  void _startSoftRefreshTimer() {
    // Soft refresh every 9 minutes (540 seconds) for Tele50
    if (widget.mediaItem?.isDynamic != true) return;

    _softRefreshTimer?.cancel();
    _softRefreshTimer = Timer.periodic(const Duration(minutes: 9), (
      timer,
    ) async {
      if (!mounted || _isReconnecting) return;

      await _softRefreshTele50();
    });
  }

  /// Soft refresh Tele50 URL
  Future<void> _softRefreshTele50() async {
    if (_isSoftRefreshing) return;

    setState(() {
      _isSoftRefreshing = true;
    });

    try {
      final newUrl = await _resolver.resolve(
        widget.mediaItem?.resolvePageUrl ?? '',
      );

      // Only reload if URL changed
      if (newUrl != _currentResolvedUrl) {
        _currentResolvedUrl = newUrl;
        await _disposeControllers();
        await _setupPlayer(newUrl);
      }
    } catch (e) {
      // Soft refresh errors are not critical, just log
      debugPrint('Soft refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSoftRefreshing = false;
        });
      }
    }
  }

  /// Go back to previous screen
  void _goBack() {
    Navigator.of(context).pop();
  }

  /// Retry button handler
  void _onRetryPressed() {
    _retryPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player (only if initialized)
          if (_chewieController != null &&
              _videoController != null &&
              _videoController!.value.isInitialized)
            Center(child: Chewie(controller: _chewieController!)),

          // Loading State
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Chargement du flux...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Error State with Retry Button
          if (_errorMessage != null && !_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _onRetryPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Réessayer',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Top Overlay (AppBar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _goBack,
                      ),

                      const SizedBox(width: 12),

                      // Channel Title
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Time and Location
                      Row(
                        children: [
                          Text(
                            _getCurrentTime(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'KINSHASA',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Reconnection Overlay
          if (_isReconnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.blueAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Reconnexion…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tentative ${_reconnectAttempts + 1}/8',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Soft Refresh Indicator
          if (_isSoftRefreshing)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Actualisation…',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
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

  /// Set landscape orientation for TV playback
  Future<void> _setLandscapeOrientation() async {
    try {
      // Lock to landscape orientation
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('Failed to set landscape orientation: $e');
    }
  }
}
