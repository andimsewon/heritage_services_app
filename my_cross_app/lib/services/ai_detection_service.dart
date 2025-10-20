import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// 손상 감지 AI 서비스: FastAPI 엔드포인트 호출
class AiDetectionService {
  AiDetectionService({required this.baseUrl});
  final String baseUrl; // 예: http://127.0.0.1:8080

  Future<AiDetectionResult> detect(Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/ai/damage/infer');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image', // FastAPI에서 UploadFile = File(...) 로 받는 필드명
            imageBytes,
            filename: 'damage.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'AI 서버 오류: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final detections = (data['detections'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final grade = data['grade'] as String?;
      final explanation = data['explanation'] as String?;

      return AiDetectionResult(
        detections: detections,
        grade: grade,
        explanation: explanation,
      );
    } catch (e) {
      // 실패 시 더미 결과 반환 (개발 단계용)
      final fallbackDetections = [
        {
          'label': '갈라짐',
          'score': 0.91,
          'x': 0.32,
          'y': 0.22,
          'w': 0.22,
          'h': 0.16,
        },
        {
          'label': '오염',
          'score': 0.78,
          'x': 0.62,
          'y': 0.55,
          'w': 0.18,
          'h': 0.14,
        },
      ];

      return AiDetectionResult(
        detections: fallbackDetections,
        grade: 'B',
        explanation: '네트워크 오류로 더미 예측을 반환했습니다. 결과를 확인 후 수정하세요.',
      );
    }
  }
}

class AiDetectionResult {
  AiDetectionResult({
    required this.detections,
    this.grade,
    this.explanation,
  });

  final List<Map<String, dynamic>> detections;
  final String? grade;
  final String? explanation;
}
