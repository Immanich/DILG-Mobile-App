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
      category: json['category'] ?? 'Uncategorized',
      reference: json['reference'] ?? 'No Reference',
      date: json['date'] ?? 'No Date',
      downloadLink: json['download_link'] != null &&
              json['download_link'].toString().startsWith('http')
          ? json['download_link']
          : '',
      extractedTexts: json['extractedTexts']?.toString().trim() ??
          'No extracted text (model)',
    );
  }
}

// class LegalOpinion {
//   final int id;
//   final String title;
//   final String link;
//   final String category;
//   final String reference;
//   final String date;
//   final String downloadLink;
//   final String? extractedTexts;

//   LegalOpinion({
//     required this.id,
//     required this.title,
//     required this.link,
//     required this.category,
//     required this.reference,
//     required this.date,
//     required this.downloadLink,
//     this.extractedTexts,
//   });

//   // factory LegalOpinion.fromJson(Map<String, dynamic> json) {
//   //   return LegalOpinion(
//   //     id: json['id'],
//   //     title: json['title']?.toString().trim() ?? 'Untitled model',
//   //     link: json['link']?.replaceAll(r'\/', '/') ?? '',
//   //     category: json['category']?.toString().trim() ?? 'Uncategorized model',
//   //     reference: json['reference']?.toString().trim() ?? 'No Reference model',
//   //     date: json['date']?.toString().trim() ?? 'No Date model',
//   //     downloadLink: json['download_link'] != null &&
//   //             json['download_link'].toString().startsWith('http')
//   //         ? json['download_link']
//   //         : '',
//   //     extractedTexts: json['extractedTexts']?.toString().trim() ??
//   //         'No extracted text (model)',
//   //   );
//   // }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'title': title,
//       'link': link,
//       'category': category,
//       'reference': reference,
//       'date': date,
//       'download_link': downloadLink,
//       'extracted_texts': extractedTexts ?? '',
//     };
//   }

//   factory LegalOpinion.fromJson(Map<String, dynamic> json) {
//     return LegalOpinion(
//       id: json['id'],
//       title: json['title'] ?? 'Untitled model',
//       // link: json['link'] ?? 'model',
//       link: json['link']?.replaceAll(r'\/', '/') ?? '',
//       category: json['category'] ?? 'Uncategorized model',
//       reference: json['reference'] ?? 'No Reference model',
//       date: json['date'] ?? 'No Date model',
//       // downloadLink: json['download_link'] ?? 'No downloadable link model',
//       downloadLink: (json['download_link'] != null &&
//               json['download_link'].toString().startsWith('http'))
//           ? json['download_link']
//           : '',
//       extractedTexts: json['extractedTexts']?.toString().trim(),
//     );
//   }
// }
