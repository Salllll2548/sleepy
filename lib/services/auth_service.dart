/// Service ยืนยันตัวตนผู้ใช้ — ตอนนี้เป็น mock implementation
/// (ไม่มี backend จริง) เผื่อไว้ต่อ Firebase Auth หรือ API ของตัวเองภายหลัง
/// ตัด/แทนเฉพาะเมธอดในไฟล์นี้ได้โดยไม่กระทบ UI เพราะหน้าจอเรียกผ่าน
/// interface เดียวกันหมด
class AuthService {
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // TODO: เรียก API จริงแทนบรรทัดนี้
    return username.isNotEmpty && password.isNotEmpty;
  }

  Future<bool> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // TODO: เรียก API จริงแทนบรรทัดนี้
    return true;
  }

  Future<bool> loginWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 600));
    // TODO: ต่อ google_sign_in package จริง
    return true;
  }
}
