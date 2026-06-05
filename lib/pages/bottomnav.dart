import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/pages/home.dart';
import 'package:food_delivery_app/pages/order.dart' as myorder;
import 'package:food_delivery_app/pages/profile.dart';
import 'package:food_delivery_app/pages/wallet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int currentTabIndex = 0;

  late List<Widget> pages;
  late Widget currentPage;
  late Home homepage;
  late Profile profile;
  late myorder.Order order;
  late Wallet wallet;

  @override
  void initState() {
    super.initState();
    homepage = Home();
    profile = Profile();
    order = myorder.Order();
    wallet = Wallet();
    pages = [homepage, order, wallet, profile];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadUserOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
        height: 65,
        backgroundColor: Colors.white,
        color: Colors.black,
        animationDuration: Duration(milliseconds: 500),
        onTap: (int index) {
          setState(() {
            currentTabIndex = index;
          });
        },
        items: [
          Icon(Icons.home_outlined, color: Colors.white),
          Icon(Icons.shopping_bag_outlined, color: Colors.white),
          Icon(Icons.wallet_outlined, color: Colors.white),
          Icon(Icons.person_outlined, color: Colors.white),
        ],
      ),
      body: pages[currentTabIndex],
    );
  }

  loadUserOrders() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .get();

    if (snapshot.docs.isEmpty) return;
    List orders = snapshot.docs.map((e) => e.data()).toList();
    analyzeAndRecommend(orders);
  }

  Future<bool> shouldShowPopup() async {
    final prefs = await SharedPreferences.getInstance();

    String today =
        "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    String? lastShown = prefs.getString("last_popup_date");

    if (lastShown == today) {
      return false;
    }

    await prefs.setString("last_popup_date", today);
    return true;
  }

  List getItemsForFood(String food, List orders) {
    for (var order in orders.reversed) {
      // من الأحدث للأقدم
      List items = order["items"];

      for (var item in items) {
        if (item["Name"] == food) {
          return items; // رجع كل عناصر هذا الطلب
        }
      }
    }
    return [];
  }

  analyzeAndRecommend(List orders) async {
    Map<String, int> foodCount = {};
    List<int> hours = [];

    for (var order in orders) {
      List items = order["items"];

      if (order["timestamp"] != null) {
        DateTime time = (order["timestamp"] as Timestamp).toDate();
        hours.add(time.hour);
      }

      for (var item in items) {
        String name = item["Name"];
        foodCount[name] = (foodCount[name] ?? 0) + 1;
      }
    }

    if (foodCount.isEmpty) return;
    // أكثر أكلة مكررة
    String mostOrderedFood = foodCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // متوسط الوقت
    int avgHour = (hours.reduce((a, b) => a + b) / hours.length).round();

    int currentHour = DateTime.now().hour;

    // شرط الظهور (فرق ساعة)
    if ((currentHour - avgHour).abs() <= 1) {
      bool show = await shouldShowPopup();

      if (show) {
        List selectedItems = getItemsForFood(mostOrderedFood, orders);

        showSmartDialog(mostOrderedFood, selectedItems);
      }
    }
  }

  showSmartDialog(String food, List items) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey.shade900],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu, color: Colors.white, size: 50),
              SizedBox(height: 15),

              Text(
                "AI Recommendation 🤖",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Would you like to order $food?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),

              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("No", style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () {
                      reorderItems(items);
                      Navigator.pop(context);
                    },
                    child: Text("Yes"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> reorderItems(List items) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return;

    Map<String, dynamic> mergedItems = {};

    for (var item in items) {
      String name = item["Name"];

      if (mergedItems.containsKey(name)) {
        mergedItems[name]["Quantity"] += item["Quantity"];
        mergedItems[name]["Total"] += item["Total"];
      } else {
        mergedItems[name] = {
          "Name": item["Name"],
          "Quantity": item["Quantity"],
          "Total": item["Total"],
          "Image": item["Image"],
        };
      }
    }

    // 🔥 أضف بعد الدمج
    for (var item in mergedItems.values) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Cart')
          .add(item);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.greenAccent,
        content: Text(
          "Your order has been added to the cart",
          style: TextStyle(
            fontSize: 18.0,
            color: Colors.black,
            fontFamily: 'Google_Sans_Flex',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
