import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/admin/add_food.dart';
import 'package:food_delivery_app/generated/l10n.dart';
import 'package:food_delivery_app/admin/manage_coupons.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  int totalRevenue = 0;
  int totalOrders = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboardStats();
  }

  // دالة لجلب الإحصائيات من كل المستخدمين دفعة واحدة
  fetchDashboardStats() async {
    try {
      // استخدام collectionGroup يجلب كل الطلبات من كل المستخدمين في نفس الوقت
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .get();

      int tempRevenue = 0;
      for (var doc in snapshot.docs) {
        if (doc.data().toString().contains('total')) {
          tempRevenue += (doc['total'] as num).toInt();
        }
      }

      if (mounted) {
        setState(() {
          totalRevenue = tempRevenue;
          totalOrders = snapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // تصميم كرت الإحصائيات
  Widget buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 15),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تصميم زر الإدارة
  Widget buildAdminAction(String title, String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(15),
                color: const Color(0xFFF3F4F6),
                child: Image.asset(
                  imagePath,
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.fastfood, size: 40),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: Text(
          S.of(context).homeAdminTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // لمنع زر الرجوع في الرئيسية
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. قسم الإحصائيات
                  Text(
                    S.of(context).dashboard,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      buildStatCard(
                        S.of(context).totalRevenue, // إجمالي الدخل
                        "\$$totalRevenue",
                        Icons.attach_money,
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 15),
                      buildStatCard(
                        S.of(context).orders, // الطلبات
                        "$totalOrders",
                        Icons.shopping_bag_outlined,
                        const Color(0xFF2F6BFF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // 2. قسم الإدارة (الأزرار)
                  Text(
                    S.of(context).adminPanel, // لوحة الإدارة
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // زر إضافة وجبة
                  buildAdminAction(
                    S.of(context).addFoodItems,
                    "images/food.jpg", // تأكد أن المسار صحيح عندك
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddFood()),
                    ),
                  ),

                  // زر مدير الكوبونات
                  buildAdminAction(S.of(context).couponManagement, "images/discount.png", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageCoupons(),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
