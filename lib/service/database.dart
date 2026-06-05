import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseMethods {
  // إضافة بيانات المستخدم
  Future addUserDetail(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .set(userInfoMap);
  }

  // تحديث محفظة المستخدم
  Future UpdateUserwallet(String id, String amount) async {
    return await FirebaseFirestore.instance.collection("users").doc(id).update({
      "Wallet": amount,
    });
  }

  // إضافة وجبة طعام (للمسؤول)
  Future addFoodItem(Map<String, dynamic> userInfoMap, String name) async {
    return await FirebaseFirestore.instance.collection(name).add(userInfoMap);
  }

  // جلب وجبات الطعام حسب التصنيف
  Future<Stream<QuerySnapshot>> getFoodItem(String name) async {
    return FirebaseFirestore.instance.collection(name).snapshots();
  }

  // إضافة وجبة إلى سلة المستخدم
  Future addFoodtoCart(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .collection('Cart')
        .add(userInfoMap);
  }

  // جلب بيانات المستخدم عبر البريد الإلكتروني
  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    var snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("Email", isEqualTo: email)
        .get();

    var data = snapshot.docs.first.data();
    data["Id"] = snapshot.docs.first.id;
    return data;
  }

  // جلب عناصر السلة (Stream)
  Future<Stream<QuerySnapshot>> getFoodCart(String id) async {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Cart")
        .snapshots();
  }

  // --- الإضافات الجديدة المطلوبة لكود صفحة الـ Order ---

  // 1. دالة حذف عنصر واحد من السلة (تستخدم مع Dismissible)
  Future deleteFoodFromCart(String userId, String cartItemId) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("Cart")
        .doc(cartItemId)
        .delete();
  }

  // 2. دالة تفريغ السلة بالكامل (تستخدم بعد إتمام عملية الدفع Checkout)
  Future clearCart(String userId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("Cart")
        .get();

    for (DocumentSnapshot doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // دالة لتحديث الكمية والسعر داخل السلة
  Future updateCartItemQuantity(
    String userId,
    String cartItemId,
    int newQuantity,
    int pricePerItem,
  ) async {
    int newTotal = newQuantity * pricePerItem;
    return await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Cart')
        .doc(cartItemId)
        .update({
          "Quantity": newQuantity.toString(),
          "Total": newTotal.toString(),
        });
  }

  //دالة جلب الطلبات من الفاير ستور
  Stream<QuerySnapshot> getUserOrders(String userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('orders')
      .orderBy('timestamp', descending: true)
      .snapshots();
}

}
