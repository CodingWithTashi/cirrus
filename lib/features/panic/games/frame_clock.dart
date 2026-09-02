import 'package:flutter/foundation.dart';

/// Ticks the painters once per frame without rebuilding the widget tree.
class FrameClock extends ChangeNotifier {
  void tick() => notifyListeners();
}
