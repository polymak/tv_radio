import 'package:flutter/foundation.dart';
import 'package:tv_radio/services/radio_player_service.dart';
import 'package:tv_radio/models/radio_station.dart';
import 'package:tv_radio/services/background_audio_service.dart';
import 'package:video_player/video_player.dart';

/// Central audio manager to ensure only one audio stream plays at a time
/// Manages coordination between radio and TV players
class AudioManager with ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final RadioPlayerService _radioService = RadioPlayerService();
  VideoPlayerController? _currentVideoController;

  bool _isRadioActive = false;
  bool _isVideoActive = false;
  bool _isMuted = false;

  // Getters
  bool get isRadioActive => _isRadioActive;
  bool get isVideoActive => _isVideoActive;
  bool get isMuted => _isMuted;
  bool get isAnyActive => _isRadioActive || _isVideoActive;

  /// Initialize the audio manager
  Future<void> initialize() async {
    await _radioService.initialize();

    // Listen to radio state changes
    _radioService.addListener(() {
      if (_radioService.isPlaying != _isRadioActive) {
        _isRadioActive = _radioService.isPlaying;
        notifyListeners();
      }
    });
  }

  /// Play radio station - stops any active video
  Future<void> playRadio(String stationName) async {
    // Stop video if active
    if (_isVideoActive) {
      await stopVideo();
    }

    // Find and play the station
    final station = _radioService.stations.firstWhere(
      (s) => s.name == stationName,
      orElse: () => _radioService.stations.first,
    );

    await _radioService.playStation(station);
    _isRadioActive = true;
    notifyListeners();
  }

  /// Play radio station by object - stops any active video
  Future<void> playRadioStation(RadioStation station) async {
    // Stop video if active
    if (_isVideoActive) {
      await stopVideo();
    }

    await _radioService.playStation(station);
    _isRadioActive = true;
    notifyListeners();
  }

  /// Play video - stops any active radio
  Future<void> playVideo(VideoPlayerController controller) async {
    // Stop radio if active
    if (_isRadioActive) {
      await stopRadio();
    }

    _currentVideoController = controller;
    await controller.play();
    _isVideoActive = true;
    notifyListeners();
  }

  /// Stop radio playback
  Future<void> stopRadio() async {
    await _radioService.stop();
    _isRadioActive = false;
    notifyListeners();
  }

  /// Stop video playback
  Future<void> stopVideo() async {
    if (_currentVideoController != null) {
      await _currentVideoController!.pause();
      await _currentVideoController!.dispose();
      _currentVideoController = null;
    }
    _isVideoActive = false;
    notifyListeners();
  }

  /// Stop all audio playback
  Future<void> stopAll() async {
    await stopRadio();
    await stopVideo();
    notifyListeners();
  }

  /// Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;

    if (_isRadioActive) {
      // Mute/unmute radio
      if (_isMuted) {
        _radioService.audioPlayer.setVolume(0.0);
      } else {
        _radioService.audioPlayer.setVolume(1.0);
      }
    }

    if (_isVideoActive && _currentVideoController != null) {
      // Mute/unmute video
      _currentVideoController!.setVolume(_isMuted ? 0.0 : 1.0);
    }

    notifyListeners();
  }

  /// Set volume for active player
  Future<void> setVolume(double volume) async {
    if (_isRadioActive) {
      await _radioService.audioPlayer.setVolume(volume);
    }

    if (_isVideoActive && _currentVideoController != null) {
      _currentVideoController!.setVolume(volume);
    }

    _isMuted = volume == 0.0;
    notifyListeners();
  }

  /// Get current volume
  double get currentVolume {
    if (_isRadioActive) {
      return _radioService.audioPlayer.volume;
    }

    if (_isVideoActive && _currentVideoController != null) {
      return _currentVideoController!.value.volume;
    }

    return 1.0;
  }

  /// Get current active station (if any)
  RadioStation? get currentRadioStation =>
      _isRadioActive ? _radioService.currentStation : null;

  /// Dispose resources
  void dispose() {
    stopAll();
    _radioService.dispose();
    super.dispose();
  }
}
