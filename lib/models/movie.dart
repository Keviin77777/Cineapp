class Movie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;
  final String? streamUrl;
  final String? duration;
  final int? views;
  final int? tmdbId;
  final String? categories;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.releaseDate,
    this.genreIds = const [],
    this.streamUrl,
    this.duration,
    this.views,
    this.tmdbId,
    this.categories,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Sem título',
      overview: json['overview'] ?? 'Sem descrição',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      releaseDate: json['release_date'] ?? '',
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      streamUrl: json['stream_url'],
      duration: json['duration'],
      views: json['views'],
      tmdbId: json['tmdb_id'],
      categories: json['categories'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'release_date': releaseDate,
      'genre_ids': genreIds,
      'stream_url': streamUrl,
      'duration': duration,
      'views': views,
      'tmdb_id': tmdbId,
      'categories': categories,
    };
  }
}
