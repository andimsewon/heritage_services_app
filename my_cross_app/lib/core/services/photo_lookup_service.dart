import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PhotoDoc {
  final String id;
  final String assetId;
  final String year;
  final String partName;
  final String partNo;
  final String face;
  final String direction;
  final String url;
  final int width;
  final int height;
  final Timestamp timestamp;

  PhotoDoc({
    required this.id,
    required this.assetId,
    required this.year,
    required this.partName,
    required this.partNo,
    required this.face,
    required this.direction,
    required this.url,
    required this.width,
    required this.height,
    required this.timestamp,
  });

  factory PhotoDoc.fromMap(String id, Map<String, dynamic> data) => PhotoDoc(
        id: id,
        assetId: data['assetId'] ?? '',
        year: data['year'] ?? '',
        partName: data['partName'] ?? '',
        partNo: data['partNo'] ?? '',
        face: data['face'] ?? '',
        direction: data['direction'] ?? '',
        url: data['url'] ?? '',
        width: data['width'] ?? 0,
        height: data['height'] ?? 0,
        timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      );
}

class PhotoLookupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Find previous year photo matching the criteria
  Future<PhotoDoc?> findPrevYearPhoto({
    required String assetId,
    required String partName,
    required String partNo,
    required String face,
    required String direction,
    required int currentYear,
  }) async {
    if (kDebugMode) {
      print('[PhotoLookupService] Looking for photo: asset=$assetId, part=$partName-$partNo, face=$face, direction=$direction, currentYear=$currentYear');
    }

    try {
      final prevYear = (currentYear - 1).toString();
      
      final query = _firestore
          .collection('heritage_assets')
          .doc(assetId)
          .collection('photos')
          .where('year', isEqualTo: prevYear)
          .where('partName', isEqualTo: partName)
          .where('partNo', isEqualTo: partNo)
          .where('face', isEqualTo: face)
          .where('direction', isEqualTo: direction)
          .orderBy('timestamp', descending: true)
          .limit(1);

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('[PhotoLookupService] No matching photo found for previous year');
        }
        return null;
      }

      final doc = snapshot.docs.first;
      final photo = PhotoDoc.fromMap(doc.id, doc.data());
      
      if (kDebugMode) {
        print('[PhotoLookupService] Found matching photo: ${photo.url}');
      }

      return photo;
    } catch (e) {
      if (kDebugMode) {
        print('[PhotoLookupService] Error finding photo: $e');
      }
      return null;
    }
  }

  /// Get all photos for a specific year and asset
  Future<List<PhotoDoc>> getPhotosForYear({
    required String assetId,
    required String year,
  }) async {
    if (kDebugMode) {
      print('[PhotoLookupService] Getting photos for asset: $assetId, year: $year');
    }

    try {
      final snapshot = await _firestore
          .collection('heritage_assets')
          .doc(assetId)
          .collection('photos')
          .where('year', isEqualTo: year)
          .orderBy('timestamp', descending: true)
          .get();

      final photos = snapshot.docs
          .map((doc) => PhotoDoc.fromMap(doc.id, doc.data()))
          .toList();

      if (kDebugMode) {
        print('[PhotoLookupService] Found ${photos.length} photos for year $year');
      }

      return photos;
    } catch (e) {
      if (kDebugMode) {
        print('[PhotoLookupService] Error getting photos: $e');
      }
      return [];
    }
  }

  /// Save a photo with metadata
  Future<String> savePhoto({
    required String assetId,
    required String year,
    required String partName,
    required String partNo,
    required String face,
    required String direction,
    required String url,
    required int width,
    required int height,
  }) async {
    if (kDebugMode) {
      print('[PhotoLookupService] Saving photo: asset=$assetId, year=$year, part=$partName-$partNo');
    }

    try {
      final docRef = await _firestore
          .collection('heritage_assets')
          .doc(assetId)
          .collection('photos')
          .add({
        'assetId': assetId,
        'year': year,
        'partName': partName,
        'partNo': partNo,
        'face': face,
        'direction': direction,
        'url': url,
        'width': width,
        'height': height,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('[PhotoLookupService] Photo saved with ID: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('[PhotoLookupService] Error saving photo: $e');
      }
      rethrow;
    }
  }
}