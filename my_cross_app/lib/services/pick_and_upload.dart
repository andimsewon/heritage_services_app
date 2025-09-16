import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'image_acquire.dart';

class PickAndUpload {
  static Future<void> pickAndUploadImage({
    required String heritageId,
    required String folder, // 'photos' or 'damage_surveys'
    required BuildContext context,
  }) async {
    // ① 이미지 가져오기
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;

    final (Uint8List bytes, sizeGetter) = picked;
    final size = await sizeGetter();

    try {
      // ② 업로드 경로 지정
      final id = const Uuid().v4();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('heritages/$heritageId/$folder/$id.jpg');

      // ③ Firebase Storage 업로드
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // ④ 다운로드 URL 획득
      final url = await storageRef.getDownloadURL();

      // ⑤ Firestore에 메타데이터 저장
      final docRef = FirebaseFirestore.instance
          .collection('heritages')
          .doc(heritageId)
          .collection(folder)
          .doc(id);

      await docRef.set({
        'url': url,
        'title': folder == 'photos' ? '문화유산 현황 사진' : '손상부 조사 사진',
        'desc': folder == 'photos'
            ? '업로드된 문화유산 사진'
            : '업로드된 손상부 조사',
        'width': size.width,
        'height': size.height,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 업로드 성공!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    }
  }
}
