import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _usernameToFakeEmail(String username) {
    final cleanUsername = username.trim().toLowerCase();
    return '$cleanUsername@fateen-app.com';
  }

  Future<User?> registerWithUsername(String username, String password) async {
    final email = _usernameToFakeEmail(username);
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ غير متوقع، حاول مرة أخرى';
      if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جدًا';
      } else if (e.code == 'email-already-in-use') {
        message = 'اسم المستخدم هذا مستخدم من قبل، اختر اسم آخر';
      }
      throw message;
    }
  }

  Future<User?> signInWithUsername(String username, String password) async {
    final email = _usernameToFakeEmail(username);
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ غير متوقع، حاول مرة أخرى';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      }
      throw message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}
