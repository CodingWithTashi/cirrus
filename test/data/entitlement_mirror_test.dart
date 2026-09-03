import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/billing_catalog.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// The purchase→mirror window.
///
/// A purchase makes THIS DEVICE premium the instant the store sheet returns.
/// The server's own copy — `users/{uid}.entitlement`, the only tier it trusts
/// — is written by RevenueCat's webhook, which lands whenever it lands. Every
/// server-side wall reads that copy, so in between them the app shows Premium
/// while `aiCoachChat` still meters five messages and `createPost` still
/// refuses a second post. The person who hits that is the one who just paid.
///
/// `EntitlementStore` therefore asks the server to re-read the store itself
/// the moment a purchase or a restore resolves. These pin that it happens,
/// that it happens only when there is something to mirror, and — the part
/// that matters most — that its failure is never the user's problem.
void main() {
  late _RecordingServerState server;

  ProviderContainer make({bool premium = false}) {
    server = _RecordingServerState();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: premium),
        serverStateRepositoryProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a completed purchase warms the server mirror', () async {
    final container = make();
    final store = container.read(entitlementProvider.notifier);

    final outcome = await store.purchase(BillingCatalog.annualPackage);

    expect(outcome, isA<PurchaseCompleted>());
    expect(container.read(isPremiumProvider), isTrue);
    expect(
      server.refreshes,
      1,
      reason: 'the server must be told to re-read the store, not left to '
          'wait on a webhook while the app already shows Premium',
    );
  });

  test('a purchase still completes when the refresh fails', () async {
    final container = make();
    server.failure = NoConnectionException();
    final store = container.read(entitlementProvider.notifier);

    final outcome = await store.purchase(BillingCatalog.annualPackage);

    // The receipt is real whatever the follow-up did. Surfacing this failure
    // would tell someone who has paid that their purchase did not work.
    expect(outcome, isA<PurchaseCompleted>());
    expect(container.read(isPremiumProvider), isTrue);
  });

  test('a cancelled purchase asks for no refresh', () async {
    final container = make();
    container.read(fakeServerProvider).nextPurchase = FakePurchaseScript.cancelled;
    final store = container.read(entitlementProvider.notifier);

    final outcome = await store.purchase(BillingCatalog.annualPackage);

    expect(outcome, isA<PurchaseCancelled>());
    expect(server.refreshes, 0, reason: 'nothing was bought');
  });

  test('a restore that finds a subscription warms the mirror', () async {
    final container = make(premium: true);
    final store = container.read(entitlementProvider.notifier);

    final restored = await store.restore();

    expect(restored.isActive, isTrue);
    expect(server.refreshes, 1);
  });

  test('a restore that finds nothing asks for no refresh', () async {
    final container = make();
    final store = container.read(entitlementProvider.notifier);

    final restored = await store.restore();

    expect(restored.isActive, isFalse);
    expect(
      server.refreshes,
      0,
      reason: 'there is nothing for the server to mirror',
    );
  });
}

class _RecordingServerState implements ServerStateRepository {
  int refreshes = 0;
  Object? failure;

  @override
  Future<bool> refreshEntitlement() async {
    refreshes++;
    if (failure != null) throw failure!;
    return true;
  }

  @override
  Future<PlanAdvice?> planAdvice() async => null;

  @override
  Future<WeeklyInsight?> latestInsight() async => null;
}
