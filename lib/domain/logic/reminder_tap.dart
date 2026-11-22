import 'quit_program.dart';
import 'reminder_planner.dart';

/// What a local notification carries in its payload, so a tap can say which
/// reminder it was: the [kind], and for the daily program the [slot], the
/// [planDay] it was armed for and the [message] it held.
///
/// The wire format is `kind|slot|planDay|message`, an empty field meaning
/// absent, or the bare `kind` when nothing else is known — which is exactly
/// what every payload armed before this type existed looks like (`checkin`,
/// `danger`, …), so a notification scheduled by an older build still decodes
/// after the upgrade. Pure Dart: the payload is a string the OS hands back and
/// is never trusted, so every field is looked up and dropped on a miss, and
/// only an unreadable kind makes the whole payload no tap.
class ReminderTap {
  const ReminderTap(this.kind, {this.slot, this.planDay, this.message});

  final ReminderKind kind;
  final ProgramSlot? slot;
  final int? planDay;
  final ProgramMessage? message;

  String encode() {
    if (slot == null && planDay == null && message == null) return kind.name;
    return [
      kind.name,
      slot?.name ?? '',
      planDay?.toString() ?? '',
      message?.name ?? '',
    ].join('|');
  }

  static ReminderTap? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final parts = payload.split('|');
    final kind = ReminderKind.values.asNameMap()[parts[0]];
    if (kind == null) return null;
    String? field(int i) =>
        i < parts.length && parts[i].isNotEmpty ? parts[i] : null;
    final day = field(2);
    return ReminderTap(
      kind,
      slot: ProgramSlot.values.asNameMap()[field(1)],
      planDay: day == null ? null : int.tryParse(day),
      message: ProgramMessage.values.asNameMap()[field(3)],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTap &&
      other.kind == kind &&
      other.slot == slot &&
      other.planDay == planDay &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, slot, planDay, message);

  @override
  String toString() => 'ReminderTap(${encode()})';
}
