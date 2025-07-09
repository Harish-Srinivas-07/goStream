import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_stream/screens/search.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/movie.dart';
import '../models/shimmer.dart';
import '../shared/constants.dart';
import '../shared/datasync.dart';

class MoviePlayer extends StatefulWidget {
  final Movie movie;
  const MoviePlayer({super.key, required this.movie});

  @override
  State<MoviePlayer> createState() => _MoviePlayerState();
}

class _MoviePlayerState extends State<MoviePlayer> {
  WebViewController? _webViewController;

  bool _isLoadingDetails = false;
  late Movie _movie;
  bool _isFavourite = false;
  List<Movie> randomMovies = [];

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _isFavourite = favouriteMovieIds.contains(_movie.imdbId);
    _fetchDetailsIfNeeded();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        randomMovies = _getRandomMovies(_movie.imdbId);
        updateRecentWatches(_movie.imdbId);
        if (mounted) setState(() {});
      }
    });
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

  List<Movie> _getRandomMovies(String excludeId) {
    final otherMovies = topMovies.where((m) => m.imdbId != excludeId).toList();

    otherMovies.shuffle(Random());

    // Ensure all 10 movies have different imdbId
    final unique = <String>{};
    final result = <Movie>[];

    for (final movie in otherMovies) {
      if (unique.length >= 10) break;
      if (unique.add(movie.imdbId)) {
        result.add(movie);
      }
    }

    return result;
  }

  Widget buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () {
        randomMovies = _getRandomMovies(_movie.imdbId);
        _movie = movie;
        _isFavourite = favouriteMovieIds.contains(_movie.imdbId);
        setState(() {});
        _fetchDetailsIfNeeded();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: movie.posterUrl ?? '',
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) {
                final scheme = Theme.of(context).colorScheme;
                return Shimmer.fromColors(
                  baseColor: scheme.surfaceContainerHighest.withAlpha(
                    (256 * 0.4).toInt(),
                  ),
                  highlightColor: scheme.primary.withAlpha((256 * 0.3).toInt()),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    color: scheme.surfaceContainerHighest,
                  ),
                );
              },
              errorWidget:
                  (context, url, error) =>
                      const Icon(Icons.broken_image, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.gabarito(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final movie = _movie;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          movie.title,
          style: GoogleFonts.gabarito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Movies',
            onPressed: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: ImdbSearch(),
                  duration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
        ],
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

          const SizedBox(height: 20),

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
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: movie.posterUrl ?? '',
                            height: 150,
                            width: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) {
                              final scheme = Theme.of(context).colorScheme;
                              return Shimmer.fromColors(
                                baseColor: scheme.surfaceContainerHighest
                                    .withAlpha((256 * 0.4).toInt()),
                                highlightColor: scheme.primary.withAlpha(
                                  (256 * 0.3).toInt(),
                                ),
                                child: Container(
                                  height: 150,
                                  width: 100,
                                  color: scheme.surfaceContainerHighest,
                                ),
                              );
                            },
                            errorWidget:
                                (context, url, error) =>
                                    const Icon(Icons.broken_image, size: 24),
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
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              if (movie.plot != null)
                                Text(
                                  movie.plot!,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
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
                              _isFavourite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            label: Text(
                              _isFavourite
                                  ? 'Remove from Fav'
                                  : 'Add to Favourites',
                              style: GoogleFonts.gabarito(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.campaign_outlined, size: 30),
                          onPressed: () {
                            final shareText = '''
🎬 ${_movie.title} (${_movie.year})

${_movie.plot ?? 'Download Go Stream now!'}

⭐ ${_movie.rating?.toStringAsFixed(1) ?? '-'} / 10 (${_movie.votes ?? '-'} votes)
Genres: ${_movie.genres?.join(', ') ?? 'N/A'}
Runtime: ${_movie.runtimeMinutes ?? 'N/A'} minutes

Watch on IMDb:
https://www.imdb.com/title/${_movie.imdbId}/
''';

                            SharePlus.instance.share(
                              ShareParams(
                                text: shareText,
                                title: 'Check out this movie: ${_movie.title}',
                              ),
                            );
                          },
                          tooltip: 'Share Movie',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.rocket_launch_outlined,
                            size: 28,
                          ),
                          tooltip: 'Open in Browser',
                          onPressed: () async {
                            final streamUrl =
                                'https://vidsrc.xyz/embed/movie/${_movie.imdbId}';
                            final uri = Uri.parse(streamUrl);

                            try {
                              final launched = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!launched) throw Exception('Launch failed');
                            } catch (e) {
                              // Fallback: Copy to clipboard
                              await Clipboard.setData(
                                ClipboardData(text: streamUrl),
                              );

                              if (!mounted) return;
                              final scheme = Theme.of(context).colorScheme;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Link copied to clipboard!',
                                    style: GoogleFonts.gabarito(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                  backgroundColor: scheme.primary,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "If streaming is not good, try opening in browser.",
                      style: GoogleFonts.gabarito(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Divider(),

                    const SizedBox(height: 24),
                    // more like this
                    if (randomMovies.length > 1) ...[
                      Text(
                        'More Like This'.toUpperCase(),
                        style: GoogleFonts.gabarito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: randomMovies.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.6,
                            ),
                        itemBuilder: (context, index) {
                          final movie = randomMovies[index];
                          return buildMovieCard(movie);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
