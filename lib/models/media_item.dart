/// Model representing a media item (TV channel or Radio station)
/// Supports M3U playlist format with EXTINF metadata
class MediaItem {
  /// Display name of the channel/radio station
  final String name;

  /// Stream URL (HLS for TV, MP3/AAC for Radio)
  final String url;

  /// Optional logo URL
  final String? logo;

  /// Optional group title from M3U
  final String? group;

  /// Type of media: 'tv' or 'radio'
  final String type;

  MediaItem({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    required this.type,
  });

  /// Factory constructor to create MediaItem from M3U EXTINF line
  /// Parses attributes like tvg-name, tvg-logo, group-title
  factory MediaItem.fromExtInf(
    String extInfLine,
    String streamUrl,
    String mediaType,
  ) {
    // Extract display name (everything after the last comma)
    String name = streamUrl; // Default to URL if no display name
    if (extInfLine.contains(',')) {
      name = extInfLine.split(',').last.trim();
    }

    // Parse attributes from EXTINF line
    String? logo;
    String? group;

    // Extract tvg-logo attribute
    final logoRegex = RegExp(r'tvg-logo=([^,\s]+)');
    final logoMatch = logoRegex.firstMatch(extInfLine);
    if (logoMatch != null) {
      logo = logoMatch.group(1);
    }

    // Extract group-title attribute
    final groupRegex = RegExp(r'group-title=([^,\s]+)');
    final groupMatch = groupRegex.firstMatch(extInfLine);
    if (groupMatch != null) {
      group = groupMatch.group(1);
    }

    return MediaItem(
      name: name,
      url: streamUrl,
      logo: logo,
      group: group,
      type: mediaType,
    );
  }

  @override
  String toString() {
    return 'MediaItem{name: $name, url: $url, logo: $logo, group: $group, type: $type}';
  }
}
