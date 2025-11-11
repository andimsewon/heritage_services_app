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
      print('[AI] 요청 URL: $uri');
      print('[AI] 이미지 크기: ${imageBytes.length} bytes');

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

      print('[AI] 응답 상태 코드: ${response.statusCode}');
      print('[AI] 응답 본문: ${response.body}');

      if (response.statusCode == 503) {
        // AI 모델이 로드되지 않은 경우
        throw AiModelNotLoadedException(
          'AI 모델이 아직 로드되지 않았습니다. 서버 관리자에게 문의하세요.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'AI 서버 오류: ${response.statusCode} - ${response.reasonPhrase}\n응답: ${response.body}',
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final detections = (data['detections'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final grade = data['grade'] as String?;
      final explanation = data['explanation'] as String?;

      print('[AI] 탐지된 객체 수: ${detections.length}');

      return AiDetectionResult(
        detections: detections,
        grade: grade,
        explanation: explanation,
        isSuccess: true,
      );
    } catch (e) {
      print('[AI] 오류 발생: $e');

      // 에러를 그대로 던지기 (더미 데이터 반환하지 않음)
      rethrow;
    }
  }
}

class AiDetectionResult {
  AiDetectionResult({
    required this.detections,
    this.grade,
    this.explanation,
    this.isSuccess = false,
  });

  final List<Map<String, dynamic>> detections;
  final String? grade;
  final String? explanation;
  final bool isSuccess;
}

/// AI 모델이 로드되지 않았을 때 발생하는 예외
class AiModelNotLoadedException implements Exception {
  AiModelNotLoadedException(this.message);
  final String message;

  @override
  String toString() => 'AiModelNotLoadedException: $message';
}
