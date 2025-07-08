import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'models/movie.dart';
import 'player.dart';
import 'shared/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple);
        final ColorScheme darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const MovieStreamPage(),
        );
      },
    );
  }
}

class MovieStreamPage extends StatefulWidget {
  const MovieStreamPage({super.key});

  @override
  State<MovieStreamPage> createState() => _MovieStreamPageState();
}

class _MovieStreamPageState extends State<MovieStreamPage> {
  final TextEditingController _searchController = TextEditingController();

  String? _allowedUrl;

  @override
  void initState() {
    super.initState();
    _loadSearches();
    _loadOrFetchTopMovies();
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
        setState(() {
          topMovies = movies;
        });
        shouldFetch = false;
      } catch (e) {
        // fallback to fetch
        shouldFetch = true;
      }
    }

    if (shouldFetch) {
      try {
        final freshMovies = await fetchTopTamilMovies();
        setState(() {
          topMovies = freshMovies;
        });
        // cache the result
        prefs.setString(
          'topMoviesCache',
          jsonEncode(freshMovies.map((e) => e.toJson()).toList()),
        );
        prefs.setInt('topMoviesFetchedAt', now);
      } catch (e) {
        print('Failed to fetch top movies: $e');
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
      print("Scraping error: $e");
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
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl ?? '',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
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
                  if (movie.rating != null)
                    Text('⭐ ${movie.rating} / 10 (${movie.votes} votes)'),
                  const SizedBox(height: 10),
                  if (movie.plot != null) Text(movie.plot!),
                  const SizedBox(height: 16),

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
                                child: MoviePlayerPage(movie: movie),
                                duration: const Duration(milliseconds: 300),
                              ),
                            );
                          },
                          icon: const Icon(Icons.ondemand_video),
                          label: const Text('Watch Now'),
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

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recent_imdb_ids') ?? [];
      favoriteSearches = prefs.getStringList('favorite_imdb_ids') ?? [];
    });
  }

  Future<void> _saveSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_imdb_ids', recentSearches);
    await prefs.setStringList('favorite_imdb_ids', favoriteSearches);
  }

  String _extractImdbId(String input) {
    final match = RegExp(r'(tt\d{7,})').firstMatch(input);
    return match?.group(1) ?? input.trim();
  }

  void _toggleFavorite(String imdbId) {
    setState(() {
      if (favoriteSearches.contains(imdbId)) {
        favoriteSearches.remove(imdbId);
      } else {
        favoriteSearches.insert(0, imdbId);
      }
      _saveSearches();
    });
  }

  bool _isFavorite(String imdbId) => favoriteSearches.contains(imdbId);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () => _showMovieDetailsBottomSheet(context, movie),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: movie.posterUrl ?? '',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) =>
                      const Center(child: CircularProgressIndicator()),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLoadedVideo = _allowedUrl != null;
    final favouriteMovies =
        topMovies.where((m) => favouriteMovieIds.contains(m.imdbId)).toList();
    final trendingMovies =
        topMovies.where((m) => !favouriteMovieIds.contains(m.imdbId)).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(
            'IMDb Movie Stream',
            style: GoogleFonts.gabarito(fontWeight: FontWeight.w600),
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  hasLoadedVideo
                      ? SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                final imdbId = _extractImdbId(
                                  _allowedUrl ?? '',
                                );
                                if (RegExp(r'^tt\d{7,}$').hasMatch(imdbId)) {
                                  _toggleFavorite(imdbId);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.secondaryContainer,
                                foregroundColor:
                                    _isFavorite(
                                          _extractImdbId(_allowedUrl ?? ''),
                                        )
                                        ? Colors.amber
                                        : scheme.onSecondaryContainer,
                                shape: const CircleBorder(),
                                // padding: const EdgeInsets.all(12),
                              ),
                              child: Icon(
                                _isFavorite(_extractImdbId(_allowedUrl ?? ''))
                                    ? Icons.star
                                    : Icons.star_border,
                              ),
                            ),

                            ElevatedButton.icon(
                              onPressed: () async {
                                _searchController.clear();

                                _allowedUrl = null;
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 15,
                                ),

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                              icon: const Icon(Icons.close),
                              label: Text(
                                'Close Player',
                                style: GoogleFonts.gabarito(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )
                      : TextField(
                        controller: _searchController,

                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Enter IMDb ID or URL (e.g. tt4154796)',
                          prefixIcon:
                              _searchController.text.trim().isNotEmpty
                                  ? null
                                  : Icon(Icons.search),

                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.trim().isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _allowedUrl = null);
                                  },
                                ),
                              if (_searchController.text.trim().isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.send, color: scheme.primary),
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    final rawInput =
                                        _searchController.text.trim();
                                    final imdbId = _extractImdbId(rawInput);

                                    if (RegExp(
                                      r'^tt\d{7,}$',
                                    ).hasMatch(imdbId)) {
                                      _searchController.text = '';
                                      FocusScope.of(context).unfocus();
                                      Navigator.push(
                                        context,
                                        PageTransition(
                                          type: PageTransitionType.rightToLeft,
                                          child: MoviePlayerPage(
                                            movie: Movie(
                                              imdbId: imdbId,
                                              title: imdbId,
                                              year: '—',
                                              posterUrl: null,
                                              plot: null,
                                              genres: null,
                                              runtimeMinutes: null,
                                              rating: null,
                                              votes: null,
                                              trailerUrl: null,
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Enter a valid IMDb ID or Url (e.g. tt1234567)',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.fixed,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),

                          filled: true,
                          fillColor: scheme.onSurface.withOpacity(0.08),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(40),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: GoogleFonts.gabarito(fontSize: 16),
                      ),
            ),

            // Center(
            //   child: Column(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Icon(
            //         Icons.ondemand_video_rounded,
            //         size: 100,
            //         color: scheme.primary.withOpacity(0.3),
            //       ),
            //       const SizedBox(height: 20),
            //       Text(
            //         "Search a movie by IMDb ID",
            //         style: GoogleFonts.gabarito(
            //           fontSize: 20,
            //           fontWeight: FontWeight.w500,
            //           color: scheme.onSurface.withOpacity(0.6),
            //         ),
            //       ),
            //       const SizedBox(height: 8),
            //       Text(
            //         "Example: tt4154796",
            //         style: GoogleFonts.gabarito(
            //           fontSize: 14,
            //           color: scheme.onSurface.withOpacity(0.4),
            //         ),
            //       ),
            //       if (favoriteSearches.isNotEmpty) ...[
            //         const SizedBox(height: 24),
            //         Text(
            //           "Favorites",
            //           style: GoogleFonts.gabarito(
            //             fontSize: 16,
            //             fontWeight: FontWeight.w600,
            //             color: scheme.primary,
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         SingleChildScrollView(
            //           scrollDirection: Axis.horizontal,
            //           child: Wrap(
            //             spacing: 8,
            //             children:
            //                 favoriteSearches.take(10).map((id) {
            //                   return GestureDetector(
            //                     onTap: () => _loadVideo(id),
            //                     child: Container(
            //                       margin: const EdgeInsets.symmetric(
            //                         vertical: 6,
            //                       ),
            //                       padding: const EdgeInsets.symmetric(
            //                         horizontal: 16,
            //                         vertical: 10,
            //                       ),
            //                       decoration: BoxDecoration(
            //                         color: scheme.secondary.withOpacity(0.12),
            //                         borderRadius: BorderRadius.circular(30),
            //                       ),
            //                       child: Row(
            //                         mainAxisSize: MainAxisSize.min,
            //                         children: [
            //                           const Icon(
            //                             Icons.star,
            //                             size: 18,
            //                             color: Colors.amber,
            //                           ),
            //                           const SizedBox(width: 6),
            //                           Text(
            //                             id,
            //                             style: GoogleFonts.gabarito(
            //                               fontSize: 14,
            //                               fontWeight: FontWeight.w500,
            //                               color: scheme.onSurface,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                   );
            //                 }).toList(),
            //           ),
            //         ),
            //       ],

            //       if (recentSearches.isNotEmpty) ...[
            //         const SizedBox(height: 24),
            //         Text(
            //           "Recent Searches",
            //           style: GoogleFonts.gabarito(
            //             fontSize: 16,
            //             fontWeight: FontWeight.w600,
            //             color: scheme.primary,
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         Wrap(
            //           spacing: 8,
            //           children:
            //               recentSearches.take(5).map((id) {
            //                 return GestureDetector(
            //                   onTap: () => _loadVideo(id),
            //                   child: Container(
            //                     margin: const EdgeInsets.symmetric(vertical: 6),
            //                     padding: const EdgeInsets.symmetric(
            //                       horizontal: 16,
            //                       vertical: 10,
            //                     ),
            //                     decoration: BoxDecoration(
            //                       color: scheme.primary.withOpacity(0.08),
            //                       borderRadius: BorderRadius.circular(30),
            //                     ),
            //                     child: Row(
            //                       mainAxisSize: MainAxisSize.min,
            //                       children: [
            //                         const Icon(Icons.history, size: 18),
            //                         const SizedBox(width: 6),
            //                         Text(
            //                           id,
            //                           style: GoogleFonts.gabarito(
            //                             fontSize: 14,
            //                             fontWeight: FontWeight.w500,
            //                             color: scheme.onSurface,
            //                           ),
            //                         ),
            //                       ],
            //                     ),
            //                   ),
            //                 );
            //               }).toList(),
            //         ),
            //       ],
            //     ],
            //   ),
            // ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (favouriteMovies.isNotEmpty) ...[
                    Text(
                      'Your Favourites',
                      style: GoogleFonts.gabarito(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.7,
                      ),
                      itemBuilder: (context, index) {
                        final movie = favouriteMovies[index];
                        return _buildMovieCard(movie);
                      },
                    ),
                    // const SizedBox(height: 24),
                  ],

                  Text(
                    'Trending Now',
                    style: GoogleFonts.gabarito(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trendingMovies.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      final movie = trendingMovies[index];
                      return _buildMovieCard(movie);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
