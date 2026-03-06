import 'package:flutter/material.dart';
import 'package:tv_radio/models/radio_station.dart';
import 'package:tv_radio/services/radio_player_service.dart';
import 'package:tv_radio/services/audio_manager.dart';
import 'package:tv_radio/screens/player_screen.dart';
import 'package:tv_radio/screens/tv_player_screen.dart';
import 'package:tv_radio/screens/about_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Media item model for unified TV and radio content
class MediaItemModel {
  final String name;
  final String url;
  final String category; // "tv" or "radio"
  final String sourceType; // "hls", "youtube", "audio"
  final String? logoAsset;
  final bool
  isDynamic; // true for Tele50 (auto-refresh), false for static streams
  final String? resolvePageUrl; // URL to fetch dynamic stream from (Tele50)

  MediaItemModel({
    required this.name,
    required this.url,
    required this.category,
    required this.sourceType,
    this.logoAsset,
    this.isDynamic = false,
    this.resolvePageUrl,
  });
}

/// Home screen with functional search and proper drawer navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late RadioPlayerService _playerService;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  // GlobalKey for proper drawer access
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _playerService = Provider.of<RadioPlayerService>(context, listen: false);
    _playerService.initialize();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<RadioStation> get filteredStations {
    if (_searchQuery.isEmpty) {
      return _playerService.stations;
    }
    return _playerService.stations.where((station) {
      return station.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _openPlayer(RadioStation station) {
    final audioManager = AudioManager();
    audioManager.playRadioStation(station);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerScreen()),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        // Focus the search field
        FocusScope.of(context).requestFocus(_searchFocusNode);
      } else {
        // Clear search and unfocus
        _searchQuery = '';
        _searchController.clear();
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  void _playIfSingleMatch() {
    final matches = filteredStations;
    if (matches.length == 1) {
      _openPlayer(matches.first);
    }
  }

  void _handleMediaItemTap(MediaItemModel item) {
    // Close drawer first
    Navigator.of(context).pop();

    // Handle different media types
    if (item.category == 'radio') {
      // Find the radio station and play it
      final station = _playerService.stations.firstWhere(
        (s) => s.name == item.name,
        orElse: () => _playerService.stations.first,
      );
      _openPlayer(station);
    } else if (item.category == 'tv') {
      if (item.sourceType == 'hls') {
        // Navigate to TV player for HLS streams
        _openTvPlayer(item);
      } else if (item.sourceType == 'youtube') {
        // Show YouTube dialog (for future use if needed)
        _showYouTubeDialog(item);
      }
    }
  }

  void _openTvPlayer(MediaItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvPlayerScreen(
          title: item.name,
          streamUrl: item.url,
          mediaItem: item,
        ),
      ),
    );
  }

  void _showYouTubeDialog(MediaItemModel item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contenu YouTube'),
          content: Text('Cette chaîne est disponible sur YouTube.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _launchURL(item.url);
              },
              child: const Text('Ouvrir'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  void _showTVPlayerDialog(MediaItemModel item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lecteur TV'),
          content: Text('Lecteur TV non implémenté pour: ${item.name}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFFE5E7EB), // light slate
                  Color(0xFFFFFFFF), // white
                ],
                center: Alignment.topLeft,
                radius: 1.5,
              ),
            ),
            child: Column(
              children: [
                // AppBar with search functionality
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Menu button with proper GlobalKey
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black87),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),

                      const SizedBox(width: 16),

                      // Title area or Search field
                      Expanded(
                        child: _isSearching
                            ? TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: "Rechercher une radio…",
                                  hintStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: InputBorder.none,
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            color: Colors.black54,
                                          ),
                                          onPressed: _clearSearch,
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                onSubmitted: (value) {
                                  _playIfSingleMatch();
                                },
                              )
                            : Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.radio,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'TV Radio',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                ],
                              ),
                      ),

                      // Search button or Clear button
                      _isSearching
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black87,
                              ),
                              onPressed: _toggleSearch,
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.black87,
                              ),
                              onPressed: _toggleSearch,
                            ),
                    ],
                  ),
                ),

                // Section label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EN DIRECT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _getCurrentTime(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'KINSHASA',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Underline indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 3,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Station list with search results
                Expanded(
                  child: filteredStations.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'Aucune radio trouvée'
                                : 'Aucune station trouvée',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredStations.length,
                          itemBuilder: (context, index) {
                            final station = filteredStations[index];
                            final isSelected =
                                _playerService.currentStation == station;

                            return _buildStationCard(station, isSelected);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Enhanced drawer with proper TV and radio sections
      drawer: Drawer(
        backgroundColor: Colors.white.withOpacity(0.95),
        child: SafeArea(
          top: true,
          bottom: true,
          child: Column(
            children: [
              // Header with padding to ensure it's below status bar
              Container(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: const Text(
                  'TV Radio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Content area
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // TV Section
                    _buildDrawerSection(
                      'Liste Télévision',
                      _tvMediaItems,
                      isTV: true,
                    ),

                    const Divider(height: 20),

                    // Radio Section
                    _buildDrawerSection(
                      'Liste Radio',
                      _radioMediaItems,
                      isTV: false,
                    ),

                    const Divider(height: 20),

                    // About Section
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Image.asset(
                          'assets/images/logo-app-TVRadio.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                        title: const Text(
                          'À propos',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerSection(
    String title,
    List<MediaItemModel> items, {
    required bool isTV,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: item.logoAsset != null
                  ? Image.asset(
                      item.logoAsset!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    )
                  : (isTV
                        ? Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tv,
                              color: Colors.white,
                              size: 18,
                            ),
                          )
                        : Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.radio,
                              color: Colors.white,
                              size: 18,
                            ),
                          )),
              title: Text(
                item.name,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              onTap: () => _handleMediaItemTap(item),
            );
          },
        ),
      ],
    );
  }

  // TV media items
  List<MediaItemModel> get _tvMediaItems => [
    MediaItemModel(
      name: 'Télé50',
      url:
          'https://stream-195689.castr.net/63dea568fbc24884706157bb/live_08637130250e11f0afb3a374844fe15e/index.fmp4.m3u8',
      category: 'tv',
      sourceType: 'hls',
      logoAsset: 'assets/images/Logo-Tele50.jpg',
      isDynamic: true,
      resolvePageUrl: 'https://tele50.cd/direct-tele/',
    ),
    MediaItemModel(
      name: 'France24',
      url:
          'https://viamotionhsi.netplus.ch/live/eds/france24/browser-HLS8/france24.m3u8',
      category: 'tv',
      sourceType: 'hls',
      logoAsset: 'assets/images/France24.png',
    ),
  ];

  // Radio media items
  List<MediaItemModel> get _radioMediaItems => [
    MediaItemModel(
      name: 'Télé50',
      url:
          'https://stream-195689.castr.net/63dea568fbc24884706157bb/live_4e3fc1404c6e11f0845ad3177da07776/tracks-a1/index.fmp4.m3u8',
      category: 'radio',
      sourceType: 'audio',
      logoAsset: 'assets/images/Logo-Tele50.jpg',
      isDynamic: false,
      resolvePageUrl: null,
    ),
    MediaItemModel(
      name: 'Radio Okapi',
      url: 'http://rs1.radiostreamer.com:8000/;?type=http&nocache=47115',
      category: 'radio',
      sourceType: 'audio',
      logoAsset: 'assets/images/logo-radio-okapi.png',
    ),
    MediaItemModel(
      name: 'Top Congo FM',
      url: 'https://mpbradio.ice.infomaniak.ch/topcongo3-128.mp3',
      category: 'radio',
      sourceType: 'audio',
      logoAsset: 'assets/images/Logo-TopCongo.png',
    ),
    MediaItemModel(
      name: 'RFI',
      url: 'https://rfimonde64k.ice.infomaniak.ch/rfimonde-64.mp3',
      category: 'radio',
      sourceType: 'audio',
      logoAsset: 'assets/images/Logo-RFI.png',
    ),
    MediaItemModel(
      name: 'RFI-Kiswahili',
      url: 'https://rfienswahili64k.ice.infomaniak.ch/rfienswahili-64.mp3',
      category: 'radio',
      sourceType: 'audio',
      logoAsset: 'assets/images/RFI-Kiswahili.png',
    ),
  ];

  Widget _buildStationCard(RadioStation station, bool isSelected) {
    return GestureDetector(
      onTap: () => _openPlayer(station),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Station logo
            station.logoAsset != null
                ? Image.asset(
                    station.logoAsset!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  )
                : Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.radio, color: Colors.white),
                  ),

            const SizedBox(width: 12),

            // Station name only (no subtitle)
            Expanded(
              child: Text(
                station.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Play button
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
