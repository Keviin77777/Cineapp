class TVShow {
  final int id;
  final String name;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String firstAirDate;
  final List<int> genreIds;
  final String? streamUrl;
  final int? seasons;
  final int? views;
  final int? tmdbId;
  final String? categories;

  TVShow({
    required this.id,
    required this.name,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.firstAirDate,
    this.genreIds = const [],
    this.streamUrl,
    this.seasons,
    this.views,
    this.tmdbId,
    this.categories,
  });

  factory TVShow.fromJson(Map<String, dynamic> json) {
    return TVShow(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Sem título',
      overview: json['overview'] ?? 'Sem descrição',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      firstAirDate: json['first_air_date'] ?? '',
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      streamUrl: json['stream_url'],
      seasons: json['seasons'],
      views: json['views'],
      tmdbId: json['tmdb_id'],
      categories: json['categories'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'first_air_date': firstAirDate,
      'genre_ids': genreIds,
      'stream_url': streamUrl,
      'seasons': seasons,
      'views': views,
      'tmdb_id': tmdbId,
      'categories': categories,
    };
  }
}
