import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_errors.dart';
import 'app/last_puff_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LpErrors.install();
  runApp(const ProviderScope(child: LastPuffApp()));
}
