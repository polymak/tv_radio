import 'dart:async';
import 'package:tv_radio/models/radio_station.dart';
import 'package:just_audio/just_audio.dart';

/// Service for managing radio stations and streaming
/// Supports mp3, icecast, http, and hls streams
class RadioService {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<RadioStation> _stations = RadioStation.stations;
  RadioStation? _currentStation;
  StreamController<RadioStation?> _currentStationController =
      StreamController.broadcast();
  StreamController<bool> _isPlayingController = StreamController.broadcast();

  // Getters
  List<RadioStation> get stations => _stations;
  RadioStation? get currentStation => _currentStation;
  Stream<RadioStation?> get currentStationStream =>
      _currentStationController.stream;
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  /// Load radio stations (using hardcoded stations)
  Future<List<RadioStation>> loadStations() async {
    _stations = RadioStation.stations;
    return _stations;
  }

  /// Play a radio station by URL
  /// Automatically detects stream type based on URL extension
  Future<void> play(String url) async {
    try {
      // Find the station by URL
      final station = _stations.firstWhere(
        (s) => s.streamUrl == url,
        orElse: () => _stations.first,
      );

      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();

      _currentStation = station;
      _currentStationController.add(station);
      _isPlayingController.add(true);
    } catch (e) {
      print('Error playing radio: $e');
      _isPlayingController.add(false);
    }
  }

  /// Play a radio station by RadioStation object
  Future<void> playStation(RadioStation station) async {
    await play(station.streamUrl);
  }

  /// Pause the current stream
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlayingController.add(false);
    } catch (e) {
      print('Error pausing radio: $e');
    }
  }

  /// Stop the current stream
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _currentStation = null;
      _currentStationController.add(null);
      _isPlayingController.add(false);
    } catch (e) {
      print('Error stopping radio: $e');
    }
  }

  /// Check if currently playing
  bool get isPlaying => _audioPlayer.playing;

  /// Get current playback position
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Get current playback state
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    _currentStationController.close();
    _isPlayingController.close();
  }
}
