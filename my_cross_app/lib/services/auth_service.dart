// 간단 모킹 인증 서비스: 서버 통신 없이 로컬에서만 검사.
// 추후 실제 API 연동 시 이 부분만 바꿔끼우면 됨.
class AuthService {
  // 데모용 계정
  static const _demoId = 'admin';
  static const _demoPw = '1234';

  /// 비동기 흉내만 내는 로그인 함수
  static Future<bool> login(String id, String pw) async {
    await Future.delayed(const Duration(milliseconds: 400)); // 네트워크 흉내
    return id == _demoId && pw == _demoPw;
  }
}
