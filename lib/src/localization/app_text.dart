import 'package:flutter/widgets.dart';

String appText(BuildContext context, String en, String ja) {
  return Localizations.localeOf(context).languageCode == 'ja' ? ja : en;
}
