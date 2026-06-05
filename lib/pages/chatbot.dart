import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:food_delivery_app/pages/profile.dart';
import 'package:food_delivery_app/pages/bottomnav.dart';
import 'package:food_delivery_app/pages/order.dart' as app_pages;
import 'package:food_delivery_app/pages/wallet.dart';
import 'package:food_delivery_app/pages/home.dart';
import 'package:food_delivery_app/service/shared_pref.dart';
import 'package:food_delivery_app/generated/l10n.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class ChatBot extends StatefulWidget {
  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMsg> _msgs = [];
  bool _isLeavingChat = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  late FlutterTts _flutterTts;
  // 🟢 المتغيرات للتحكم بإيقاف النطق
  bool _isPlayingTts = false;
  String _currentSpokenText = "";

  bool get shouldShowFeedback {
    return _msgs.any((msg) => msg.isUser);
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _setupTts();
  }

  // 🟢 قمنا بتبسيط الإعدادات هنا ونقل تحديد اللغة لداخل دالة النطق
  Future<void> _setupTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // 🟢 مراقبة حالة الصوت لتغيير الأيقونة
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isPlayingTts = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingTts = false;
          _currentSpokenText = "";
        });
      }
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingTts = false;
          _currentSpokenText = "";
        });
      }
    });
  }

  // 🟢 التعديل الأهم: دالة النطق أصبحت تأخذ لغة التطبيق الحالية وتتحدث بها
  // 🟢 تعديل: دالة النطق أصبحت تعمل كزر تشغيل وإيقاف (Toggle)
  Future<void> _toggleSpeak(String text) async {
    // إذا كان يتحدث الآن
    if (_isPlayingTts) {
      await _flutterTts.stop(); // أوقفه فوراً

      // إذا ضغطت على رسالة أخرى ليقرأها وهو يتحدث في الرسالة السابقة
      if (_currentSpokenText != text) {
        _speakNewText(text);
      }
    } else {
      _speakNewText(text);
    }
  }

  // 🟢 إضافة: دالة قراءة النص وتحديد اللغة
  Future<void> _speakNewText(String text) async {
    _currentSpokenText = text;
    String currentLocale = Localizations.localeOf(context).languageCode;
    String ttsLanguage = "en-US";

    if (currentLocale == 'ar') {
      ttsLanguage = "ar-SA";
    } else if (currentLocale == 'tr') {
      ttsLanguage = "tr-TR";
    }

    await _flutterTts.setLanguage(ttsLanguage);
    await _flutterTts.speak(text);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);

        // 🟢 جلب لغة التطبيق الحالية
        String currentLocale = Localizations.localeOf(context).languageCode;
        String sttLocale = "en_US"; // الافتراضي
        if (currentLocale == 'ar') sttLocale = "ar_SA"; // عربي
        if (currentLocale == 'tr') sttLocale = "tr_TR"; // تركي

        _speech.listen(
          // 🟢 إجبار الميكروفون على الاستماع بلغة التطبيق
          localeId: sttLocale,
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          }),
        );
      } else {
        setState(() => _isListening = false);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_msgs.isEmpty) {
      _msgs.add(
        _ChatMsg(
          text: S.of(context).aiWelcomeMessage,
          isUser: false,
          time: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
    }
  }

  Future<void> saveFeedbackToFirebase({
    required double rating,
    required String comment,
  }) async {
    final userId = await SharedPreferenceHelper().getUserId();
    final userName = await SharedPreferenceHelper().getUserName();
    final userEmail = await SharedPreferenceHelper().getUserEmail();

    await FirebaseFirestore.instance.collection("assistant_feedback").add({
      "userId": userId ?? "",
      "userName": userName ?? "",
      "userEmail": userEmail ?? "",
      "rating": rating,
      "comment": comment,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> showFeedbackSheet() async {
    double selectedRating = 0;
    final TextEditingController feedbackController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      S.of(context).rateAssistantTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    S.of(context).rateExperienceSubtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        onPressed: () {
                          setModalState(() {
                            selectedRating = starIndex.toDouble();
                          });
                        },
                        icon: Icon(
                          Icons.star,
                          size: 34,
                          color: selectedRating >= starIndex
                              ? Colors.amber
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: S.of(context).feedbackHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedRating == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                S.of(context).selectRatingValidation,
                              ),
                            ),
                          );
                          return;
                        }

                        await saveFeedbackToFirebase(
                          rating: selectedRating,
                          comment: feedbackController.text.trim(),
                        );

                        if (!mounted) return;

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.orangeAccent,
                            content: Text(
                              S.of(context).feedbackSuccessMsg,
                              style: const TextStyle(
                                fontSize: 18.0,
                                color: Colors.black,
                                fontFamily: 'Google_Sans_Flex',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text(S.of(context).submitButton),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> exitChat() async {
    if (_isLeavingChat) return;
    _isLeavingChat = true;

    _flutterTts.stop();
    _speech.stop();

    if (shouldShowFeedback) {
      await showFeedbackSheet();
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => BottomNav()),
      (route) => false,
    );
  }

  Widget _quickButton(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD6DFEA)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> askAI() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('chatWithAI');

      final history = _msgs.map((msg) {
        return {"role": msg.isUser ? "user" : "assistant", "content": msg.text};
      }).toList();

      final result = await callable.call({"messages": history});

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print("AI Error: $e");
      return {"reply": S.of(context).aiServiceError, "action": null};
    }
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _msgs.add(_ChatMsg(text: text, isUser: true, time: DateTime.now()));
    });
    _controller.clear();

    // استدعاء الـ Cloud Function مباشرة
    final result =
        await askAI(); // تأكد أن هذه الدالة تستدعي الـ Firebase Function

    String reply = result["reply"]?.toString() ?? "";
    final String? action = result["action"]?.toString();

    if (!mounted) return;

    setState(() {
      _msgs.add(_ChatMsg(text: reply, isUser: false, time: DateTime.now()));
    });

    if (action != null) handleAction(action);
  }

  Future<void> sendQuickMessage(String text) async {
    setState(() {
      _msgs.add(_ChatMsg(text: text, isUser: true, time: DateTime.now()));
    });

    final result = await askAI();
    final String reply = result["reply"]?.toString() ?? "";
    final String? action = result["action"]?.toString();

    if (!mounted) return;

    setState(() {
      _msgs.add(_ChatMsg(text: reply, isUser: false, time: DateTime.now()));
    });

    if (action != null) {
      handleAction(action);
    }
  }

  void handleAction(String action) {
    if (action == "open_profile") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Profile()),
      );
    } else if (action == "open_home") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BottomNav()),
      );
    } else if (action == "open_cart") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const app_pages.Order()),
      );
    } else if (action == "open_wallet") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Wallet()),
      );
    } else if (action == "open_pizza") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Pizza"),
        ),
      );
    } else if (action == "open_burger") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Burger"),
        ),
      );
    } else if (action == "open_salad") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Salad"),
        ),
      );
    } else if (action == "open_icecream") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Ice-cream"),
        ),
      );
    }
  }

  String _fmtTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? "PM" : "AM";
    return "$h:$m $ap";
  }

  // دالة للبحث عن كوبون نشط في قاعدة البيانات
  Future<String?> _getSmartCoupon() async {
    try {
      // نفترض أن عندك مجموعة اسمها "Coupons" وفيها حقل "code" وحقل "isActive"
      var snapshot = await FirebaseFirestore.instance
          .collection("Coupons")
          .where("isActive", isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['code'];
      }
    } catch (e) {
      print("Error fetching coupon: $e");
    }
    return null;
  }

  // دالة لفحص إذا كان نص المستخدم يحتوي على كلمات تردد أو بحث عن خصم
  bool _shouldSuggestCoupon(String text) {
    final keywords = [
      'pahalı', 'indirim', 'fiyat', 'ucuz', 'bütçe', 'kupon', 'promo', // تركي
      'غالي', 'خصم', 'كوبون', 'سعر', 'رخيص', 'تخفيض', // عربي
      'expensive', 'discount', 'coupon', 'price', 'cheap', 'budget', // إنجليزي
    ];

    return keywords.any((key) => text.toLowerCase().contains(key));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await exitChat();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF5FF),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await exitChat();
            },
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 8),
              _circleIcon(
                icon: Icons.smart_toy_outlined,
                bg: const Color(0xFF2F6BFF),
                iconColor: Colors.white,
                size: 40,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).aiAssistantTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 10),
                      const SizedBox(width: 6),
                      Text(
                        S.of(context).onlineStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == "clear_chat") {
                  setState(() {
                    _msgs.clear();
                    _msgs.add(
                      _ChatMsg(
                        text: S.of(context).aiWelcomeMessage,
                        isUser: false,
                        time: DateTime.now(),
                      ),
                    );
                  });
                } else if (value == "about") {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(S.of(context).aboutAssistantTitle),
                      content: Text(S.of(context).aboutAssistantContent),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                } else if (value == "close") {
                  await exitChat();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "clear_chat",
                  child: Text(S.of(context).clearChatMenu),
                ),
                PopupMenuItem(
                  value: "close",
                  child: Text(S.of(context).backToHomeMenu),
                ),
                PopupMenuItem(
                  value: "about",
                  child: Text(S.of(context).aboutAssistantMenu),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                itemCount: _msgs.length,
                itemBuilder: (context, i) {
                  final m = _msgs[i];
                  return _MessageRow(
                    text: m.text,
                    isUser: m.isUser,
                    timeText: _fmtTime(m.time),
                    // 🟢 إرسال دالة النطق للرسالة لكي يستدعيها زر الميكروفون
                    onSpeak: () => _toggleSpeak(m.text),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFEFF5FF),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickButton(
                      S.of(context).quickProfile,
                      () => sendQuickMessage("open profile"),
                    ),
                    _quickButton(
                      S.of(context).quickHome,
                      () => sendQuickMessage("open home"),
                    ),
                    _quickButton(
                      S.of(context).quickPizza,
                      () => sendQuickMessage("open pizza"),
                    ),
                    _quickButton(
                      S.of(context).quickBurger,
                      () => sendQuickMessage("open burger"),
                    ),
                    _quickButton(
                      S.of(context).quickSalad,
                      () => sendQuickMessage("open salad"),
                    ),
                    _quickButton(
                      S.of(context).quickIceCream,
                      () => sendQuickMessage("open ice cream"),
                    ),
                  ],
                ),
              ),
            ),
            _Composer(
              controller: _controller,
              onSend: _send,
              hintText: S.of(context).typeMessageHint,
              isListening: _isListening,
              onListen: _listen,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final bool isListening;
  final VoidCallback onListen;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.hintText,
    required this.isListening,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(color: Color(0xFFEFF5FF)),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E8F0)),
                ),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onListen,
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: isListening
                      ? Colors.redAccent.withOpacity(0.8)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E8F0)),
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: isListening ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6BFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final String text;
  final bool isUser;
  final String timeText;
  final VoidCallback? onSpeak;
  final bool isPlaying; // 🟢 إضافة متغير حالة التشغيل

  const _MessageRow({
    required this.text,
    required this.isUser,
    required this.timeText,
    this.onSpeak,
    this.isPlaying = false, // 🟢 القيمة الافتراضية
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? const Color(0xFF2F6BFF) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF0F172A);
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: align,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _circleIcon(
              icon: Icons.smart_toy_outlined,
              bg: const Color(0xFF2F6BFF),
              iconColor: Colors.white,
              size: 34,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(color: textColor, height: 1.25),
                  ),
                ),
                const SizedBox(height: 6),
                // 🟢 وضع وقت الرسالة وبجانبه أيقونة الاستماع (للبوت فقط)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (!isUser && onSpeak != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onSpeak,
                        // 🟢 تغيير الأيقونة ولونها إذا كان يتحدث
                        child: Icon(
                          isPlaying
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_rounded,
                          size: 18,
                          color: isPlaying
                              ? Colors.redAccent
                              : const Color(0xFF2F6BFF),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _circleIcon(
              icon: Icons.person,
              bg: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              size: 34,
            ),
          ],
        ],
      ),
    );
  }
}

Widget _circleIcon({
  required IconData icon,
  required Color bg,
  required Color iconColor,
  required double size,
}) {
  return Container(
    height: size,
    width: size,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Icon(icon, color: iconColor, size: size * 0.55),
  );
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final DateTime time;

  _ChatMsg({required this.text, required this.isUser, required this.time});
}
