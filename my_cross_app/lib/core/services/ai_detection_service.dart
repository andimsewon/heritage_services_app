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

  /// baseUrl에 경로가 포함된 경우에도 안전하게 엔드포인트를 생성
  Uri _buildEndpointUri(Uri baseUri, String endpointPath) {
    final endpointSegments = endpointPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final combinedSegments = [
      ...baseUri.pathSegments,
      ...endpointSegments,
    ];
    return baseUri.replace(pathSegments: combinedSegments);
  }

  /// 재시도 로직이 포함된 AI 감지
  Future<AiDetectionResult> detect(Uint8List imageBytes) async {
    _validateInput(imageBytes);
    final baseUri = _validateUri();
    final uri = _buildEndpointUri(baseUri, 'ai/damage/infer');

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
      } on AiServerException catch (e) {
        // 500 에러는 서버 측 문제이므로 재시도 가능
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

  /// AI 모델 상태 조회
  Future<AiModelStatus> fetchModelStatus() async {
    final baseUri = _validateUri();
    final uri = _buildEndpointUri(baseUri, 'ai/model/status');

    try {
      final response = await http.get(uri).timeout(timeout);
      return _parseModelStatusResponse(response);
    } on TimeoutException {
      throw AiTimeoutException(
        'AI 모델 상태 조회 시간이 초과되었습니다. (${timeout.inSeconds}초) 잠시 후 다시 시도해주세요.',
      );
    } catch (e) {
      final errorStr = e.toString();
      if (_looksLikeNetworkError(errorStr)) {
        throw AiConnectionException(
          'AI 모델 상태를 확인할 수 없습니다. 서버 연결을 확인해주세요.',
        );
      }
      rethrow;
    }
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
      if (_looksLikeNetworkError(errorStr)) {
        throw AiConnectionException(
          'AI 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.',
        );
      }
      
      rethrow;
    }
  }

  bool _looksLikeNetworkError(String message) {
    return message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('Connection refused') ||
        message.contains('Network is unreachable');
  }

  /// 응답 파싱 및 검증
  AiDetectionResult _parseResponse(http.Response response) {
    if (response.statusCode == 503) {
      throw AiModelNotLoadedException(
        'AI 모델이 아직 로드되지 않았습니다. 서버 관리자에게 문의하세요.',
      );
    }

    // 500 에러는 서버 측 문제이므로 특별 처리
    if (response.statusCode == 500) {
      String errorMessage = 'AI 서버에서 내부 오류가 발생했습니다.';
      
      // 응답 본문에서 더 자세한 정보 추출 시도
      try {
        final body = response.body;
        if (body.isNotEmpty) {
          // JSON 응답인 경우 파싱 시도
          try {
            final errorData = json.decode(body) as Map<String, dynamic>?;
            if (errorData != null && errorData.containsKey('detail')) {
              final detail = errorData['detail'];
              if (detail is String) {
                errorMessage = 'AI 서버 오류: $detail';
              } else if (detail is Map) {
                errorMessage = 'AI 서버 오류: ${detail.toString()}';
              }
            }
          } catch (_) {
            // JSON 파싱 실패 시 원본 메시지 사용
            if (body.length < 200) {
              errorMessage = 'AI 서버 오류: $body';
            }
          }
        }
      } catch (_) {
        // 에러 처리 실패 시 기본 메시지 사용
      }
      
      throw AiServerException(
        message: errorMessage,
        statusCode: 500,
        responseBody: response.body,
      );
    }

    if (response.statusCode != 200) {
      // 기타 HTTP 에러
      throw AiServerException(
        message: 'AI 서버 오류: ${response.statusCode} - ${response.reasonPhrase ?? 'Unknown error'}',
        statusCode: response.statusCode,
        responseBody: response.body.length > 200 
            ? response.body.substring(0, 200) + "..." 
            : response.body,
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

  AiModelStatus _parseModelStatusResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
        'AI 모델 상태 조회 실패: ${response.statusCode} - '
        '${response.reasonPhrase ?? 'Unknown error'}',
      );
    }

    try {
      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      final status = (data['status'] as String?)?.toLowerCase() ?? 'not_loaded';
      final available = data['available'] as bool? ?? false;
      final device = data['device'] as String?;
      final labelsKorean = _coerceLabelMap(
        data['labels_korean'] as Map<dynamic, dynamic>?,
      );
      final labels = labelsKorean ??
          _coerceLabelMap(data['labels'] as Map<dynamic, dynamic>?);

      return AiModelStatus(
        isLoaded: status == 'loaded',
        available: available,
        device: device,
        labels: labels,
        raw: data,
      );
    } catch (e) {
      throw FormatException('AI 모델 상태 응답 파싱 실패: $e');
    }
  }

  Map<String, String>? _coerceLabelMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return null;
    return raw.map((key, value) {
      return MapEntry(key.toString(), value?.toString() ?? '');
    });
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

class AiModelStatus {
  const AiModelStatus({
    required this.isLoaded,
    required this.available,
    required this.device,
    required this.labels,
    required this.raw,
  });

  final bool isLoaded;
  final bool available;
  final String? device;
  final Map<String, String>? labels;
  final Map<String, dynamic> raw;

  bool get isReady => isLoaded && available;

  List<String> get labelNames {
    if (labels == null) return const [];
    return labels!.values
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
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

/// AI 서버 내부 오류 (500 등)
class AiServerException implements Exception {
  AiServerException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });
  
  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => 'AiServerException: $message';
}
