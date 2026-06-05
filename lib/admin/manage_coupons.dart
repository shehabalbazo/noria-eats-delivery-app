import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/generated/l10n.dart';

class ManageCoupons extends StatefulWidget {
  const ManageCoupons({super.key});

  @override
  State<ManageCoupons> createState() => _ManageCouponsState();
}

class _ManageCouponsState extends State<ManageCoupons> {
  TextEditingController codeController = TextEditingController();
  TextEditingController discountController = TextEditingController();
  // 1. إضافة المتحكم الخاص بالوصف
  TextEditingController descriptionController = TextEditingController(); 
  bool isAdding = false;

  addCoupon() async {
    // تحديث شرط التحقق ليشمل الوصف إذا أردت جعله إجبارياً
    if (codeController.text.isEmpty || discountController.text.isEmpty || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).fillAllFields),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isAdding = true);

    String code = codeController.text.trim().toUpperCase();
    int discount = int.parse(discountController.text.trim());
    String description = descriptionController.text.trim();

    await FirebaseFirestore.instance.collection('Coupons').doc(code).set({
      "code": code,
      "discount": discount,
      "description": description, // 2. إرسال الوصف إلى Firestore
      "isActive": true,
      "addedAt": DateTime.now(),
    });

    setState(() {
      isAdding = false;
      codeController.clear();
      discountController.clear();
      descriptionController.clear(); // مسح الحقل بعد الإضافة
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).couponAdded),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  deleteCoupon(String id) async {
    await FirebaseFirestore.instance.collection('Coupons').doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).couponDeleted),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: Text(
          S.of(context).couponManagement,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).addNewCoupon,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  // حقل الكود
                  _buildTextField(codeController, S.of(context).couponCodeHint, false),
                  const SizedBox(height: 10),

                  // حقل نسبة الخصم
                  _buildTextField(discountController, S.of(context).discountPercentageHint, true),
                  const SizedBox(height: 10),

                  // 3. حقل الوصف الجديد
                  _buildTextField(descriptionController, S.of(context).couponDescriptionHint, false, maxLines: 2),
                  
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isAdding ? null : addCoupon,
                      child: isAdding
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(S.of(context).saveCoupon, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Text(S.of(context).activeCoupons, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('Coupons')
                    .orderBy('addedAt', descending: true)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var coupon = snapshot.data!.docs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.local_offer, color: Colors.green),
                          title: Text(coupon['code'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          // 4. عرض الوصف في القائمة تحت الكود
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${S.of(context).discountLabel2}: %${coupon['discount']}"),
                              Text(
                                coupon['description'] ?? "", 
                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => deleteCoupon(coupon.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء حقول الإدخال لتقليل تكرار الكود
  Widget _buildTextField(TextEditingController controller, String hint, bool isNumber, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
        ),
      ),
    );
  }
}