import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// 손상 감지 AI 서비스: HTTP 엔드포인트 호출, 실패 시 더미 결과 반환
class AiDetectionService {
  AiDetectionService({required this.baseUrl});
  final String baseUrl; // 예: http://127.0.0.1:8081

  Future<List<Map<String, dynamic>>> detect(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('$baseUrl/detect');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/octet-stream'},
            body: imageBytes,
          )
          .timeout(const Duration(milliseconds: 800));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final dets = (data['detections'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        return dets;
      }
      throw Exception('AI ${res.statusCode}: ${res.body}');
    } catch (_) {
      // 더미 결과(2개 박스)
      return [
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
    }
  }
}
