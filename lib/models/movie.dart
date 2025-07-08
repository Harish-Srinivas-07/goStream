class Movie {
  final String imdbId;
  final String title;
  final String year;
  final String? posterUrl;
  final String? plot;
  final List<String>? genres;
  final int? runtimeMinutes;
  final double? rating;
  final int? votes;
  final String? trailerUrl;

  Movie({
    required this.imdbId,
    required this.title,
    required this.year,
    this.posterUrl,
    this.plot,
    this.genres,
    this.runtimeMinutes,
    this.rating,
    this.votes,
    this.trailerUrl,
  });

  Movie copyWith({
    String? title,
    String? year,
    String? posterUrl,
    String? plot,
    List<String>? genres,
    int? runtimeMinutes,
    double? rating,
    int? votes,
    String? trailerUrl,
  }) {
    return Movie(
      imdbId: imdbId,
      title: title ?? this.title,
      year: year ?? this.year,
      posterUrl: posterUrl ?? this.posterUrl,
      plot: plot ?? this.plot,
      genres: genres ?? this.genres,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      rating: rating ?? this.rating,
      votes: votes ?? this.votes,
      trailerUrl: trailerUrl ?? this.trailerUrl,
    );
  }

  @override
  String toString() {
    return 'Movie(imdbId: $imdbId, title: $title, year: $year, '
        'posterUrl: $posterUrl, plot: $plot, genres: $genres, '
        'runtimeMinutes: $runtimeMinutes, rating: $rating, votes: $votes, '
        'trailerUrl: $trailerUrl)';
  }

  // Optional: JSON serialization
  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      imdbId: json['imdbId'],
      title: json['title'],
      year: json['year'],
      posterUrl: json['posterUrl'],
      plot: json['plot'],
      genres: (json['genres'] as List?)?.map((e) => e as String).toList(),
      runtimeMinutes: json['runtimeMinutes'],
      rating: (json['rating'] as num?)?.toDouble(),
      votes: json['votes'],
      trailerUrl: json['trailerUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imdbId': imdbId,
      'title': title,
      'year': year,
      'posterUrl': posterUrl,
      'plot': plot,
      'genres': genres,
      'runtimeMinutes': runtimeMinutes,
      'rating': rating,
      'votes': votes,
      'trailerUrl': trailerUrl,
    };
  }
}

class MovieSearch {
  final String imdbId;
  final String title;
  final String year;
  final String? posterUrl;
  final String? actors;

  MovieSearch({
    required this.imdbId,
    required this.title,
    required this.year,
    this.posterUrl,
    this.actors,
  });

  @override
  String toString() {
    return '[$imdbId] $title ($year) - $actors\nPoster: $posterUrl';
  }
}
