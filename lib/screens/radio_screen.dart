import 'package:flutter/material.dart';
import 'package:tv_radio/models/radio_station.dart';
import 'package:tv_radio/services/radio_service.dart';
import 'package:tv_radio/services/audio_manager.dart';

/// Dedicated radio screen for Android TV
/// Displays list of radio stations with play controls
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final RadioService _radioService = RadioService();
  List<RadioStation> _stations = [];
  RadioStation? _currentStation;
  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRadio();
  }

  Future<void> _initializeRadio() async {
    setState(() {
      _isLoading = true;
    });

    _stations = await _radioService.loadStations();

    // Listen to playback state changes
    _radioService.currentStationStream.listen((station) {
      setState(() {
        _currentStation = station;
      });
    });

    _radioService.isPlayingStream.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _radioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '📻 Radios RDC',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _buildRadioList(),
    );
  }

  Widget _buildRadioList() {
    return Column(
      children: [
        // Now Playing section
        _buildNowPlaying(),

        // Stations list
        Expanded(
          child: ListView.builder(
            itemCount: _stations.length,
            itemBuilder: (context, index) {
              final station = _stations[index];
              final isSelected = _currentStation == station;

              return _buildRadioTile(station, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNowPlaying() {
    if (_currentStation == null) {
      return Container(
        height: 100,
        color: Colors.grey[900],
        child: const Center(
          child: Text(
            'Select a station to play',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    return Container(
      height: 120,
      color: Colors.grey[900],
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Station logo
          _currentStation!.logoAsset != null
              ? Image.asset(
                  _currentStation!.logoAsset!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.radio,
                      size: 60,
                      color: Colors.white,
                    );
                  },
                )
              : const Icon(Icons.radio, size: 60, color: Colors.blueAccent),

          const SizedBox(width: 16),

          // Station info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentStation!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currentStation!.subtitle!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Play/Pause button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 40,
              color: Colors.blueAccent,
            ),
            onPressed: () {
              final audioManager = AudioManager();
              if (_isPlaying) {
                audioManager.stopRadio();
              } else {
                audioManager.playRadioStation(_currentStation!);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(RadioStation station, bool isSelected) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus && _currentStation != station) {
          _radioService.playStation(station);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: station.logoAsset != null
              ? Image.asset(
                  station.logoAsset!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.radio,
                      size: 40,
                      color: Colors.grey,
                    );
                  },
                )
              : Icon(Icons.radio, size: 40, color: Colors.blueAccent),
          title: Text(
            station.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            station.subtitle!,
            style: const TextStyle(fontSize: 14, color: Colors.white54),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.white54,
          ),
          onTap: () {
            final audioManager = AudioManager();
            audioManager.playRadioStation(station);
          },
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radio Settings'),
        content: const Text('Radio streaming settings will be available here.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
