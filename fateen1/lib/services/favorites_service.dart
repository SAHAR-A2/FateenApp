import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addToFavorites(String userId, String productBarcode) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayUnion([productBarcode]),
      });
    } catch (e) {
      throw 'حدث خطأ أثناء إضافة المنتج للمفضلة';
    }
  }

  Future<void> removeFromFavorites(String userId, String productBarcode) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayRemove([productBarcode]),
      });
    } catch (e) {
      throw 'حدث خطأ أثناء إزالة المنتج من المفضلة';
    }
  }

  Future<List<String>> getFavorites(String userId) async {
    DocumentSnapshot doc;

    try {
      doc = await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      throw 'حدث خطأ أثناء الاتصال بقاعدة البيانات';
    }

    if (!doc.exists) {
      throw 'لم يُعثر على بيانات المستخدم';
    }

    final data = doc.data() as Map<String, dynamic>?;
    final favorites = data?['favorites'] ?? [];
    return List<String>.from(favorites);
  }
}
