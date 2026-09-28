import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<String?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      // ========================================================
      // WEB - Chrome
      // ========================================================
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        userCredential = await _auth.signInWithPopup(googleProvider);
      }

      // ========================================================
      // ANDROID / iOS
      // ========================================================
      else {
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // ========================================================
      // GET USER
      // ========================================================

      final user = userCredential.user;

      if (user == null) {
        return 'ไม่สามารถเข้าสู่ระบบด้วย Google ได้';
      }

      // ========================================================
      // SAVE NEW USER TO FIRESTORE
      // ========================================================

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final displayName = user.displayName ?? '';

        final nameParts = displayName.trim().split(' ');

        final firstName = nameParts.isNotEmpty ? nameParts.first : '';

        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        await _firestore.collection('users').doc(user.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'dateOfBirth': '',
          'emailVerified': user.emailVerified,
          'provider': 'google',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ';
    } catch (e) {
      return 'เกิดข้อผิดพลาด: $e';
    }
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  Future<String?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String dateOfBirth,
    required String phone,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        return 'ไม่สามารถสร้างบัญชีได้';
      }

      await user.updateDisplayName(
        '$firstName $lastName',
      );

      await _firestore.collection('users').doc(user.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'dateOfBirth': dateOfBirth,
        'phone': phone.trim(),
        'emailVerified': false,
        'provider': 'email',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await user.sendEmailVerification();

      await _auth.signOut();

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว';

        case 'invalid-email':
          return 'รูปแบบ Gmail ไม่ถูกต้อง';

        case 'weak-password':
          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';

        case 'network-request-failed':
          return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้';

        default:
          return e.message ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      }
    } catch (e) {
      return 'เกิดข้อผิดพลาด: $e';
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        return 'ไม่สามารถเข้าสู่ระบบได้';
      }

      await user.reload();

      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        return 'ไม่พบผู้ใช้';
      }

      if (!currentUser.emailVerified) {
        await _auth.signOut();

        return 'กรุณายืนยัน Gmail ก่อนเข้าสู่ระบบ';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'ไม่พบบัญชีนี้ในระบบ';

        case 'wrong-password':
        case 'invalid-credential':
          return 'Gmail หรือรหัสผ่านไม่ถูกต้อง';

        case 'invalid-email':
          return 'รูปแบบ Gmail ไม่ถูกต้อง';

        case 'too-many-requests':
          return 'ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอสักครู่';

        case 'network-request-failed':
          return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้';

        default:
          return e.message ?? 'เข้าสู่ระบบไม่สำเร็จ';
      }
    } catch (e) {
      return 'เกิดข้อผิดพลาด: $e';
    }
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  Future<String?> resetPassword({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return 'รูปแบบ Gmail ไม่ถูกต้อง';

        case 'user-not-found':
          return 'ไม่พบบัญชีที่ใช้ Gmail นี้';

        case 'network-request-failed':
          return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้';

        default:
          return e.message ?? 'ไม่สามารถส่งอีเมลรีเซ็ตรหัสผ่านได้';
      }
    } catch (e) {
      return 'เกิดข้อผิดพลาด: $e';
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _auth.signOut();
  }
}
