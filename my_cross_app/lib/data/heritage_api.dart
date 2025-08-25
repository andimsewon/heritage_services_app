// lib/data/heritage_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class HeritageApi {
  HeritageApi(this.baseUrl);
  final String baseUrl; // 예: http://10.0.2.2:8080

  Future<HeritageList> fetchList({String? query, int page = 1, int size = 20}) async {
    final uri = Uri.parse('$baseUrl/heritage/list').replace(queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'keyword': query.trim(),
      'page': '$page',
      'size': '$size',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => HeritageItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return HeritageList(items: items, totalCount: data['totalCount'] as int? ?? items.length);
  }
}

class HeritageList {
  final List<HeritageItem> items;
  final int totalCount;
  HeritageList({required this.items, required this.totalCount});
}

class HeritageItem {
  final String id;
  final String name;
  final String region;
  final String code;
  final String ccbaKdcd;
  final String ccbaAsno;
  final String ccbaCtcd;

  HeritageItem({
    required this.id,
    required this.name,
    required this.region,
    required this.code,
    required this.ccbaKdcd,
    required this.ccbaAsno,
    required this.ccbaCtcd,
  });

  factory HeritageItem.fromJson(Map<String, dynamic> j) => HeritageItem(
    id: j['id'] as String,
    name: j['name'] as String,
    region: j['region'] as String,
    code: j['code'] as String,
    ccbaKdcd: j['ccbaKdcd'] as String? ?? '',
    ccbaAsno: j['ccbaAsno'] as String? ?? '',
    ccbaCtcd: j['ccbaCtcd'] as String? ?? '',
  );
}
