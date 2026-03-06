import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_radio/models/media_item.dart';
import 'package:tv_radio/services/m3u_parser.dart';

/// Service for managing TV and Radio playlists
/// Supports loading from assets and remote URLs
class PlaylistService {
  static const _tvM3UAssetPath = 'assets/rdc_tv.m3u';
  static const _radioM3UAssetPath = 'assets/rdc_radio.m3u';
  static const _prefsTvUrlKey = 'tv_m3u_url';
  static const _prefsRadioUrlKey = 'radio_m3u_url';

  List<MediaItem> _tvItems = [];
  List<MediaItem> _radioItems = [];
  MediaItem? _selectedTVItem;
  MediaItem? _selectedRadioItem;

  // Singleton instance
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal();

  /// Get list of TV channels
  List<MediaItem> get tvItems => _tvItems;

  /// Get list of Radio stations
  List<MediaItem> get radioItems => _radioItems;

  /// Get currently selected TV item
  MediaItem? get selectedTVItem => _selectedTVItem;

  /// Get currently selected Radio item
  MediaItem? get selectedRadioItem => _selectedRadioItem;

  /// Set selected TV item
  void setSelectedTVItem(MediaItem? item) {
    _selectedTVItem = item;
  }

  /// Set selected Radio item
  void setSelectedRadioItem(MediaItem? item) {
    _selectedRadioItem = item;
  }

  /// Load TV channels from assets
  Future<List<MediaItem>> loadTVFromAssets() async {
    try {
      final content = await rootBundle.loadString(_tvM3UAssetPath);
      _tvItems = M3UParser.parseM3U(content, 'tv');
      return _tvItems;
    } catch (e) {
      print('Error loading TV from assets: $e');
      _tvItems = [];
      return _tvItems;
    }
  }

  /// Load Radio stations from assets
  Future<List<MediaItem>> loadRadioFromAssets() async {
    try {
      final content = await rootBundle.loadString(_radioM3UAssetPath);
      _radioItems = M3UParser.parseM3U(content, 'radio');
      return _radioItems;
    } catch (e) {
      print('Error loading Radio from assets: $e');
      _radioItems = [];
      return _radioItems;
    }
  }

  /// Load playlist from remote URL
  /// [url] - The M3U URL
  /// [mediaType] - 'tv' or 'radio'
  Future<List<MediaItem>> loadFromUrl(String url, String mediaType) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final content = response.body;
        if (M3UParser.isValidM3U(content)) {
          final items = M3UParser.parseM3U(content, mediaType);

          // Save URL to preferences
          await _saveUrlToPrefs(url, mediaType);

          if (mediaType == 'tv') {
            _tvItems = items;
          } else {
            _radioItems = items;
          }

          return items;
        } else {
          throw Exception('Invalid M3U format');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error loading from URL: $e');
      throw Exception('Failed to load playlist: $e');
    }
  }

  /// Load TV channels from URL
  Future<List<MediaItem>> loadTVFromUrl(String url) async {
    return loadFromUrl(url, 'tv');
  }

  /// Load Radio stations from URL
  Future<List<MediaItem>> loadRadioFromUrl(String url) async {
    return loadFromUrl(url, 'radio');
  }

  /// Load both TV and Radio from URLs
  Future<void> loadBothFromUrls(String tvUrl, String radioUrl) async {
    await Future.wait([loadTVFromUrl(tvUrl), loadRadioFromUrl(radioUrl)]);
  }

  /// Get last saved TV URL from preferences
  Future<String?> getLastTVUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsTvUrlKey);
  }

  /// Get last saved Radio URL from preferences
  Future<String?> getLastRadioUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsRadioUrlKey);
  }

  /// Save URL to preferences
  Future<void> _saveUrlToPrefs(String url, String mediaType) async {
    final prefs = await SharedPreferences.getInstance();
    if (mediaType == 'tv') {
      await prefs.setString(_prefsTvUrlKey, url);
    } else {
      await prefs.setString(_prefsRadioUrlKey, url);
    }
  }

  /// Initialize service by loading from assets
  Future<void> initialize() async {
    await loadTVFromAssets();
    await loadRadioFromAssets();

    // Set first items as selected by default
    if (_tvItems.isNotEmpty) {
      _selectedTVItem = _tvItems.first;
    }
    if (_radioItems.isNotEmpty) {
      _selectedRadioItem = _radioItems.first;
    }
  }

  /// Refresh current playlists
  /// Reloads from assets or last saved URLs
  Future<void> refresh() async {
    final tvUrl = await getLastTVUrl();
    final radioUrl = await getLastRadioUrl();

    if (tvUrl != null) {
      await loadTVFromUrl(tvUrl);
    } else {
      await loadTVFromAssets();
    }

    if (radioUrl != null) {
      await loadRadioFromUrl(radioUrl);
    } else {
      await loadRadioFromAssets();
    }
  }
}
