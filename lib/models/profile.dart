class Profile {
  final String id;
  final String name;
  final String avatarUrl;
  final String backgroundColor;

  Profile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.backgroundColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'backgroundColor': backgroundColor,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      backgroundColor: json['backgroundColor'],
    );
  }
}
