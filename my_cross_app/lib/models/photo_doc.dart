import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoDoc {
  final String id;
  final String title;
  final String url; // Firebase Storage URL
  final int width;
  final int height;
  final int bytes;
  final DateTime createdAt;

  PhotoDoc({
    required this.id,
    required this.title,
    required this.url,
    required this.width,
    required this.height,
    required this.bytes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'bytes': bytes,
    'url': url,
    'width': width,
    'height': height,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static PhotoDoc fromSnap(DocumentSnapshot s) {
    final d = s.data() as Map<String, dynamic>;
    return PhotoDoc(
      id: s.id,
      title: d['title'] as String? ?? '',
      url: d['url'] as String? ?? '',
      width: (d['width'] as num?)?.toInt() ?? 0,
      height: (d['height'] as num?)?.toInt() ?? 0,
      bytes: (d['bytes'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
