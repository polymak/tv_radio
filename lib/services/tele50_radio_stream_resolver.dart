import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Custom exception for Tele50 stream resolution failures
class Tele50ResolveException implements Exception {
  final String message;
  final String? url;
  final dynamic cause;

  Tele50ResolveException({required this.message, this.url, this.cause});

  @override
  String toString() {
    return 'Tele50ResolveException: $message${url != null ? ' (URL: $url)' : ''}${cause != null ? ' Caused by: $cause' : ''}';
  }
}

/// Service to resolve dynamic Tele50 radio stream URLs
/// Fetches the latest Castr HLS URL from the Tele50 direct radio page
class Tele50RadioStreamResolver {
  final http.Client _httpClient;
  final Duration _timeout;

  Tele50RadioStreamResolver({http.Client? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 10);

  /// Resolve the current Tele50 stream URL from the direct radio page
  Future<String> resolve(String resolvePageUrl) async {
    try {
      // Fetch the page content with proper headers
      final response = await _httpClient
          .get(
            Uri.parse(resolvePageUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Android) tv_radio/1.0',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
              'Accept-Encoding': 'gzip, deflate, br',
              'Connection': 'keep-alive',
              'Upgrade-Insecure-Requests': '1',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Tele50ResolveException(
          message:
              'Failed to fetch Tele50 page. Status: ${response.statusCode}',
          url: resolvePageUrl,
          cause: 'HTTP ${response.statusCode}',
        );
      }

      final pageContent = response.body;

      // Extract Castr HLS URLs using regex
      final castrUrls = _extractCastrUrls(pageContent);

      if (castrUrls.isEmpty) {
        throw Tele50ResolveException(
          message: 'No Castr HLS URLs found in page content',
          url: resolvePageUrl,
          cause: 'No matching URLs found',
        );
      }

      // Prefer URLs containing "index.fmp4.m3u8", otherwise use the last one
      final preferredUrl = _selectPreferredUrl(castrUrls);

      if (preferredUrl == null) {
        throw Tele50ResolveException(
          message: 'Could not select a preferred URL from found URLs',
          url: resolvePageUrl,
          cause: 'No suitable URL found',
        );
      }

      return preferredUrl;
    } on TimeoutException {
      throw Tele50ResolveException(
        message: 'Timeout while fetching Tele50 page',
        url: resolvePageUrl,
        cause: 'Request timeout',
      );
    } on http.ClientException catch (e) {
      throw Tele50ResolveException(
        message: 'Network error while fetching Tele50 page',
        url: resolvePageUrl,
        cause: e,
      );
    } catch (e) {
      throw Tele50ResolveException(
        message: 'Unexpected error while resolving Tele50 stream',
        url: resolvePageUrl,
        cause: e,
      );
    }
  }

  /// Extract all Castr HLS URLs from page content using regex
  List<String> _extractCastrUrls(String pageContent) {
    // Pattern to match Castr HLS URLs
    // Examples: https://stream-123456.castr.net/.../index.fmp4.m3u8
    final regex = RegExp(
      r'https?://stream-\d+\.castr\.net/[^\s]+\.m3u8',
      caseSensitive: false,
    );

    final matches = regex.allMatches(pageContent);
    final urls = matches.map((match) => match.group(0)!).toList();

    // Remove duplicates while preserving order
    final uniqueUrls = <String>{};
    final result = <String>[];

    for (final url in urls) {
      if (uniqueUrls.add(url)) {
        result.add(url);
      }
    }

    return result;
  }

  /// Select the preferred URL from the list of found URLs
  String? _selectPreferredUrl(List<String> urls) {
    // First, try to find URLs containing "index.fmp4.m3u8"
    final fmp4Urls = urls
        .where((url) => url.toLowerCase().contains('index.fmp4.m3u8'))
        .toList();

    if (fmp4Urls.isNotEmpty) {
      return fmp4Urls.last; // Return the last fmp4 URL
    }

    // If no fmp4 URLs found, return the last URL (most recent)
    return urls.isNotEmpty ? urls.last : null;
  }

  /// Dispose the HTTP client if it was created by this resolver
  void dispose() {
    _httpClient.close();
  }
}
