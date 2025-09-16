// lib/services/image_acquire.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// 이미지를 선택/촬영해서 (bytes, sizeGetter)를 반환.
/// - 모바일: 카메라 우선, 실패/거부 시 갤러리 fallback
/// - 웹: 파일 선택
class ImageAcquire {
  static final _picker = ImagePicker();

  static Future<(Uint8List bytes, Future<ui.Size> Function())?> pick(
      BuildContext context) async {
    try {
      if (kIsWeb) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.image,
          withData: true,
        );
        if (res == null || res.files.single.bytes == null) return null;
        final bytes = res.files.single.bytes!;
        Future<ui.Size> sizeGetter() async {
          final codec = await ui.instantiateImageCodec(bytes);
          final fi = await codec.getNextFrame();
          return ui.Size(
              fi.image.width.toDouble(), fi.image.height.toDouble());
        }

        return (bytes, sizeGetter);
      } else {
        // 카메라 → 실패 시 갤러리
        final shot = await _picker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        final file = shot ??
            await _picker.pickImage(
                source: ImageSource.gallery, imageQuality: 85);
        if (file == null) return null;

        final bytes = await file.readAsBytes();
        Future<ui.Size> sizeGetter() async {
          final codec = await ui.instantiateImageCodec(bytes);
          final fi = await codec.getNextFrame();
          return ui.Size(
              fi.image.width.toDouble(), fi.image.height.toDouble());
        }

        return (bytes, sizeGetter);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
      }
      return null;
    }
  }
}
