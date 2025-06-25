class Box {
  final String id;
  final String name;
  final String type;
  final DateTime timestamp;

  Box({
    required this.id,
    required this.name,
    required this.type,
    required this.timestamp,
  });

  factory Box.fromJson(Map<String, dynamic> json) {
    return Box(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}