import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tv_radio/models/radio_station.dart';
import 'package:tv_radio/services/tele50_radio_stream_resolver.dart';
import 'package:tv_radio/services/audio_manager.dart';

/// Enhanced radio player service with skip functionality and proper state management
/// Supports MP3, icecast, http, and hls streams with fallback
/// Includes dynamic stream resolution for Tele50 and auto-reconnect for Okapi
class RadioPlayerService with ChangeNotifier {
  static final RadioPlayerService _instance = RadioPlayerService._internal();
  factory RadioPlayerService() => _instance;
  RadioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Tele50RadioStreamResolver _tele50Resolver = Tele50RadioStreamResolver();

  List<RadioStation> _stations = RadioStation.stations;
  RadioStation? _currentStation;
  bool _isPlaying = false;
  bool _isLoading = false;
  int _currentIndex = 0;

  // Auto-reconnect state
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  Timer? _softRefreshTimer;
  int _reconnectAttempts = 0;
  String? _currentTele50Url;

  // Backoff delays in seconds
  final List<int> _reconnectDelays = [1, 2, 5, 10, 20, 30];

  // Getters
  List<RadioStation> get stations => _stations;
  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isReconnecting => _isReconnecting;
  int get currentIndex => _currentIndex;

  // Public access to audio player for AudioManager
  AudioPlayer get audioPlayer => _audioPlayer;

