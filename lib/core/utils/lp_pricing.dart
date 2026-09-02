// Re-export: the locked prices live in `domain/logic/lp_pricing.dart` so the
// data layer's fake store can price its offering without importing `core`.
// Views keep importing this path.
export '../../domain/logic/lp_pricing.dart';
