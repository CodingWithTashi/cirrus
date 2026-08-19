import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_errors.dart';
import 'app/last_puff_app.dart';
import 'data/backend_mode.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (resolveBackendMode() == BackendMode.firebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  LpErrors.install();
  runApp(const ProviderScope(child: LastPuffApp()));
}
