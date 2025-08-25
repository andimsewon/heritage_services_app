import 'dart:convert';
import 'package:http/http.dart' as http;

class HeritageApi {
  HeritageApi(this.baseUrl);
  final String baseUrl; // 예: http://127.0.0.1:8080

  Future<HeritageList> fetchList({
    String? keyword,
    String? kind,   // ccbaKdcd
    String? region, // ccbaCtcd
    int page = 1,
    int size = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/heritage/list').replace(queryParameters: {
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (region != null && region.isNotEmpty) 'region': region,
      'page': '$page',
      'size': '$size',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => HeritageRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return HeritageList(items: items, totalCount: data['totalCount'] as int? ?? items.length);
  }

  Future<Map<String, dynamic>> fetchDetail({
    required String ccbaKdcd,
    required String ccbaAsno,
    required String ccbaCtcd,
  }) async {
    final uri = Uri.parse('$baseUrl/heritage/detail').replace(queryParameters: {
      'ccbaKdcd': ccbaKdcd,
      'ccbaAsno': ccbaAsno,
      'ccbaCtcd': ccbaCtcd,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
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
  final String name;     // 유산명
  final String sojaeji;  // 소재지
  final String addr;     // 주소(시도)
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
