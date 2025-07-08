import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models/movie.dart';
import 'models/shimmer.dart';
import 'shared/constants.dart';

class MoviePlayerPage extends StatefulWidget {
  final Movie movie;
  const MoviePlayerPage({super.key, required this.movie});

  @override
  State<MoviePlayerPage> createState() => _MoviePlayerPageState();
}

class _MoviePlayerPageState extends State<MoviePlayerPage> {
  WebViewController? _webViewController;

  bool _isLoadingDetails = false;
  late Movie _movie;
  bool _isFavourite = false;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _isFavourite = favouriteMovieIds.contains(_movie.imdbId);
    _fetchDetailsIfNeeded();
  }

  void _initializePlayer() {
    final allowedUrl = "https://vidsrc.xyz/embed/movie/${_movie.imdbId}";
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (req) {
                return req.url == allowedUrl
                    ? NavigationDecision.navigate
                    : NavigationDecision.prevent;
              },
            ),
          )
          ..loadRequest(Uri.parse(allowedUrl));
  }

  // omdb api
  // Future<void> _fetchDetailsIfNeeded() async {
  //   if (_movie.posterUrl != null && _movie.title != _movie.imdbId) return;

  //   setState(() => _isLoadingDetails = true);

  //   final apiKey = 'key';
  //   final url = 'http://www.omdbapi.com/?i=${_movie.imdbId}&apikey=$apiKey';

  //   final res = await http.get(Uri.parse(url));
  //   if (res.statusCode == 200) {
  //     final data = jsonDecode(res.body);
  //     if (data['Response'] == 'True') {
  //       setState(() {
  //         _movie = _movie.copyWith(
  //           title: data['Title'],
  //           year: data['Year'],
  //           posterUrl: data['Poster'] != 'N/A' ? data['Poster'] : null,
  //           plot: data['Plot'] != 'N/A' ? data['Plot'] : null,
  //           genres: (data['Genre'] as String?)?.split(', ').toList(),
  //           rating:
  //               (data['imdbRating'] != 'N/A')
  //                   ? double.tryParse(data['imdbRating'])
  //                   : null,
  //           votes:
  //               (data['imdbVotes'] != 'N/A')
  //                   ? int.tryParse(data['imdbVotes'].replaceAll(',', ''))
  //                   : null,
  //         );
  //         debugPrint('--> here the movie details $_movie');
  //       });
  //     }
  //   }
  //   setState(() => _isLoadingDetails = false);
  // }

  Future<void> _fetchDetailsIfNeeded() async {
    final existingIndex = topMovies.indexWhere(
      (m) => m.imdbId == _movie.imdbId,
    );

    // If movie exists and already has poster/title (assuming that's enough), skip
    if (existingIndex != -1 &&
        topMovies[existingIndex].posterUrl != null &&
        topMovies[existingIndex].title != topMovies[existingIndex].imdbId) {
      _movie = topMovies[existingIndex];
      _initializePlayer();
      return;
    }

    setState(() => _isLoadingDetails = true);

    try {
      final url = 'https://www.imdb.com/title/${_movie.imdbId}/';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final jsonScript = document.querySelector(
          'script[type="application/ld+json"]',
        );

        if (jsonScript != null) {
          final data = jsonDecode(jsonScript.text);

          final title = data['name'] ?? _movie.imdbId;
          final year = (data['datePublished'] ?? '').toString().substring(0, 4);
          final duration = (data['duration'] ?? 'PT0M').replaceAll(
            RegExp(r'PT|M'),
            '',
          );
          final rating = double.tryParse(
            data['aggregateRating']?['ratingValue']?.toString() ?? '',
          );
          final votes = int.tryParse(
            data['aggregateRating']?['ratingCount']?.toString().replaceAll(
                  ',',
                  '',
                ) ??
                '',
          );
          final plot = data['description'];
          final genres = List<String>.from(data['genre'] ?? []);
          final posterUrl = data['image'] != 'N/A' ? data['image'] : null;

          final updatedMovie = _movie.copyWith(
            title: title,
            year: year,
            posterUrl: posterUrl,
            plot: plot != '' ? plot : null,
            genres: genres,
            runtimeMinutes: int.tryParse(duration),
            rating: rating,
            votes: votes,
          );

          setState(() {
            _movie = updatedMovie;

            if (existingIndex != -1) {
              // Update existing movie in topMovies
              final current = topMovies[existingIndex];
              final merged = current.copyWith(
                title: current.title != current.imdbId ? current.title : title,
                year: current.year != '—' ? current.year : year,
                posterUrl: current.posterUrl ?? posterUrl,
                plot: current.plot ?? plot,
                genres: current.genres ?? genres,
                runtimeMinutes:
                    current.runtimeMinutes ?? int.tryParse(duration),
                rating: current.rating ?? rating,
                votes: current.votes ?? votes,
              );
              topMovies[existingIndex] = merged;
            } else {
              topMovies.add(updatedMovie);
            }
          });

          _initializePlayer();

          // Update SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'topMoviesCache',
            jsonEncode(topMovies.map((e) => e.toJson()).toList()),
          );
          debugPrint('--> Updated topMovies with: $_movie');
        }
      }
    } catch (e) {
      debugPrint('Error scraping IMDb: $e');
    }

    setState(() => _isLoadingDetails = false);
  }

  Future<void> loadFavouriteMovieIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favouriteMovieIds') ?? [];
    favouriteMovieIds = favList;
  }

  Future<void> saveFavouriteMovieIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favouriteMovieIds', favouriteMovieIds);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final movie = _movie;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          movie.title,
          style: GoogleFonts.gabarito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: Column(
        children: [
          // Top 1/3 WebView Player
          SizedBox(
            height: MediaQuery.of(context).size.height / 4,
            child:
                _webViewController != null
                    ? WebViewWidget(controller: _webViewController!)
                    : playerShimmer(context),
          ),

          // Bottom 2/3 Movie Info
          if (_isLoadingDetails)
            movieInfoShimmer(context)
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            movie.posterUrl ?? '',
                            height: 150,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Icon(Icons.image),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Movie Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${movie.title} (${movie.year})',
                                style: GoogleFonts.gabarito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (movie.rating != null)
                                Text(
                                  '⭐ ${movie.rating} / 10  •  ${movie.votes} votes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              if (movie.plot != null)
                                Text(
                                  movie.plot!,
                                  style: TextStyle(fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () async {
                        if (_isFavourite) {
                          favouriteMovieIds.remove(_movie.imdbId);
                        } else {
                          favouriteMovieIds.add(_movie.imdbId);
                        }
                        _isFavourite = !_isFavourite;
                        setState(() {});
                        await saveFavouriteMovieIds();
                      },
                      icon: Icon(
                        _isFavourite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      label: Text(
                        _isFavourite
                            ? 'Remove from Favourites'
                            : 'Add to Favourites',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.red.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