  /// Initialize the service
  Future<void> initialize() async {
    _stations = RadioStation.stations;

    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      final isPlayingNow = state.playing;
      if (_isPlaying != isPlayingNow) {
        _isPlaying = isPlayingNow;
        notifyListeners();
      }
    });

    // Listen to playback errors for auto-reconnect
    _audioPlayer.playbackEventStream.listen(
      (event) {
        // Handle playback errors
      },
      onError: (error) {
        _handlePlaybackError(error);
      },
    );

    // Listen to player state for auto-reconnect
    _audioPlayer.playerStateStream.listen((state) {
      // Monitor for idle state which might indicate an error
      if (state.processingState == ProcessingState.idle && _isPlaying) {
        // This might indicate a playback error, trigger reconnect for Tele50/Okapi
        if (_currentStation != null &&
            (_currentStation!.name == 'Radio Télé50' ||
                _currentStation!.name == 'Radio Okapi')) {
          _startReconnectLoop();
        }
      }
    });
  }

  /// Play a specific station
  Future<void> playStation(RadioStation station) async {
    // Cancel any existing reconnect or soft refresh timers
    _cancelReconnectTimer();
    _cancelSoftRefreshTimer();

    if (_currentStation == station && _isPlaying) {
      return; // Already playing
    }

    // Find the index of the station
    final stationIndex = _stations.indexOf(station);
    if (stationIndex != -1) {
      _currentIndex = stationIndex;
    }

    _isLoading = true;
    _currentStation = station;
    _isReconnecting = false;
    _reconnectAttempts = 0;
    notifyListeners();

    try {
      String streamUrl = station.streamUrl;

      // Handle dynamic streams (Tele50)
      if (station.isDynamic && station.resolvePageUrl != null) {
        streamUrl = await _tele50Resolver.resolve(station.resolvePageUrl!);
        _currentTele50Url = streamUrl;

        // Start soft refresh timer for Tele50 (every 9 minutes)
        _startSoftRefreshTimer(station);
      }

      // Handle headers for Okapi
      if (station.headers != null) {
        await _setAudioSourceWithHeaders(streamUrl, station.headers!);
      } else {
        await _audioPlayer.setUrl(streamUrl);
      }

      await _audioPlayer.play();
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error playing station ${station.name}: $e');
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_currentStation == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    // State will be updated by the playerStateStream listener
  }

  /// Skip to next station
  Future<void> next() async {
    if (_stations.isEmpty) return;

    // Remember if we were playing
    final wasPlaying = _isPlaying;

    // Calculate next index
    int nextIndex = (_currentIndex + 1) % _stations.length;
    _currentIndex = nextIndex;
    final nextStation = _stations[nextIndex];

    try {
      // Stop current stream
      await _audioPlayer.stop();

      // Set new URL
      await _audioPlayer.setUrl(nextStation.streamUrl);

      // Update current station
      _currentStation = nextStation;
      notifyListeners();

      // Auto-play if previously playing
      if (wasPlaying) {
        await _audioPlayer.play();
        _isPlaying = true;
      } else {
        _isPlaying = false;
      }

      notifyListeners();
    } catch (e) {
      print('Error switching to next station ${nextStation.name}: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Skip to previous station
  Future<void> previous() async {
    if (_stations.isEmpty) return;

    // Remember if we were playing
    final wasPlaying = _isPlaying;

    // Calculate previous index
    int prevIndex = (_currentIndex - 1 + _stations.length) % _stations.length;
    _currentIndex = prevIndex;
    final prevStation = _stations[prevIndex];

    try {
      // Stop current stream
      await _audioPlayer.stop();

      // Set new URL
      await _audioPlayer.setUrl(prevStation.streamUrl);

      // Update current station
      _currentStation = prevStation;
      notifyListeners();

      // Auto-play if previously playing
      if (wasPlaying) {
        await _audioPlayer.play();
        _isPlaying = true;
      } else {
        _isPlaying = false;
      }

      notifyListeners();
    } catch (e) {
      print('Error switching to previous station ${prevStation.name}: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentStation = null;
    notifyListeners();
  }

  /// Get current playback position stream
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Get player state stream
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Dispose resources
  @override
  void dispose() {
    _cancelReconnectTimer();
    _cancelSoftRefreshTimer();
    _tele50Resolver.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Set audio source with custom headers (for Okapi)
  Future<void> _setAudioSourceWithHeaders(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      // Try to use just_audio's built-in headers support
      await _audioPlayer.setUrl(url, headers: headers);
    } catch (e) {
      print(
        'Headers not supported by just_audio, falling back to basic URL: $e',
      );
      await _audioPlayer.setUrl(url);
    }
  }

  /// Handle playback errors with auto-reconnect logic
  Future<void> _handlePlaybackError(dynamic error) async {
    if (_currentStation == null || _isReconnecting) {
      return;
    }

    print('Playback error for station ${_currentStation!.name}: $error');

    // Only auto-reconnect for Tele50 and Okapi
    if (_currentStation!.name == 'Radio Télé50' ||
        _currentStation!.name == 'Radio Okapi') {
      await _startReconnectLoop();
    }
  }

  /// Start the auto-reconnect loop with exponential backoff
  Future<void> _startReconnectLoop() async {
    if (_isReconnecting) return;

    _isReconnecting = true;
    notifyListeners();

    while (_isReconnecting && _reconnectAttempts < _reconnectDelays.length) {
      final delaySeconds = _reconnectDelays[_reconnectAttempts];
      print(
        'Tele50/Okapi reconnect attempt ${_reconnectAttempts + 1} in ${delaySeconds}s',
      );

      await Future.delayed(Duration(seconds: delaySeconds));

      if (!_isReconnecting) break; // Check if reconnect was cancelled

      try {
        await _attemptReconnect();
        // If successful, reset attempts and exit loop
        _reconnectAttempts = 0;
        _isReconnecting = false;
        notifyListeners();
        return;
      } catch (e) {
        print('Reconnect attempt ${_reconnectAttempts + 1} failed: $e');
        _reconnectAttempts++;
      }
    }

    // If we exhausted all attempts, stop reconnecting
    _isReconnecting = false;
    _reconnectAttempts = 0;
    notifyListeners();
  }

  /// Attempt to reconnect to the current station
  Future<void> _attemptReconnect() async {
    if (_currentStation == null) {
      throw Exception('No current station to reconnect to');
    }

    String streamUrl = _currentStation!.streamUrl;

    // For Tele50, resolve the URL again
    if (_currentStation!.isDynamic && _currentStation!.resolvePageUrl != null) {
      streamUrl = await _tele50Resolver.resolve(
        _currentStation!.resolvePageUrl!,
      );
      _currentTele50Url = streamUrl;
    }

    // Stop current playback
    await _audioPlayer.stop();

    // Set new source
    if (_currentStation!.headers != null) {
      await _setAudioSourceWithHeaders(streamUrl, _currentStation!.headers!);
    } else {
      await _audioPlayer.setUrl(streamUrl);
    }

    // Start playing
    await _audioPlayer.play();
  }

  /// Start soft refresh timer for Tele50 (every 9 minutes)
  void _startSoftRefreshTimer(RadioStation station) {
    if (!station.isDynamic || station.name != 'Radio Télé50') return;

    _cancelSoftRefreshTimer();

    _softRefreshTimer = Timer.periodic(const Duration(minutes: 9), (
      timer,
    ) async {
      if (_currentStation?.name != 'Radio Télé50' || !_isPlaying) {
        _cancelSoftRefreshTimer();
        return;
      }

      try {
        final newUrl = await _tele50Resolver.resolve(station.resolvePageUrl!);

        // Only reload if URL changed
        if (newUrl != _currentTele50Url) {
          print('Tele50 URL changed, reloading stream');
          _currentTele50Url = newUrl;

          // Reload the stream without stopping playback
          if (station.headers != null) {
            await _setAudioSourceWithHeaders(newUrl, station.headers!);
          } else {
            await _audioPlayer.setUrl(newUrl);
          }
          await _audioPlayer.play();
        }
      } catch (e) {
        print('Soft refresh failed: $e');
      }
    });
  }

  /// Cancel reconnect timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;
  }

  /// Cancel soft refresh timer
  void _cancelSoftRefreshTimer() {
    _softRefreshTimer?.cancel();
    _softRefreshTimer = null;
  }
}
