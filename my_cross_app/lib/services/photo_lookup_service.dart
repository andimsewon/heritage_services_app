import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PhotoLookupService {
  PhotoLookupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<PhotoDoc?> findPrevYearPhoto({
    required String assetId,
    required String partName,
    required String partNo,
    required String face,
    required String direction,
    required int currentYear,
  }) async {
    final prevYear = (currentYear - 1).toString();
    final photosRef = _firestore
        .collection('heritage_assets')
        .doc(assetId)
        .collection('photos');

    Query<Map<String, dynamic>> query = photosRef
        .where('year', isEqualTo: prevYear)
        .where('partName', isEqualTo: partName)
        .where('face', isEqualTo: face)
        .where('direction', isEqualTo: direction);

    if (partNo.isNotEmpty) {
      query = query.where('partNo', isEqualTo: partNo);
    }

    final snapshot = await query.orderBy('ts', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) {
      if (kDebugMode) {
        print('[PhotoLookupService] No photo for $assetId/$prevYear '
            '$partName-$partNo-$face-$direction');
      }
      return null;
    }

    final doc = PhotoDoc.fromSnap(snapshot.docs.first);
    if (kDebugMode) {
      print('[PhotoLookupService] Found previous photo ${doc.url}');
    }
    return doc;
  }
}

class PhotoDoc {
  const PhotoDoc({
    required this.id,
    required this.url,
    required this.year,
    required this.partName,
    required this.partNo,
    required this.face,
    required this.direction,
    required this.width,
    required this.height,
    required this.timestamp,
  });

  final String id;
  final String url;
  final String year;
  final String partName;
  final String partNo;
  final String face;
  final String direction;
  final int width;
  final int height;
  final DateTime? timestamp;

  factory PhotoDoc.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return PhotoDoc(
      id: snap.id,
      url: data['url'] as String? ?? '',
      year: data['year'] as String? ?? '',
      partName: data['partName'] as String? ?? '',
      partNo: data['partNo'] as String? ?? '',
      face: data['face'] as String? ?? '',
      direction: data['direction'] as String? ?? '',
      width: (data['width'] as num?)?.toInt() ?? 0,
      height: (data['height'] as num?)?.toInt() ?? 0,
      timestamp: (data['ts'] as Timestamp?)?.toDate(),
    );
  }
}
