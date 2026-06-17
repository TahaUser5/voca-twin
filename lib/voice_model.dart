class VoiceModel {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final DateTime createdAt; // ✅ Timestamp for sorting
  final Duration duration; // ✅ Duration for UI display

  VoiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.createdAt,
    required this.duration,
  });

  // ✅ Convert model to JSON for APIs / Local Storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'createdAt': createdAt.toIso8601String(),
      'duration': duration.inSeconds, // Store duration in seconds
    };
  }

  // ✅ Create model from JSON (useful for API responses)
  factory VoiceModel.fromJson(Map<String, dynamic> json) {
    return VoiceModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      audioUrl: json['audioUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      duration: Duration(seconds: json['duration']),
    );
  }
}
