import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/logic/age_entry_engine.dart';
import '../../domain/models/models.dart';
import '../../domain/models/onboarding_draft.dart';
import '../dto/codec_helpers.dart';

/// A draft found on disk, with when it was written.
class OnboardingDraft {
  const OnboardingDraft({required this.state, required this.savedAt});

  final OnboardingState state;
  final DateTime savedAt;
}

/// Disk for the onboarding draft.
///
/// The funnel is nineteen screens and about two and a half minutes, and until
/// now every answer lived only in a Riverpod notifier — kill the app at 8/12
/// and the whole thing was gone, with the first and only write happening after
/// the paywall.
///
/// **One JSON string under one key, not fifteen keys.** `SettingsPersistence`
/// uses a key per field because it is eight independent scalars with
/// independent defaults. A draft is a *document*: it resumes whole or not at
/// all, and a process killed between key seven and key eight would come back
/// with mismatched answers. One `setString` is one write.
///
/// Like every other persistence file here, nothing in it throws: a load
/// failure is an absent draft and a save failure is dropped. Losing a draft is
/// a small annoyance; failing a launch over one is not a trade worth making.
abstract final class OnboardingDraftPersistence {
  static const String _key = 'onboarding.draft';

  /// Bumped whenever the payload shape changes. A mismatch is treated as
  /// absent AND the key is removed, so a stale shape cannot linger.
  static const int schemaVersion = 1;

  /// A weekend abandonment is exactly the case this exists for, so a day is
  /// too short. Longer is worse, though, and the reason is specific:
  /// `puffsInput` is the baseline the entire taper curve divides through
  /// (`QuitPlan.costPerPuff`, `TaperEngine.limitFor`), so a three-week-old
  /// baseline produces a plan that misrepresents the user permanently.
  /// Re-asking one question is cheaper than a wrong curve.
  static const Duration ttl = Duration(days: 7);

  /// The stored draft, or null when there is none, it is corrupt, it is from
  /// another schema, it has expired, or it belongs to someone under 18.
  ///
  /// [now] is injected so "a stale draft does not resume" is a synchronous
  /// unit test rather than a `Future.delayed`.
  static Future<OnboardingDraft?> load({required DateTime now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['v'] != schemaVersion) {
        await prefs.remove(_key);
        return null;
      }

      final savedAt = decodeTimestamp(json['savedAt'] as String);
      if (now.difference(savedAt) > ttl) {
        await prefs.remove(_key);
        return null;
      }

      final state = _decode(json);

      // docs/02 §3 A3 on the under-18 gate: "No data stored." The view model
      // erases the draft the moment it learns this, but an in-flight write
      // racing process death is not a compliance argument, so the read side
      // refuses independently. This also covers a birthday crossed since the
      // draft was written.
      if (_isAgeGated(state, now)) {
        await prefs.remove(_key);
        return null;
      }

      return OnboardingDraft(state: state, savedAt: savedAt);
    } on Object {
      // Corrupt, truncated, or a preferences store that will not open. An
      // unreadable draft is the same as no draft.
      return null;
    }
  }

  static Future<void> save(OnboardingState state, {required DateTime now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_encode(state, now)));
    } on Object {
      // Write-behind, like every other optimistic save in the app.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object {
      // Nothing to do about it, and nothing worth failing over.
    }
  }

  static bool _isAgeGated(OnboardingState state, DateTime now) {
    if (state.step == ObStep.under18) return true;
    final entry = AgeEntryEngine.interpret(
      state.birthYearInput,
      currentYear: now.year,
    );
    return entry.kind == BirthEntryKind.underAge;
  }

  /// Kept private on purpose. `lib/data/dto/` is the *wire* layer, mirrored by
  /// `functions/src/domain/journeyCodec.ts` and gated by
  /// `dto_roundtrip_test.dart`; a draft never crosses the wire, and filing it
  /// there would imply a server counterpart that must not exist.
  static Map<String, dynamic> _encode(OnboardingState s, DateTime now) => {
    'v': schemaVersion,
    'savedAt': encodeTimestamp(now),
    'step': s.step.name,
    'email': s.email,
    'gender': s.gender?.name,
    'birthYearInput': s.birthYearInput,
    'attempts': s.attempts?.name,
    'frequency': s.frequency?.name,
    'puffsInput': s.puffsInput,
    'strength': s.strength?.name,
    'spendInput': s.spendInput,
    'firstPuff': s.firstPuff?.name,
    'whys': s.whys.map((w) => w.name).toList(),
    'worries': s.worries.map((w) => w.name).toList(),
    'method': s.method.name,
    'paceDays': s.paceDays,
    // The longest thing anyone types in the funnel, so it is the answer it
    // would hurt most to lose to a process kill. No schema bump: an added key
    // with a default cannot make an older draft decode into garbage, and
    // bumping would throw away every in-flight draft to add a field.
    'whyWordsInput': s.whyWordsInput,
    // Same treatment: a typed coach name lost to a process kill resurfaces
    // as "Ember" on resume, which reads as the rename not taking.
    'coachNameInput': s.coachNameInput,
    'committed': s.committed,
  };

  static OnboardingState _decode(Map<String, dynamic> json) {
    Set<T> set<T extends Enum>(List<T> values, Object? raw) => {
      for (final name in (raw as List?) ?? const [])
        ?enumByNameOrNull(values, name),
    };

    return OnboardingState(
      // A step name this build does not know restarts the funnel rather than
      // throwing — the same forward-compatibility stance the DTO codecs take.
      step: enumByName(ObStep.values, json['step'], ObStep.welcome),
      email: json['email'] as String?,
      gender: enumByNameOrNull(Gender.values, json['gender']),
      birthYearInput: json['birthYearInput'] as String? ?? '',
      attempts: enumByNameOrNull(QuitAttempts.values, json['attempts']),
      frequency: enumByNameOrNull(VapeFrequency.values, json['frequency']),
      puffsInput: json['puffsInput'] as String? ?? '',
      strength: enumByNameOrNull(NicStrength.values, json['strength']),
      spendInput: json['spendInput'] as String? ?? '',
      firstPuff: enumByNameOrNull(FirstPuffWindow.values, json['firstPuff']),
      whys: set(WhyChip.values, json['whys']),
      worries: set(WorryChip.values, json['worries']),
      method: enumByName(QuitMethod.values, json['method'], QuitMethod.taper),
      paceDays: json['paceDays'] as int? ?? 30,
      whyWordsInput: json['whyWordsInput'] as String? ?? '',
      coachNameInput: json['coachNameInput'] as String? ?? '',
      committed: json['committed'] as bool? ?? false,
    );
  }
}
