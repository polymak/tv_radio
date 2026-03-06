import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tv_radio/models/radio_station.dart';
import 'package:tv_radio/services/tele50_radio_stream_resolver.dart';

/// Background audio handler for radio playback with system media controls
class BackgroundAudioHandler extends BaseAudioHandler {
  final Tele50RadioStreamResolver _tele50Resolver = Tele50RadioStreamResolver();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentTele50Url;
  Timer? _softRefreshTimer;

  BackgroundAudioHandler() {
    // Initialize audio player
    _setupAudioPlayer();

    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      final playing = state.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[state.processingState]!,
          playing: playing,
        ),
      );
    });

    // Listen to playback errors
    _audioPlayer.playbackEventStream.listen(
      (event) {
        // Handle playback errors
      },
      onError: (error) {
        print('Audio playback error: $error');
      },
    );
  }

  void _setupAudioPlayer() {
    // Configure audio player for background playback
    // Note: AudioAttributes API may vary, using basic configuration
  }

  /// Play a radio station with background audio support
  Future<void> playRadioStation(RadioStation station) async {
    // Stop current playback
    await _audioPlayer.stop();

    // Clear soft refresh timer
    _softRefreshTimer?.cancel();

    // Prepare media item
    final mediaItem = MediaItem(
      id: station.streamUrl,
      title: station.name,
      artist: station.subtitle,
      album: station.showTitle,
      artUri: _getArtUri(station),
    );

    // Set media item
    // Note: MediaItem doesn't have add method, this line is not needed

    // Resolve stream URL if needed
    String streamUrl = station.streamUrl;
    if (station.isDynamic && station.resolvePageUrl != null) {
      try {
        streamUrl = await _tele50Resolver.resolve(station.resolvePageUrl!);
        _currentTele50Url = streamUrl;

        // Start soft refresh timer for Tele50 (every 9 minutes)
        _startSoftRefreshTimer(station);
      } catch (e) {
        print('Failed to resolve Tele50 URL: $e');
      }
    }

    // Set audio source
    if (station.headers != null) {
      await _audioPlayer.setUrl(streamUrl, headers: station.headers);
    } else {
      await _audioPlayer.setUrl(streamUrl);
    }

    // Start playback
    await _audioPlayer.play();

    // Update playback state
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.ready,
        playing: true,
      ),
    );
  }

  /// Pause playback
  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  /// Play playback
  @override
  Future<void> play() async {
    await _audioPlayer.play();
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  /// Stop playback
  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    _softRefreshTimer?.cancel();
    _currentTele50Url = null;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  /// Skip to previous (not implemented for radio)
  @override
  Future<void> skipToPrevious() async {
    // Radio doesn't have previous/next, but we keep this for system compatibility
  }

  /// Skip to next (not implemented for radio)
  @override
  Future<void> skipToNext() async {
    // Radio doesn't have previous/next, but we keep this for system compatibility
  }

  /// Get art URI for media item
  Uri? _getArtUri(RadioStation station) {
    if (station.logoAsset != null) {
      final assetPath = station.logoAsset!;
      // Convert asset path to file URI
      if (assetPath.startsWith('assets/')) {
        return Uri.file(assetPath);
      }
    }
    return null;
  }

  /// Start soft refresh timer for Tele50
  void _startSoftRefreshTimer(RadioStation station) {
    if (!station.isDynamic || station.name != 'Radio Télé50') return;

    _softRefreshTimer?.cancel();
    _softRefreshTimer = Timer.periodic(const Duration(minutes: 9), (
      timer,
    ) async {
      if (playbackState.value.playing && _currentTele50Url != null) {
        try {
          final newUrl = await _tele50Resolver.resolve(station.resolvePageUrl!);

          // Only reload if URL changed
          if (newUrl != _currentTele50Url) {
            print('Tele50 URL changed, reloading stream');
            _currentTele50Url = newUrl;

            // Reload the stream without stopping playback
            if (station.headers != null) {
              await _audioPlayer.setUrl(newUrl, headers: station.headers);
            } else {
              await _audioPlayer.setUrl(newUrl);
            }
            await _audioPlayer.play();
          }
        } catch (e) {
          print('Soft refresh failed: $e');
        }
      }
    });
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    _softRefreshTimer?.cancel();
    _tele50Resolver.dispose();
    await _audioPlayer.dispose();
    // Note: BaseAudioHandler may not have dispose method in this version
  }
}
