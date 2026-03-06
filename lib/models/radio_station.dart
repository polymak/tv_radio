/// Model representing a radio station
/// Supports MP3, icecast, http, and hls streams
class RadioStation {
  final int id;
  final String name;
  final String subtitle;
  final String streamUrl;
  final String? logoAsset;
  final String showTitle;
  final String showHost;
  final bool isDynamic;
  final String? resolvePageUrl;
  final Map<String, String>? headers;

  RadioStation({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.streamUrl,
    this.logoAsset,
    required this.showTitle,
    required this.showHost,
    this.isDynamic = false,
    this.resolvePageUrl,
    this.headers,
  });

  /// Getter to detect if stream is HLS
  bool get isHls => streamUrl.toLowerCase().endsWith('.m3u8');

  /// Static list of hardcoded radio stations
  static List<RadioStation> get stations => [
    RadioStation(
      id: 1,
      name: 'Radio Okapi',
      subtitle: 'News & Information',
      streamUrl: 'http://rs1.radiostreamer.com:8000/;?type=http&nocache=47115',
      logoAsset: 'assets/images/logo-radio-okapi.png',
      showTitle: 'Journal Okapi',
      showHost: 'Présenté par Jean-Pierre',
      isDynamic: false,
      resolvePageUrl: null,
      headers: {
        "User-Agent": "Mozilla/5.0 (Android) tv_radio/1.0",
        "Icy-MetaData": "1",
        "Accept": "*/*",
        "Connection": "keep-alive",
      },
    ),
    RadioStation(
      id: 2,
      name: 'Top Congo FM',
      subtitle: 'Music & Entertainment',
      streamUrl: 'https://mpbradio.ice.infomaniak.ch/topcongo3-128.mp3',
      logoAsset: 'assets/images/Logo-TopCongo.png',
      showTitle: 'Top Hits',
      showHost: 'Présenté par Marie',
      isDynamic: false,
      resolvePageUrl: null,
      headers: null,
    ),
    RadioStation(
      id: 3,
      name: 'RFI',
      subtitle: 'International News',
      streamUrl: 'https://rfimonde64k.ice.infomaniak.ch/rfimonde-64.mp3',
      logoAsset: 'assets/images/Logo-RFI.png',
      showTitle: 'Le Monde en Direct',
      showHost: 'Présenté par Pierre',
      isDynamic: false,
      resolvePageUrl: null,
      headers: null,
    ),
    RadioStation(
      id: 4,
      name: 'Radio Télé50',
      subtitle: 'News & Entertainment',
      streamUrl:
          'https://stream-195689.castr.net/63dea568fbc24884706157bb/live_4e3fc1404c6e11f0845ad3177da07776/tracks-a1/index.fmp4.m3u8',
      logoAsset: 'assets/images/Logo-Tele50.jpg',
      showTitle: 'Direct Radio',
      showHost: 'Présenté par Télé50',
      isDynamic: false,
      resolvePageUrl: null,
      headers: null,
    ),
    RadioStation(
      id: 5,
      name: 'RFI-Kiswahili',
      subtitle: 'News & Information',
      streamUrl:
          'https://rfienswahili64k.ice.infomaniak.ch/rfienswahili-64.mp3',
      logoAsset: 'assets/images/RFI-Kiswahili.png',
      showTitle: 'RFI Kiswahili',
      showHost: 'Présenté par RFI',
      isDynamic: false,
      resolvePageUrl: null,
      headers: null,
    ),
  ];

  @override
  String toString() {
    return 'RadioStation{id: $id, name: $name, subtitle: $subtitle, streamUrl: $streamUrl, isHls: $isHls}';
  }
}
