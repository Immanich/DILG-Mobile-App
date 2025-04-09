import 'issuances.dart';

class JointCircular {
  final int id;
  final String title;
  final String link;
  final String reference;
  final String date;
  final String downloadLink;

  JointCircular({
    required this.id,
    required this.title,
    required this.link,
    required this.reference,
    required this.date,
    required this.downloadLink,
  });

  factory JointCircular.fromJson(Map<String, dynamic> json) {
    return JointCircular(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      link: json['link'] ?? '',
      reference: json['reference'] ?? 'No Reference',
      date: json['date'] ?? 'No Date',
      downloadLink: json['download_link'] != null &&
              json['download_link'].toString().startsWith('http')
          ? json['download_link']
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'link': link,
      'reference': reference,
      'date': date,
      'download_link': downloadLink,
    };
  }
}
