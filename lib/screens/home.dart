import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../models/movie.dart';
import '../models/shimmer.dart';
import 'player.dart';
import '../shared/constants.dart';
import '../shared/datasync.dart';
import 'search.dart';
import 'settings.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController _searchController = TextEditingController();
  int _trendingLoadedCount = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 600) {
        _loadMoreTrending();
      }
    });
    getRecentWatches();
    loadFavouriteMovieIds();
    _loadOrFetchTopMovies();
  }

  bool _isLoadingMore = false;

  void _loadMoreTrending() {
    if (_isLoadingMore) return;

    final trendingMovies =
        topMovies.where((m) => !favouriteMovieIds.contains(m.imdbId)).toList();

    if (_trendingLoadedCount < trendingMovies.length) {
      _isLoadingMore = true;

      // Immediately trigger UI update to show shimmer
      setState(() {});

      Future.delayed(const Duration(milliseconds: 500), () {
        _trendingLoadedCount = (_trendingLoadedCount + 10).clamp(
          0,
          trendingMovies.length,
        );
        _isLoadingMore = false;
        setState(() {});
      });
    }
  }

  Future<void> _loadOrFetchTopMovies() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('topMoviesCache');
    final lastFetched = prefs.getInt('topMoviesFetchedAt');

    final now = DateTime.now().millisecondsSinceEpoch;
    final oneDayMs = 24 * 60 * 60 * 1000;

    bool shouldFetch = true;

    if (cachedJson != null &&
        lastFetched != null &&
        now - lastFetched < oneDayMs) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final List<Movie> movies =
            decoded.map((e) => Movie.fromJson(e)).toList();
        topMovies = movies;
        setState(() {});
        shouldFetch = false;
      } catch (e) {
        debugPrint('Cache decode error: $e');
        shouldFetch = true;
      }
    } else {
      debugPrint('No valid cache found. Will fetch from IMDb.');
    }

    if (shouldFetch) {
      try {
        final freshMovies = await fetchTopTamilMovies();
        debugPrint('Fetched ${freshMovies.length} top Tamil movies from IMDb');
        topMovies = freshMovies;
        setState(() {});
        // cache the result
        prefs.setString(
          'topMoviesCache',
          jsonEncode(freshMovies.map((e) => e.toJson()).toList()),
        );
        prefs.setInt('topMoviesFetchedAt', now);
      } catch (e) {
        debugPrint('Failed to fetch top movies: $e');
      }
    }
  }

  Future<List<Movie>> fetchTopTamilMovies() async {
    const url =
        'https://www.imdb.com/search/title/?title_type=feature&primary_language=ta';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final script = document.getElementById('__NEXT_DATA__');

        if (script != null) {
          final data = jsonDecode(script.text);
          final titles =
              data["props"]["pageProps"]["searchResults"]["titleResults"]["titleListItems"];

          return titles.take(50).map<Movie>((movie) {
            final imdbId = movie["titleId"] ?? '';
            return Movie(
              imdbId: imdbId,
              title: movie["titleText"] ?? 'N/A',
              year: (movie["releaseYear"] ?? 'N/A').toString(),

              posterUrl: movie["primaryImage"]?["url"] ?? '',
              plot: movie["plot"] ?? '',
              genres: List<String>.from(movie["genres"] ?? []),
              runtimeMinutes: (movie["runtime"] ?? 0) ~/ 60,
              rating:
                  (movie["ratingSummary"]?["aggregateRating"] as num?)
                      ?.toDouble(),
              votes: movie["ratingSummary"]?["voteCount"],
              trailerUrl:
                  movie["trailerId"] != null
                      ? "https://www.imdb.com/video/${movie["trailerId"]}"
                      : null,
            );
          }).toList();
        }
      }

      return [];
    } catch (e) {
      debugPrint("Scraping error: $e");
      return [];
    }
  }

  void _showMovieDetailsBottomSheet(BuildContext context, Movie movie) {
    bool isFavourite = favouriteMovieIds.contains(movie.imdbId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final scheme = Theme.of(context).colorScheme;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 5),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl ?? '',
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Shimmer.fromColors(
                            baseColor: scheme.surfaceContainerHighest.withAlpha(
                              (256 * 0.4).toInt(),
                            ),
                            highlightColor: scheme.primary.withAlpha(
                              (256 * 0.3).toInt(),
                            ),
                            child: Container(
                              height: 300,
                              width: double.infinity,
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                      errorWidget:
                          (context, url, error) =>
                              const Icon(Icons.image_not_supported),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${movie.title} (${movie.year})',
                    style: GoogleFonts.gabarito(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),

                  if (movie.rating != null)
                    Text(
                      '⭐ ${movie.rating} /10 with ${movie.votes} votes',
                      style: GoogleFonts.gabarito(),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    movie.plot ?? '',
                    style: GoogleFonts.poppins(fontSize: 13),
                    textAlign: TextAlign.justify,
                  ),

                  const SizedBox(height: 20),

                  // Watch Now + Favourite Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.rightToLeft,
                                child: MoviePlayer(movie: movie),
                              ),
                            ).then((_) {
                              getRecentWatches();
                            });
                          },
                          icon: const Icon(Icons.play_circle_filled_outlined),
                          label: Text(
                            'Watch Now',
                            style: GoogleFonts.gabarito(fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () async {
                          setState(() {
                            if (isFavourite) {
                              favouriteMovieIds.remove(movie.imdbId);
                            } else {
                              favouriteMovieIds.add(movie.imdbId);
                            }
                            isFavourite = !isFavourite;
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList(
                            'favouriteMovieIds',
                            favouriteMovieIds,
                          );
                        },
                        icon: Icon(
                          isFavourite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red,
                        ),
                        tooltip:
                            isFavourite
                                ? 'Remove from Favourites'
                                : 'Add to Favourites',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () => _showMovieDetailsBottomSheet(context, movie),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: movie.posterUrl ?? '',
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Center(child: movieCardShimmer(context)),
              errorWidget: (context, url, error) => const Icon(Icons.image),
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

  Widget recentWatchesList({
    required List<Movie> recentMovies,
    required ColorScheme scheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently Watched'.toUpperCase(),
          style: GoogleFonts.gabarito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentMovies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              final movie = recentMovies[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: MoviePlayer(movie: movie),
                      duration: const Duration(milliseconds: 300),
                    ),
                  ).then((_) => getRecentWatches());
                },
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: scheme.inversePrimary.withAlpha((256 * 0.2).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: movie.posterUrl ?? '',
                          width: 36,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Shimmer.fromColors(
                                baseColor: scheme.surfaceContainerHighest
                                    .withAlpha((256 * 0.4).toInt()),
                                highlightColor: scheme.primary.withAlpha(
                                  (256 * 0.3).toInt(),
                                ),
                                child: Container(
                                  width: 36,
                                  height: 48,
                                  color: scheme.surfaceContainerHighest,
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 18),
                        ),
                      ),

                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.gabarito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (movie.rating != null)
                                  Text(
                                    '⭐ ${movie.rating?.toStringAsFixed(1)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: scheme.primary,
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  movie.year,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: scheme.onSurface.withAlpha(
                                      (256 * 0.7).toInt(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final favouriteMovies =
        topMovies.where((m) => favouriteMovieIds.contains(m.imdbId)).toList();
    final trendingAll =
        topMovies.where((m) => !favouriteMovieIds.contains(m.imdbId)).toList();
    final trendingToDisplay = trendingAll.take(_trendingLoadedCount).toList();

    final recentMovies =
        recentWatchIds
            .map((id) {
              try {
                return topMovies.firstWhere((m) => m.imdbId == id);
              } catch (_) {
                return null;
              }
            })
            .where((m) => m != null)
            .cast<Movie>()
            .toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.surface,
          elevation: 0,
          title: null,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(25),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // app logo
                  // Padding(
                  //   padding: const EdgeInsets.only(right: 8),
                  //   child: Image.asset('assets/logo.png', height: 35),
                  // ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: ImdbSearch(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withAlpha(
                            (256 * 0.08).toInt(),
                          ),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: scheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Search movies...',
                              style: GoogleFonts.gabarito(
                                fontSize: 16,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  IconButton(
                    icon: Icon(
                      Icons.explore_outlined,
                      color: scheme.primary,
                      size: 35,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: const SettingsPage(),
                        ),
                      ).then((_) {
                        _loadOrFetchTopMovies();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  if (recentMovies.isNotEmpty) ...[
                    recentWatchesList(
                      recentMovies: recentMovies,
                      scheme: scheme,
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (favouriteMovies.isNotEmpty) ...[
                    Text(
                      '❤️ Your Favourites'.toUpperCase(),
                      style: GoogleFonts.gabarito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: favouriteMovies.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.6,
                      ),
                      itemBuilder: (context, index) {
                        final movie = favouriteMovies[index];
                        return buildMovieCard(movie);
                      },
                    ),
                    // const SizedBox(height: 24),
                  ],

                  if (trendingToDisplay.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '🔥 Trending Now'.toUpperCase(),
                        style: GoogleFonts.gabarito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount:
                          (_trendingLoadedCount < trendingAll.length)
                              ? _trendingLoadedCount + 4
                              : _trendingLoadedCount,

                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 18,
                        childAspectRatio: .65,
                      ),
                      itemBuilder: (context, index) {
                        if (index >= trendingToDisplay.length) {
                          return movieCardShimmer(context);
                        }

                        final movie = trendingToDisplay[index];
                        return buildMovieCard(movie);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
