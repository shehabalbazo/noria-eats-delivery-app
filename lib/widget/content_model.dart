import 'package:flutter/material.dart';
import 'package:food_delivery_app/generated/l10n.dart'; 

class UnboardingContent {
  String image;
  String title;
  String description;

  UnboardingContent({
    required this.description,
    required this.image,
    required this.title,
  });
}

//  : حولنا القائمة إلى دالة تستقبل BuildContext
List<UnboardingContent> getContents(BuildContext context) {
  return [
    UnboardingContent(
      title: S.of(context).onboardTitle1,
      description: S.of(context).onboardDesc1,
      image: "images/screen1.png",
    ),
    UnboardingContent(
      title: S.of(context).onboardTitle2,
      description: S.of(context).onboardDesc2,
      image: "images/screen2.png",
    ),
    UnboardingContent(
      title: S.of(context).onboardTitle3,
      description: S.of(context).onboardDesc3,
      image: "images/screen3.png",
    ),
  ];
}