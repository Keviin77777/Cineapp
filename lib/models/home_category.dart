class HomeCategory {
  final int id;
  final String name;
  final DateTime date;

  HomeCategory({
    required this.id,
    required this.name,
    required this.date,
  });

  factory HomeCategory.fromJson(Map<String, dynamic> json) {
    return HomeCategory(
      id: json['id'] ?? 0,
      name: json['Nome'] ?? '',
      date: DateTime.parse(json['Data'] ?? DateTime.now().toIso8601String()),
    );
  }
}
