class Category {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final bool isSystem;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.isSystem,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        icon: json['icon'],
        color: json['color'],
        isSystem: json['is_system'],
      );
}
