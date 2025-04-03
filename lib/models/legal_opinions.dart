class LegalOpinion {
  final int id;
  final String title;
  final String link;
  final String category;
  final String reference;
  final String date;
  final String downloadLink;
  final String? extractedTexts;

  LegalOpinion({
    required this.id,
    required this.title,
    required this.link,
    required this.category,
    required this.reference,
    required this.date,
    required this.downloadLink,
    this.extractedTexts,
  });

  factory LegalOpinion.fromJson(Map<String, dynamic> json) {
    return LegalOpinion(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      link: json['link'] ?? '',
      category: json['category'] ?? '',
      reference: json['reference'] ?? 'No Reference',
      date: json['date'] ?? 'No Date',
      downloadLink: json['download_link'] != null &&
              json['download_link'].toString().startsWith('http')
          ? json['download_link']
          : '',
      extractedTexts: json['extracted_texts']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'link': link,
      'category': category,
      'reference': reference,
      'date': date,
      'download_link': downloadLink,
      'extracted_texts': extractedTexts,
    };
  }
}
