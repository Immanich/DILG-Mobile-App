class LegalOpinion {
  final int id;
  final String title;
  final String link;
  final String category;
  final String reference;
  final String date;

  LegalOpinion({
    required this.id,
    required this.title,
    required this.link,
    required this.category,
    required this.reference,
    required this.date,
  });

  factory LegalOpinion.fromJson(Map<String, dynamic> json) {
    return LegalOpinion(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      link: json['link'] ?? '',
      category: json['category'] ?? 'Uncategorized',
      reference: json['reference'] ?? 'No Reference',
      date: json['date'] ?? 'No Date',
    );
  }
}
