import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class HeritageApi {
  HeritageApi(this.baseUrl);
  final String baseUrl; // 예: http://127.0.0.1:8080

  Future<HeritageList> fetchList({
    String? keyword,
    String? kind, // ccbaKdcd
    String? region, // ccbaCtcd
    int page = 1,
    int size = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/heritage/list').replace(
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (region != null && region.isNotEmpty) 'region': region,
        'page': '$page',
        'size': '$size',
      },
    );

    // 🔍 디버그 로그: API 요청 정보 출력
    print('🔍 [HeritageApi] baseUrl: $baseUrl');
    print('🔍 [HeritageApi] 요청 URI: $uri');
    print('🔍 [HeritageApi] kIsWeb: $kIsWeb');

    // 웹 환경에서 CORS 문제 해결을 위한 설정
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 웹에서 CORS 문제를 우회하기 위한 추가 헤더
    if (kIsWeb) {
      headers['User-Agent'] = 'Flutter Web App';
    }

    print('🔍 [HeritageApi] 요청 헤더: $headers');

    final res = await http.get(uri, headers: headers);

    // 🔍 응답 상태 및 내용 로그
    print('🔍 [HeritageApi] 응답 상태 코드: ${res.statusCode}');
    print('🔍 [HeritageApi] 응답 헤더: ${res.headers}');
    print('🔍 [HeritageApi] 응답 본문 (처음 200자): ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');

    _validateResponse(res,
        context: 'HeritageApi.fetchList', expectedContent: 'JSON 목록');
    final data = _safeDecodeJson(res.body,
        context: 'HeritageApi.fetchList 응답') as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => HeritageRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return HeritageList(
      items: items,
      totalCount: data['totalCount'] as int? ?? items.length,
    );
  }

  Future<Map<String, dynamic>> fetchDetail({
    required String ccbaKdcd,
    required String ccbaAsno,
    required String ccbaCtcd,
  }) async {
    final uri = Uri.parse('$baseUrl/heritage/detail').replace(
      queryParameters: {
        'ccbaKdcd': ccbaKdcd,
        'ccbaAsno': ccbaAsno,
        'ccbaCtcd': ccbaCtcd,
      },
    );

    // 🔍 디버그 로그
    print('🔍 [HeritageApi.detail] 요청 URI: $uri');

    // 웹 환경에서 CORS 문제 해결을 위한 설정
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 웹에서 CORS 문제를 우회하기 위한 추가 헤더
    if (kIsWeb) {
      headers['User-Agent'] = 'Flutter Web App';
    }

    final res = await http.get(uri, headers: headers);

    print('🔍 [HeritageApi.detail] 응답 상태: ${res.statusCode}');
    print('🔍 [HeritageApi.detail] 응답 본문 (처음 200자): ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');

    _validateResponse(res,
        context: 'HeritageApi.fetchDetail', expectedContent: 'JSON 상세');
    return _safeDecodeJson(res.body,
        context: 'HeritageApi.fetchDetail 응답') as Map<String, dynamic>;
  }
}

void _validateResponse(
  http.Response res, {
  required String context,
  required String expectedContent,
}) {
  if (res.statusCode != 200) {
    final preview =
        res.body.length > 120 ? '${res.body.substring(0, 120)}…' : res.body;
    throw Exception(
      '[$context] HTTP ${res.statusCode}. $expectedContent을 기대했지만 실패했습니다. 본문: $preview',
    );
  }

  final contentType = res.headers['content-type'] ?? '';
  final bodyStartsWithHtml = res.body.trimLeft().startsWith('<');
  if (contentType.contains('text/html') || bodyStartsWithHtml) {
    final preview =
        res.body.length > 120 ? '${res.body.substring(0, 120)}…' : res.body;
    throw FormatException(
      '[$context] $expectedContent 대신 HTML 응답을 받았습니다. 본문: $preview',
      res.body,
    );
  }
}

dynamic _safeDecodeJson(
  String body, {
  required String context,
}) {
  try {
    return json.decode(body);
  } on FormatException catch (e) {
    final preview = body.length > 120 ? '${body.substring(0, 120)}…' : body;
    throw FormatException(
      '[$context] JSON 파싱에 실패했습니다. HTML 또는 잘못된 형식일 수 있습니다. 본문: $preview',
      e.source,
      e.offset,
    );
  }
}

class HeritageList {
  final List<HeritageRow> items;
  final int totalCount;
  HeritageList({required this.items, required this.totalCount});
}

class HeritageRow {
  final String id;
  final String kindCode;
  final String kindName; // 종목
  final String name; // 유산명
  final String sojaeji; // 소재지
  final String addr; // 주소(시도)
  final String ccbaKdcd, ccbaAsno, ccbaCtcd;

  HeritageRow({
    required this.id,
    required this.kindCode,
    required this.kindName,
    required this.name,
    required this.sojaeji,
    required this.addr,
    required this.ccbaKdcd,
    required this.ccbaAsno,
    required this.ccbaCtcd,
  });

  factory HeritageRow.fromJson(Map<String, dynamic> j) => HeritageRow(
    id: j['id'] as String,
    kindCode: j['kindCode'] as String? ?? '',
    kindName: j['kindName'] as String? ?? '',
    name: j['name'] as String? ?? '',
    sojaeji: j['sojaeji'] as String? ?? '',
    addr: j['addr'] as String? ?? '',
    ccbaKdcd: j['ccbaKdcd'] as String? ?? '',
    ccbaAsno: j['ccbaAsno'] as String? ?? '',
    ccbaCtcd: j['ccbaCtcd'] as String? ?? '',
  );
}
