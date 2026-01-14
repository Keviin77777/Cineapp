class User {
  final int id;
  final String nome;
  final String email;
  final String? senha;

  User({
    required this.id,
    required this.nome,
    required this.email,
    this.senha,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      nome: json['Nome'] ?? '',
      email: json['Email'] ?? '',
      senha: json['Senha'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Nome': nome,
      'Email': email,
      'Senha': senha,
    };
  }
}
