import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';

import '../models/movie.dart';
import '../shared/datasync.dart';
import 'player.dart';

class ImdbSearch extends StatefulWidget {
  const ImdbSearch({super.key});

  @override
  State<ImdbSearch> createState() => _ImdbSearchState();
}

class _ImdbSearchState extends State<ImdbSearch> {
  final TextEditingController _controller = TextEditingController();
  Future<List<MovieSearch>>? _searchResults;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    FocusScope.of(context).unfocus();

    final trimmed = query.trim();
    final imdbIdRegex = RegExp(r'tt\d{7,}');

    // If it's a direct IMDb ID, skip search and open player
    if (imdbIdRegex.hasMatch(trimmed)) {
      final match = imdbIdRegex.firstMatch(trimmed);
      final imdbId = match?.group(0);
      if (imdbId != null) {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.rightToLeft,
            child: MoviePlayer(
              movie: Movie(
                imdbId: imdbId,
                title: '',
                year: '',
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
        return;
      }
    }

    // Otherwise perform regular search
    if (trimmed.isEmpty) return;

    setState(() {
      _searchResults = fetchSearchResults(trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: scheme.onSurface,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          title: Text('', style: GoogleFonts.gabarito(color: scheme.onSurface)),
          backgroundColor: scheme.surface,
          iconTheme: IconThemeData(color: scheme.onSurface),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _controller,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _performSearch,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search movies...',
                        prefixIcon:
                            _controller.text.trim().isEmpty
                                ? Icon(Icons.search, color: scheme.onSurface)
                                : null,
                        suffixIcon:
                            _controller.text.trim().isNotEmpty
                                ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: scheme.onSurface,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    FocusScope.of(context).unfocus();
                                    setState(() => _searchResults = null);
                                  },
                                )
                                : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          // vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: scheme.onSurface.withAlpha(
                          (256 * 0.08).toInt(),
                        ),
                      ),
                      style: GoogleFonts.gabarito(
                        fontSize: 16,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  if (_controller.text.trim().isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.primary.withAlpha((256 * 0.1).toInt()),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.search, color: scheme.primary),
                        onPressed: () => _performSearch(_controller.text),
                        tooltip: 'Search',
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child:
                  _searchResults == null
                      ? Center(
                        child: Text(
                          'Search any movie name to get started.',
                          style: GoogleFonts.gabarito(color: scheme.onSurface),
                        ),
                      )
                      : FutureBuilder<List<MovieSearch>>(
                        future: _searchResults,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError ||
                              snapshot.data == null ||
                              snapshot.data!.isEmpty) {
                            return Center(
                              child: Text(
                                'No results found.',
                                style: GoogleFonts.gabarito(
                                  color: scheme.onSurface,
                                ),
                              ),
                            );
                          }

                          final results = snapshot.data!;
                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: results.length,
                            separatorBuilder:
                                (_, __) => Divider(
                                  height: 24,
                                  color: scheme.onSurface.withAlpha(
                                    (256 * 0.12).toInt(),
                                  ),
                                ),
                            itemBuilder: (_, i) {
                              final movie = results[i];
                              return ListTile(
                                leading:
                                    movie.posterUrl != null
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: movie.posterUrl!,
                                            width: 50,
                                            height: 75,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (_, __, ___) =>
                                                    const Icon(Icons.image),
                                          ),
                                        )
                                        : Icon(
                                          Icons.movie,
                                          color: scheme.primary,
                                        ),
                                title: Text(
                                  '${movie.title} (${movie.year})',
                                  style: GoogleFonts.gabarito(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle:
                                    movie.actors != null
                                        ? Text(
                                          movie.actors!,
                                          style: GoogleFonts.gabarito(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        )
                                        : null,
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  Navigator.push(
                                    context,
                                    PageTransition(
                                      type: PageTransitionType.rightToLeft,
                                      child: MoviePlayer(
                                        movie: Movie(
                                          imdbId: movie.imdbId,
                                          title: movie.title,
                                          year: movie.year,
                                          posterUrl: movie.posterUrl,
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
                                },
                              );
                            },
                          );
                        },
                      ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
