import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/pages/login.dart';
import 'package:food_delivery_app/service/database.dart';
import 'package:food_delivery_app/widget/widget_support.dart';
import 'package:food_delivery_app/generated/l10n.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = "", password = "", name = "";

  TextEditingController namecontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  TextEditingController mailcontroller = TextEditingController();

  final _formkey = GlobalKey<FormState>();

  Future<void> registration() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      // إرسال رابط تأكيد الإيميل
      await userCredential.user!.sendEmailVerification();

      String id = userCredential.user!.uid;

      Map<String, dynamic> addUserInfo = {
        "Name": name.trim(),
        "Email": email.trim(),
        "Wallet": "0",
        "Id": id,
      };

      // حفظ البيانات في Firestore
      await DatabaseMethods().addUserDetail(addUserInfo, id);

      // تسجيل خروج مؤقت حتى ما يدخل قبل تأكيد الإيميل
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.greenAccent,
          content: Text(
            S.of(context).registrationSuccess,
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.black,
              fontFamily: 'Google_Sans_Flex',
              fontWeight: FontWeight.bold,
            ),
          ),
          behavior: SnackBarBehavior.floating
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LogIn()),
      );
    } on FirebaseAuthException catch (e) {
      String message = S.of(context).somethingWentWrong;

      if (e.code == 'weak-password') {
        message = S.of(context).weakPasswordMsg;
      } else if (e.code == 'email-already-in-use') {
        message = S.of(context).accountExistsMsg;
      } else if (e.code == 'invalid-email') {
        message = S.of(context).invalidEmailMsg;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orangeAccent,
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 18.0,
              color: Colors.black,
              fontFamily: 'Google_Sans_Flex',
              fontWeight: FontWeight.bold,
            ),
          ),
          behavior: SnackBarBehavior.floating
        ),
      );
    }
  }

  @override
  void dispose() {
    namecontroller.dispose();
    passwordcontroller.dispose();
    mailcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height / 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFff5c30), Color(0xFFe74b1a)],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).size.height / 3,
              ),
              height: MediaQuery.of(context).size.height / 2,
              width: MediaQuery.of(context).size.width,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 60.0, left: 20.0, right: 20.0),
              child: Column(
                children: [
                  Center(
                    child: Image.asset(
                      "images/logo.png",
                      width: MediaQuery.of(context).size.width / 1.5,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 50.0),
                  Material(
                    elevation: 5.0,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height / 1.8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Form(
                        key: _formkey,
                        child: Column(
                          children: [
                            const SizedBox(height: 30.0),
                            Text(
                              S.of(context).signUp,
                              style: AppWidget.headlineTextFieldStyle(),
                            ),
                            const SizedBox(height: 30.0),

                            // Name
                            TextFormField(
                              controller: namecontroller,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return S.of(context).enterNameValidation;
                                }
                                if (value.trim().length < 2) {
                                  return S.of(context).nameTooShortValidation;
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: S.of(context).nameHint,
                                hintStyle: AppWidget.semiBoldTextFieldStyle(),
                                prefixIcon: const Icon(Icons.person_outlined),
                              ),
                            ),

                            const SizedBox(height: 30.0),

                            // Email
                            TextFormField(
                              controller: mailcontroller,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return S.of(context).enterEmailValidation;
                                }

                                final emailRegex = RegExp(
                                  r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
                                );

                                if (!emailRegex.hasMatch(value.trim())) {
                                  return S.of(context).invalidEmailMsg;
                                }

                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: S.of(context).emailHint,
                                hintStyle: AppWidget.semiBoldTextFieldStyle(),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                            ),

                            const SizedBox(height: 30.0),

                            // Password
                            TextFormField(
                              controller: passwordcontroller,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return S.of(context).enterPasswordValidation;
                                }
                                if (value.length < 6) {
                                  return S.of(context).passwordLengthValidation;
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: S.of(context).passwordHint,
                                hintStyle: AppWidget.semiBoldTextFieldStyle(),
                                prefixIcon: const Icon(Icons.password_outlined),
                              ),
                            ),

                            const SizedBox(height: 60.0),

                            GestureDetector(
                              onTap: () async {
                                if (_formkey.currentState!.validate()) {
                                  email = mailcontroller.text;
                                  name = namecontroller.text;
                                  password = passwordcontroller.text;

                                  await registration();
                                }
                              },
                              child: Material(
                                elevation: 5.0,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  width: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffff5722),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      S.of(context).signUpButton,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.0,
                                        fontFamily: 'Google_Sans_Flex',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        S.of(context).alreadyHaveAccount,
                        style: AppWidget.semiBoldTextFieldStyle(),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LogIn(),
                            ),
                          );
                        },
                        child: Text(
                          S.of(context).login,
                          style: TextStyle(
                            color: Color(0xffff5722),
                            fontSize: 18.0,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Google_Sans_Flex',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
