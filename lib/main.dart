import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';

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
  late final WebViewController _webViewController;
  final TextEditingController _searchController = TextEditingController();

  String? _allowedUrl;

  bool _isLoading = false;
  List<String> _recentSearches = [];
  List<String> _favoriteSearches = [];

  @override
  void initState() {
    super.initState();
    _loadSearches();

    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                setState(() => _isLoading = true);
              },
              onPageFinished: (_) {
                setState(() => _isLoading = false);
              },
              onNavigationRequest: (NavigationRequest request) {
                if (_allowedUrl != null && request.url == _allowedUrl) {
                  return NavigationDecision.navigate;
                }
                return NavigationDecision.prevent;
              },
            ),
          );
  }

  Future<void> _loadSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_imdb_ids') ?? [];
      _favoriteSearches = prefs.getStringList('favorite_imdb_ids') ?? [];
    });
  }

  Future<void> _saveSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_imdb_ids', _recentSearches);
    await prefs.setStringList('favorite_imdb_ids', _favoriteSearches);
  }

  String _extractImdbId(String input) {
    final match = RegExp(r'(tt\d{7,})').firstMatch(input);
    return match?.group(1) ?? input.trim();
  }

  void _toggleFavorite(String imdbId) {
    setState(() {
      if (_favoriteSearches.contains(imdbId)) {
        _favoriteSearches.remove(imdbId);
      } else {
        _favoriteSearches.insert(0, imdbId);
      }
      _saveSearches();
    });
  }

  bool _isFavorite(String imdbId) => _favoriteSearches.contains(imdbId);

  void _loadVideo(String input) {
    final imdbId = _extractImdbId(input);

    // IMDb ID must start with "tt" and be followed by at least 7 digits
    if (!RegExp(r'^tt\d{7,}$').hasMatch(imdbId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a valid IMDb ID or Url (e.g. tt1234567)',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final url = 'https://vidsrc.xyz/embed/movie/$imdbId';

    setState(() {
      _allowedUrl = url;
      _webViewController.loadRequest(Uri.parse(url));

      // Insert and save new valid search
      if (!_recentSearches.contains(imdbId)) {
        _recentSearches.insert(0, imdbId);
        if (_recentSearches.length > 5) {
          _recentSearches.removeLast();
        }
      }

      _saveSearches();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLoadedVideo = _allowedUrl != null;

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
            Expanded(
              child: Stack(
                children: [
                  hasLoadedVideo
                      ? WebViewWidget(controller: _webViewController)
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.ondemand_video_rounded,
                              size: 100,
                              color: scheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Search a movie by IMDb ID",
                              style: GoogleFonts.gabarito(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Example: tt4154796",
                              style: GoogleFonts.gabarito(
                                fontSize: 14,
                                color: scheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                            if (_favoriteSearches.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                "Favorites",
                                style: GoogleFonts.gabarito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Wrap(
                                  spacing: 8,
                                  children:
                                      _favoriteSearches.take(10).map((id) {
                                        return GestureDetector(
                                          onTap: () => _loadVideo(id),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.secondary
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: 18,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  id,
                                                  style: GoogleFonts.gabarito(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: scheme.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],

                            if (_recentSearches.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                "Recent Searches",
                                style: GoogleFonts.gabarito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    _recentSearches.take(5).map((id) {
                                      return GestureDetector(
                                        onTap: () => _loadVideo(id),
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withOpacity(
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.history,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                id,
                                                style: GoogleFonts.gabarito(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                  if (_isLoading)
                    Container(
                      color: scheme.surface.withOpacity(0.6),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),

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
                                _webViewController.loadRequest(
                                  Uri.dataFromString(
                                    '<html><body></body></html>',
                                    mimeType: 'text/html',
                                  ),
                                );
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
                        onSubmitted: _loadVideo,
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
                                  onPressed:
                                      () => _loadVideo(_searchController.text),
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
          ],
        ),
      ),
    );
  }
}
