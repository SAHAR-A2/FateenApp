import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fateen/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserProfile(String userId, AppUser user) async {
    try {
      await _firestore.collection('users').doc(userId).set(user.toJson());
    } catch (e) {
      throw 'حدث خطأ أثناء حفظ بياناتك، تأكد من الاتصال بالإنترنت';
    }
  }

  Future<AppUser?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return AppUser.fromJson(doc.data() as Map<String, dynamic>);
      } else {
        throw 'لم يُعثر على بياناتك';
      }
    } catch (e) {
      throw 'حدث خطأ أثناء جلب بيانات المستخدم';
    }
  }

  Future<void> updateUserAllergies(
    String userId,
    List<UserAllergy> allergies,
  ) async {
    try {
      List<Map<String, dynamic>> allergiesJson = allergies
          .map((allergy) => allergy.toJson())
          .toList();

      await _firestore.collection('users').doc(userId).update({
        'allergies': allergiesJson,
      });
    } catch (e) {
      throw 'حدث خطأ أثناء تحديث قائمة الحساسية';
    }
  }

  Future<void> updateUserDiseases(
    String userId,
    List<UserDisease> diseases,
  ) async {
    try {
      List<Map<String, dynamic>> diseasesJson = diseases
          .map((d) => d.toJson())
          .toList();

      await _firestore.collection('users').doc(userId).update({
        'diseases': diseasesJson,
      });
    } catch (e) {
      throw 'حدث خطأ أثناء تحديث بيانات الأمراض';
    }
  }
}
