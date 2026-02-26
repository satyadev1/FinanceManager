/// Offer from external API (by card type). Not stored in CSV; fetched when needed.
class Offer {
  final String title;
  final String? description;
  final String? url;
  final String? imageUrl;
  final DateTime? validUntil;

  const Offer({
    required this.title,
    this.description,
    this.url,
    this.imageUrl,
    this.validUntil,
  });

  factory Offer.fromMap(Map<String, dynamic> map) {
    return Offer(
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      url: map['url'] as String?,
      imageUrl: map['image_url'] as String?,
      validUntil: map['valid_until'] != null ? DateTime.tryParse(map['valid_until'] as String) : null,
    );
  }
}
