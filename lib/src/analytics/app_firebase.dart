import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

Future<void> ensureSongBriefFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    await Firebase.initializeApp();
  }
}
