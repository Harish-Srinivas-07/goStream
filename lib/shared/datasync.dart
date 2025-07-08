import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import 'constants.dart';

final Future<SharedPreferences> _prefsFuture = SharedPreferences.getInstance();

Future<void> loadFavouriteMovieIds() async {
  final prefs = await _prefsFuture;
  final favList = prefs.getStringList('favouriteMovieIds') ?? [];
  favouriteMovieIds = favList;
}

Future<void> saveFavouriteMovieIds() async {
  final prefs = await _prefsFuture;
  await prefs.setStringList('favouriteMovieIds', favouriteMovieIds);
}

Future<List<MovieSearch>> fetchSearchResults(String query) async {
  final url =
      'https://www.imdb.com/find/?q=${Uri.encodeComponent(query)}&s=tt&ttype=ft';
  final headers = {'User-Agent': 'Mozilla/5.0'};

  try {
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final document = parse(response.body);

      final section = document.querySelector(
        '[data-testid="find-results-section-title"]',
      );
      if (section == null) return [];

      final results = section.querySelectorAll('.find-result-item');

      return results.map<MovieSearch>((element) {
        final link = element.querySelector('a[href^="/title/"]');
        final title = link?.text.trim() ?? 'Unknown';
        final imdbId =
            RegExp(
              r'tt\d+',
            ).firstMatch(link?.attributes['href'] ?? '')?.group(0) ??
            '';

        final yearEl = element.querySelector('.ipc-inline-list__item');
        final year = yearEl?.text.trim() ?? '—';

        final actorEl =
            element.querySelectorAll('.ipc-inline-list__item').length > 1
                ? element.querySelectorAll('.ipc-inline-list__item')[1]
                : null;
        final actors = actorEl?.text.trim();

        final posterEl = element.querySelector('img');
        final posterUrl = posterEl?.attributes['src'];

        return MovieSearch(
          imdbId: imdbId,
          title: title,
          year: year,
          posterUrl: posterUrl,
          actors: actors,
        );
      }).toList();
    }
  } catch (e) {
    debugPrint('Error scraping IMDb search: $e');
  }

  return [];
}

Future<void> updateRecentWatches(String imdbId) async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> current = prefs.getStringList('recentWatches') ?? [];

  current.remove(imdbId);
  current.insert(0, imdbId);

  // Keep only top 5
  if (current.length > 5) {
    current.removeRange(5, current.length);
  }

  await prefs.setStringList('recentWatches', current);
}

Future<void> getRecentWatches() async {
  final prefs = await SharedPreferences.getInstance();
  recentWatchIds = prefs.getStringList('recentWatches') ?? [];
}
