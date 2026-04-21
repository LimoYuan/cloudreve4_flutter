/// WebDAV 账户模型
class DavAccountModel {
  final String id;
  final DateTime createdAt;
  final String name;
  final String uri;
  final String password;
  final String options;

  DavAccountModel({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.uri,
    required this.password,
    required this.options,
  });

  factory DavAccountModel.fromJson(Map<String, dynamic> json) {
    return DavAccountModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      name: json['name'] as String,
      uri: json['uri'] as String,
      password: json['password'] as String,
      options: json['options'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'name': name,
      'uri': uri,
      'password': password,
      'options': options,
    };
  }
}
