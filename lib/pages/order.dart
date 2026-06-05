import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/service/database.dart';
import 'package:food_delivery_app/service/shared_pref.dart';
import 'package:food_delivery_app/widget/widget_support.dart';
import 'package:food_delivery_app/service/notification_service.dart';
import 'package:food_delivery_app/generated/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class Order extends StatefulWidget {
  const Order({super.key});

  @override
  State<Order> createState() => _OrderState();
}

class _OrderState extends State<Order> {
  String? id, wallet;
  int total = 0; // هذا سيبقى كـ (Ara Toplam / Subtotal)
  Stream? foodStream;

  // 🟢 إضافة جديدة: متغيرات نظام الكوبونات
  double discountPercentage = 0.0;
  bool isCouponApplied = false;
  TextEditingController couponController = TextEditingController();

  // 🟢 إضافة جديدة: متغير ذكي يحسب السعر النهائي بعد الخصم
  int get finalTotal => (total - (total * discountPercentage)).toInt();

  getthesharedpref() async {
    id = await SharedPreferenceHelper().getUserId();
    wallet = await SharedPreferenceHelper().getUserWallet();
    if (!mounted) return;
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    if (id != null) {
      foodStream = await DatabaseMethods().getFoodCart(id!);
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    ontheload();
    super.initState();
  }

  // 🟢 إضافة جديدة: تفريغ الذاكرة من الكنترولر عند الخروج
  @override
  void dispose() {
    couponController.dispose();
    super.dispose();
  }

  // 🟢 تحديث: جلب الكوبون من قاعدة البيانات بدلاً من الأكواد الثابتة
  Future<void> applyCoupon() async {
    String code = couponController.text.trim();
    if (code.isEmpty) return;

    try {
      // البحث عن الكوبون في Firestore
      var response = await FirebaseFirestore.instance
          .collection('Coupons')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true) // التأكد أنه فعال
          .get();

      if (response.docs.isNotEmpty) {
        var couponData = response.docs.first;

        setState(() {
          // تحويل قيمة الخصم من رقم صحيح (مثلاً 20) إلى نسبة مئوية (0.20)
          discountPercentage =
              int.parse(couponData['discount'].toString()) / 100.0;
          isCouponApplied = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${S.of(context).applied}: ${couponData['discount']}%",
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // إذا لم يجد الكود أو كان غير فعال
        setState(() {
          discountPercentage = 0.0;
          isCouponApplied = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).invalidCoupon),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error applying coupon: $e");
    }
  }

  Widget foodCart() {
    return StreamBuilder(
      stream: foodStream,
      builder: (context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data.docs;

        if (docs.isEmpty) {
          Future.microtask(() {
            if (mounted && total != 0) setState(() => total = 0);
          });
          return Center(
            child: Text(
              S.of(context).cartEmpty,
              style: AppWidget.semiBoldTextFieldStyle(),
            ),
          );
        }

        int newTotal = 0;
        for (var d in docs) {
          newTotal += int.parse(d["Total"].toString());
        }

        Future.microtask(() {
          if (mounted && total != newTotal) setState(() => total = newTotal);
        });

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            DocumentSnapshot ds = docs[index];

            return Dismissible(
              key: ValueKey(ds.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.shade400,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                margin: const EdgeInsets.only(bottom: 10.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                DatabaseMethods().deleteFoodFromCart(id!, ds.id);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context).itemRemoved),
                    duration: const Duration(milliseconds: 800),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 5.0,
                ),
                child: Material(
                  borderRadius: BorderRadius.circular(10),
                  elevation: 3.0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                int currentQty = int.parse(ds["Quantity"]);
                                int pricePerItem =
                                    int.parse(ds["Total"]) ~/ currentQty;
                                await DatabaseMethods().updateCartItemQuantity(
                                  id!,
                                  ds.id,
                                  currentQty + 1,
                                  pricePerItem,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 5.0,
                              ),
                              child: Text(
                                ds["Quantity"],
                                style: AppWidget.semiBoldTextFieldStyle(),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                int currentQty = int.parse(ds["Quantity"]);
                                int pricePerItem =
                                    int.parse(ds["Total"]) ~/ currentQty;
                                if (currentQty > 1) {
                                  await DatabaseMethods()
                                      .updateCartItemQuantity(
                                        id!,
                                        ds.id,
                                        currentQty - 1,
                                        pricePerItem,
                                      );
                                } else {
                                  await DatabaseMethods().deleteFoodFromCart(
                                    id!,
                                    ds.id,
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20.0),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: ds["Image"],
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 80,
                                width: 80,
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ds["Name"],
                                style: AppWidget.semiBoldTextFieldStyle(),
                              ),
                              Text(
                                "\$${ds["Total"]}",
                                style: AppWidget.semiBoldTextFieldStyle(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
      body: Container(
        padding: const EdgeInsets.only(top: 60.0),
        child: Column(
          children: [
            Text(
              S.of(context).foodCart,
              style: AppWidget.headlineTextFieldStyle(),
            ),
            const SizedBox(height: 20.0),
            Expanded(child: foodCart()),
            const Divider(),

            // واجهة الكوبون وتفصيل السعر
            const Divider(color: Colors.transparent), // مسافة شفافة للترتيب
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. حقل الكوبون (تصميم عصري)
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6), // لون رمادي فاتح مريح
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.local_offer_outlined,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: couponController,
                            decoration: InputDecoration(
                              hintText: S.of(context).couponHint,
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: applyCoupon,
                          child: Container(
                            height: 55,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: isCouponApplied
                                  ? Colors.green
                                  : const Color(0xFF2F6BFF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isCouponApplied
                                  ? S.of(context).applied
                                  : S.of(context).apply,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. تفاصيل السعر
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context).subtotal,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "\$$total",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (isCouponApplied) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).discount,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "-\$${(total * discountPercentage).toInt()}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),

                  // 3. السعر النهائي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context).totalPrice,
                        style: AppWidget.boldTextFieldStyle(),
                      ),
                      Text(
                        "\$$finalTotal",
                        style: isCouponApplied
                            ? const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              )
                            : const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // زر تأكيد الطلب
            GestureDetector(
              onTap: () async {
                if (total == 0 || id == null) return;
                int currentWallet = int.parse(wallet ?? "0");

                // 🟢 التعديل الأهم: مقارنة الرصيد مع السعر النهائي (finalTotal) بدلاً من الأصلي (total)
                if (currentWallet < finalTotal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).insufficientBalance)),
                  );
                  return;
                }

                // خصم السعر النهائي فقط من المحفظة
                int newAmount = currentWallet - finalTotal;
                await DatabaseMethods().UpdateUserwallet(
                  id!,
                  newAmount.toString(),
                );

                await SharedPreferenceHelper().saveUserWallet(
                  newAmount.toString(),
                );

                QuerySnapshot cartSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(id)
                    .collection('Cart')
                    .get();

                List ordersList = [];

                for (var doc in cartSnapshot.docs) {
                  ordersList.add({
                    "Name": doc["Name"],
                    "Quantity": doc["Quantity"],
                    "Total": doc["Total"],
                    "Image": doc["Image"],
                  });
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(id)
                    .collection('orders')
                    .add({
                      "items": ordersList,
                      "total": finalTotal, // حفظ السعر النهائي في الفاتورة
                      "original_total":
                          total, // حفظ السعر الأصلي للمقارنة في لوحة الإدارة
                      "discount_applied": isCouponApplied,
                      "timestamp": DateTime.now(),
                    });

                await DatabaseMethods().clearCart(id!);

                if (ordersList.isNotEmpty) {
                  String firstItemName = ordersList[0]["Name"];

                  await NotificationService.scheduleSmartReminder(
                    foodName: firstItemName,
                    secondsFromNow: 60,
                    aiMessage: S.of(context).reminderMessage(firstItemName),
                  );

                  await NotificationService.showInstantNotification(
                    title: S.of(context).orderConfirmedTitle,
                    body: S.of(context).orderConfirmedBody,
                  );
                }

                if (!mounted) return;

                // 🟢 إعادة تعيين الكوبونات والأسعار بعد الدفع
                setState(() {
                  wallet = newAmount.toString();
                  total = 0;
                  isCouponApplied = false;
                  discountPercentage = 0.0;
                  couponController.clear();
                });

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(S.of(context).successTitle),
                    content: Text(S.of(context).orderPlaced),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(S.of(context).okButton),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: total == 0 ? Colors.grey : Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    S.of(context).checkoutButton,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
