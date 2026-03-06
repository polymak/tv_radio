import 'package:tv_radio/models/media_item.dart';

/// Service for parsing M3U playlist files
/// Handles #EXTM3U, #EXTINF lines and stream URLs
class M3UParser {
  /// Parse M3U content from string and return list of MediaItems
  ///
  /// [content] - The M3U file content as string
  /// [mediaType] - Either 'tv' or 'radio' to categorize the items
  ///
  /// Returns list of MediaItem objects
  static List<MediaItem> parseM3U(String content, String mediaType) {
    final lines = content.split('\n');
    final List<MediaItem> items = [];
    String? currentExtInf;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith('#')) {
        // Store EXTINF line for next iteration
        if (line.startsWith('#EXTINF:')) {
          currentExtInf = line;
        }
        continue;
      }

      // Process stream URL line
      if (currentExtInf != null && line.isNotEmpty) {
        try {
          final item = MediaItem.fromExtInf(currentExtInf, line, mediaType);
          items.add(item);
        } catch (e) {
          // Skip malformed entries
          print('Error parsing M3U entry: $e');
        }
        currentExtInf = null;
      }
    }

    return items;
  }

  /// Parse M3U content from lines list
  /// Alternative method for when you already have lines
  static List<MediaItem> parseM3ULines(List<String> lines, String mediaType) {
    return parseM3U(lines.join('\n'), mediaType);
  }

  /// Validate if content is a valid M3U format
  /// Checks for #EXTM3U header
  static bool isValidM3U(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('#EXTM3U') || trimmed.startsWith('#EXTINF:');
  }

  /// Extract metadata from EXTINF line
  /// Returns map of attributes like tvg-name, tvg-logo, group-title
  static Map<String, String> extractExtInfAttributes(String extInfLine) {
    final attributes = <String, String>{};

    // Extract tvg-name
    final nameRegex = RegExp(r'tvg-name=([^,\s]+)');
    final nameMatch = nameRegex.firstMatch(extInfLine);
    if (nameMatch != null) {
      attributes['tvg-name'] = nameMatch.group(1) ?? '';
    }

    // Extract tvg-logo
    final logoRegex = RegExp(r'tvg-logo=([^,\s]+)');
    final logoMatch = logoRegex.firstMatch(extInfLine);
    if (logoMatch != null) {
      attributes['tvg-logo'] = logoMatch.group(1) ?? '';
    }

    // Extract group-title
    final groupRegex = RegExp(r'group-title=([^,\s]+)');
    final groupMatch = groupRegex.firstMatch(extInfLine);
    if (groupMatch != null) {
      attributes['group-title'] = groupMatch.group(1) ?? '';
    }

    return attributes;
  }
}
