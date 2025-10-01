// lib/services/pick_and_upload.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'image_acquire.dart';
import 'firebase_service.dart';

class PickAndUpload {
  static final _fb = FirebaseService();

  /// 사진 선택/촬영 → Storage 업로드 → Firestore 기록
  static Future<void> pickAndUploadImage({
    required String heritageId,
    required String heritageName,
    required String folder, // 'photos' or 'damage_surveys'
    required BuildContext context,
    String? fixedTitle,
  }) async {
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;

    final (Uint8List bytes, Future<ui.Size> Function() sizeGetter) = picked;

    String title = fixedTitle ?? '';
    if (fixedTitle == null && folder == 'photos') {
      // 제목 입력 다이얼로그 (현황 사진일 때만)
      final c = TextEditingController();
      if (!context.mounted) return null;
      final t = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('사진 제목 입력'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: '예: 남측면 전경'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('등록'),
            ),
          ],
        ),
      );
      if (t == null || t.isEmpty) return;
      title = t;
    }

    try {
      // 업로드 시작 알림
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진을 업로드하는 중...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _fb.addPhoto(
        heritageId: heritageId,
        heritageName: heritageName,
        title: title.isEmpty
            ? (folder == 'photos' ? '문화유산 현황 사진' : '손상부 조사 원본')
            : title,
        imageBytes: bytes,
        sizeGetter: sizeGetter,
        folder: folder,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 업로드 성공!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = '업로드 실패: ';
        if (e.toString().contains('permission')) {
          errorMessage += '권한이 없습니다. Firebase 설정을 확인해주세요.';
        } else if (e.toString().contains('network')) {
          errorMessage += '네트워크 연결을 확인해주세요.';
        } else if (e.toString().contains('size')) {
          errorMessage += '파일 크기가 너무 큽니다.';
        } else {
          errorMessage += e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
