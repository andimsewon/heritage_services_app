import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// 손상 감지 AI 서비스: FastAPI 엔드포인트 호출
class AiDetectionService {
  AiDetectionService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 60),
    this.maxRetries = 2,
  });

  final String baseUrl; // 예: http://127.0.0.1:8080
  final Duration timeout;
  final int maxRetries;

  /// 입력 검증
  void _validateInput(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      throw ArgumentError('이미지 데이터가 비어있습니다.');
    }
    if (imageBytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('이미지 크기가 너무 큽니다. (최대 10MB)');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('AI 서버 URL이 설정되지 않았습니다.');
    }
  }

  /// URI 검증
  Uri _validateUri() {
    try {
      final uri = Uri.parse(baseUrl);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw ArgumentError('유효하지 않은 URL 형식입니다: $baseUrl');
      }
      return uri;
    } catch (e) {
      throw ArgumentError('URL 파싱 실패: $baseUrl - $e');
    }
  }

  /// 재시도 로직이 포함된 AI 감지
  Future<AiDetectionResult> detect(Uint8List imageBytes) async {
    _validateInput(imageBytes);
    final baseUri = _validateUri();
    final uri = baseUri.resolve('/ai/damage/infer');

    Exception? lastException;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // 재시도 전 대기 (지수 백오프)
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        return await _detectWithTimeout(uri, imageBytes);
      } on AiModelNotLoadedException {
        // 모델 미로드 오류는 재시도하지 않음
        rethrow;
      } on AiConnectionException catch (e) {
        lastException = e;
        if (attempt < maxRetries) {
          continue; // 재시도
        }
        rethrow;
      } on AiTimeoutException catch (e) {
        lastException = e;
        if (attempt < maxRetries) {
          continue; // 재시도
        }
        rethrow;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          continue; // 재시도
        }
        break;
      }
    }

    // 모든 재시도 실패
    throw lastException ?? Exception('알 수 없는 오류가 발생했습니다.');
  }

  /// 타임아웃이 적용된 실제 감지 요청
  Future<AiDetectionResult> _detectWithTimeout(
    Uri uri,
    Uint8List imageBytes,
  ) async {
    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'damage.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );

      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(timeout);

      return _parseResponse(response);
    } on TimeoutException {
      throw AiTimeoutException(
        'AI 서버 응답 시간이 초과되었습니다. (${timeout.inSeconds}초) 잠시 후 다시 시도해주세요.',
      );
    } catch (e) {
      if (e is AiTimeoutException || 
          e is AiConnectionException || 
          e is AiModelNotLoadedException) {
        rethrow;
      }
      
      // 네트워크 오류 감지
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Connection refused') ||
          errorStr.contains('Network is unreachable')) {
        throw AiConnectionException(
          'AI 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.',
        );
      }
      
      rethrow;
    }
  }

  /// 응답 파싱 및 검증
  AiDetectionResult _parseResponse(http.Response response) {
    if (response.statusCode == 503) {
      throw AiModelNotLoadedException(
        'AI 모델이 아직 로드되지 않았습니다. 서버 관리자에게 문의하세요.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'AI 서버 오류: ${response.statusCode} - ${response.reasonPhrase}\n'
        '응답: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}',
      );
    }

    try {
      final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
      
      // 응답 데이터 검증
      if (!data.containsKey('detections')) {
        throw FormatException('응답에 detections 필드가 없습니다.');
      }

      final detections = (data['detections'] as List? ?? [])
          .map((e) {
            if (e is! Map) {
              throw FormatException('detections 항목이 Map 형식이 아닙니다.');
            }
            return Map<String, dynamic>.from(e);
          })
          .toList();
      
      final grade = data['grade'] as String?;
      final explanation = data['explanation'] as String?;
      final count = data['count'] as int? ?? detections.length;

      return AiDetectionResult(
        detections: detections,
        grade: grade,
        explanation: explanation,
        count: count,
        isSuccess: true,
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('응답 파싱 실패: $e');
    }
  }
}

class AiDetectionResult {
  AiDetectionResult({
    required this.detections,
    this.grade,
    this.explanation,
    this.count,
    this.isSuccess = false,
  });

  final List<Map<String, dynamic>> detections;
  final String? grade;
  final String? explanation;
  final int? count;
  final bool isSuccess;

  /// 결과가 유효한지 확인
  bool get isValid => isSuccess && detections.isNotEmpty;

  /// 최고 신뢰도 점수
  double? get maxConfidence {
    if (detections.isEmpty) return null;
    return detections
        .map((d) => (d['score'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);
  }
}

/// AI 모델이 로드되지 않았을 때 발생하는 예외
class AiModelNotLoadedException implements Exception {
  AiModelNotLoadedException(this.message);
  final String message;

  @override
  String toString() => 'AiModelNotLoadedException: $message';
}

/// AI 서버 연결 오류
class AiConnectionException implements Exception {
  AiConnectionException(this.message);
  final String message;

  @override
  String toString() => 'AiConnectionException: $message';
}

/// AI 서버 타임아웃 오류
class AiTimeoutException implements Exception {
  AiTimeoutException(this.message);
  final String message;

  @override
  String toString() => 'AiTimeoutException: $message';
}
