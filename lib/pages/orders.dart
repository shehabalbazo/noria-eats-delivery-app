import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/service/database.dart';
import 'package:food_delivery_app/service/shared_pref.dart';
import 'package:food_delivery_app/generated/l10n.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String? id;
  Stream? foodStream;
  Stream? ordersStream;

  getData() async {
    id = await SharedPreferenceHelper().getUserId();
    if (id != null) {
      ordersStream = DatabaseMethods().getUserOrders(id!);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  reorderItems(List items) async {
    String? userId = await SharedPreferenceHelper().getUserId();

    if (userId != null) {
      for (var item in items) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('Cart')
            .add({
              "Name": item["Name"],
              "Quantity": item["Quantity"],
              "Total": item["Total"],
              "Image": item["Image"],
            });
      }

      foodStream = await DatabaseMethods().getFoodCart(userId);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          content: Text(
            S.of(context).orderAddedToCart,
            style: const TextStyle(
              fontSize: 16.0,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Widget ordersList() {
    return StreamBuilder(
      stream: ordersStream,
      builder: (context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 15),
                Text(
                  S.of(context).noOrdersYet,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 30), // مسافة من الأسفل
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var order = docs[index];
            Map<String, dynamic> data = order.data() as Map<String, dynamic>;
            List items = data["items"] ?? [];

            // 1. استخراج التاريخ
            String formattedDate = S.of(context).unknownDate;
            if (data.containsKey("timestamp") && data["timestamp"] != null) {
              DateTime d = (data["timestamp"] as Timestamp).toDate();
              formattedDate = DateFormat(
                'dd/MM/yyyy  hh:mm a',
                Localizations.localeOf(context).languageCode,
              ).format(d);
            }

            // 2. المنطق البرمجي للكوبونات والخصم
            bool isDiscountApplied = data.containsKey('discount_applied')
                ? data['discount_applied'] == true
                : false;
            int finalTotal = data['total'] ?? 0;
            int originalTotal = data.containsKey('original_total')
                ? data['original_total']
                : finalTotal;

            // 3. التصميم الجديد الاحترافي
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ترويسة الفاتورة (التاريخ)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            size: 20,
                            color: Color(0xFF2F6BFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(height: 1, thickness: 1),
                    ),

                    // قائمة الوجبات
                    Column(
                      children: items.map<Widget>((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item["Image"],
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["Name"],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      S
                                          .of(context)
                                          .quantityLabel(
                                            item["Quantity"].toString(),
                                          ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "\$${item["Total"]}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, thickness: 1),
                    ),

                    // قسم السعر الإجمالي (Total) مع تأثيرات الكوبون
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).totalPrice, // استخدمنا نفس ترجمة السلة
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Row(
                          children: [
                            // إذا كان هناك خصم، نشطب السعر الأصلي
                            if (isDiscountApplied) ...[
                              Text(
                                "\$$originalTotal",
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // السعر النهائي
                            Text(
                              "\$$finalTotal",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: isDiscountApplied
                                    ? Colors.orange
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // علامة (Tag) الكوبون
                    if (isDiscountApplied) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                S.of(context).applied,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // زر إعادة الطلب (تصميم أعرض وأجمل)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await reorderItems(data["items"]);
                        },
                        child: Text(
                          S.of(context).reorderButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB), // لون خلفية مريح للعين
      appBar: AppBar(
        title: Text(
          S.of(context).myOrdersTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF9F9FB),
        elevation: 0,
        centerTitle: true,
      ),
      body: ordersList(),
    );
  }
}
