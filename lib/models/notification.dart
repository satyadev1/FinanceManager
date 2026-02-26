/// In-app notification/message. Synced via notifications.csv on Google Drive.
class AppNotification {
  final String? id;
  final String title;
  final String body;
  final String type; // info, offer, reminder
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    this.id,
    required this.title,
    required this.body,
    this.type = 'info',
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'info',
      read: map['read'] == true || map['read'] == 'true',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
