class AppUser {
  const AppUser({required this.id, required this.name, required this.email, required this.organizationName});

  final int id;
  final String name;
  final String email;
  final String organizationName;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    organizationName: (json['organization'] as Map<String, dynamic>)['name'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'organization': {'name': organizationName},
  };
}

class Session {
  const Session({required this.token, required this.user});

  final String token;
  final AppUser user;
}
