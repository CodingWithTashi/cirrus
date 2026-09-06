import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';

/// The quiet window as a span on a noon-to-noon track.
///
/// Positions run 0–24 across the rail and the hour at a position is
/// `(12 + position) % 24`, so the usual night is one contiguous band in the
/// middle of the rail rather than two stubs at its ends. Any window of 1–23
/// hours that does not cross noon fits; nothing else is offered, and nothing
/// else is a quiet window anybody sets.
@immutable
class QuietTrack {
  const QuietTrack._(this.start, this.end);

  /// The span for a stored window. A start equal to its end (which the
  /// planner reads as "no quiet hours") cannot be drawn, so it opens as the
  /// shortest span instead; a window that crosses noon is pulled back so it
  /// fits. Neither is a state the rail itself can produce.
  factory QuietTrack.fromHours(int startHour, int endHour) {
    var start = (startHour - _noon + cells) % cells;
    final length = _clampInt(
      (endHour - startHour + cells) % cells,
      minLength,
      maxLength,
    );
    if (start + length > cells) start = cells - length;
    return QuietTrack._(start, start + length);
  }

  static const int cells = 24;
  static const int minLength = 1;
  static const int maxLength = 23;
  static const int _noon = 12;

  /// Rail positions, 0 ≤ [start] < [end] ≤ 24.
  final int start;
  final int end;

  int get length => end - start;
  int get startHour => hourAt(start);
  int get endHour => hourAt(end);

  /// The wall-clock hour at a rail position.
  static int hourAt(int position) => (_noon + position) % cells;

  /// The start knob moved to [position]; the end stays where it is.
  QuietTrack withStart(int position) => QuietTrack._(
    _clampInt(position, _max(0, end - maxLength), end - minLength),
    end,
  );

  /// The end knob moved to [position]; the start stays where it is.
  QuietTrack withEnd(int position) => QuietTrack._(
    start,
    _clampInt(position, start + minLength, _min(cells, start + maxLength)),
  );

  /// The whole band slid so that it starts at [startPosition], length kept.
  QuietTrack shiftedTo(int startPosition) {
    final s = _clampInt(startPosition, 0, cells - length);
    return QuietTrack._(s, s + length);
  }

  @override
  bool operator ==(Object other) =>
      other is QuietTrack && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'QuietTrack($startHour → $endHour)';
}

int _clampInt(int value, int low, int high) =>
    value < low ? low : (value > high ? high : value);
int _max(int a, int b) => a > b ? a : b;
int _min(int a, int b) => a < b ? a : b;

enum _Grip { start, end, band }

/// The rail in the danger-hours sheet: two knobs and the night between them.
///
/// A knob drag moves that end, snapping to the hour with a selection tick
/// on every hour crossed and a pill above the knob naming the hour under the
/// finger. A drag that starts inside the band slides the whole window with
/// its length kept. A tap on the rail outside the band brings the nearer knob
/// to it. Horizontal drags only, so the sheet's own vertical scroll and its
/// swipe-to-dismiss are never contested.
///
/// Oxygen, not ember: the danger chips above it wear ember, and the two
/// selections must never read as one. Stateless about the window itself —
/// the sheet owns it and re-answers the chips and the promise on every
/// change.
class QuietHoursBand extends StatefulWidget {
  const QuietHoursBand({
    super.key,
    required this.track,
    required this.onChanged,
  });

  final QuietTrack track;
  final ValueChanged<QuietTrack> onChanged;

  /// Rail geometry, shared with the test that drags it.
  static const double height = 36;
  static const double knobRadius = 14;
  static const double railHeight = 12;
  static const double axisHeight = 14;

  /// How close to a knob's centre a touch has to land to take that knob.
  static const double hitSlop = 22;

  @override
  State<QuietHoursBand> createState() => _QuietHoursBandState();
}

class _QuietHoursBandState extends State<QuietHoursBand> {
  _Grip? _grip;

  /// Band drag: where inside the band the finger landed, in cells, so the
  /// band does not jump to centre itself under the finger.
  double _grabOffset = 0;
  double _width = 1;

  double _positionAt(double dx) =>
      (dx / _width * QuietTrack.cells).clamp(0.0, QuietTrack.cells.toDouble());

  double _dxOf(int position) => position / QuietTrack.cells * _width;

  _Grip _nearer(double position) =>
      (position - widget.track.start).abs() <=
          (widget.track.end - position).abs()
      ? _Grip.start
      : _Grip.end;

  void _down(DragDownDetails d) {
    final dx = d.localPosition.dx;
    final p = _positionAt(dx);
    final t = widget.track;
    final nearStart = (_dxOf(t.start) - dx).abs() <= QuietHoursBand.hitSlop;
    final nearEnd = (_dxOf(t.end) - dx).abs() <= QuietHoursBand.hitSlop;
    final _Grip? grip;
    if (nearStart && nearEnd) {
      grip = _nearer(p);
    } else if (nearStart) {
      grip = _Grip.start;
    } else if (nearEnd) {
      grip = _Grip.end;
    } else if (p > t.start && p < t.end) {
      grip = _Grip.band;
      _grabOffset = p - t.start;
    } else {
      // Outside the band: the nearer knob follows on the first move, or
      // jumps on a tap — never on the touch itself, which may turn out to
      // be the sheet scrolling.
      grip = null;
    }
    setState(() => _grip = grip);
  }

  void _update(DragUpdateDetails d) {
    final p = _positionAt(d.localPosition.dx);
    _grip ??= _nearer(p);
    _apply(p);
  }

  void _tap(TapUpDetails d) {
    final p = _positionAt(d.localPosition.dx);
    final t = widget.track;
    if (p > t.start && p < t.end) return;
    _grip = _nearer(p);
    _apply(p);
    _grip = null;
  }

  void _apply(double p) {
    final t = widget.track;
    final next = switch (_grip) {
      _Grip.start => t.withStart(p.round()),
      _Grip.end => t.withEnd(p.round()),
      _Grip.band => t.shiftedTo((p - _grabOffset).round()),
      null => t,
    };
    if (next == t) return;
    LpHaptics.tick();
    widget.onChanged(next);
  }

  void _end() {
    if (_grip != null) setState(() => _grip = null);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final t = widget.track;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final cell = _width / QuietTrack.cells;
        final live = _grip;
        final tipAt = switch (live) {
          _Grip.end => t.end,
          _Grip.start || _Grip.band => t.start,
          null => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: QuietHoursBand.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // The drag starts where the finger landed, not a
                      // touch-slop later — a cell-quantized drag is a cell
                      // short otherwise (the Blocks lesson).
                      dragStartBehavior: DragStartBehavior.down,
                      onHorizontalDragDown: _down,
                      onHorizontalDragUpdate: _update,
                      onHorizontalDragEnd: (_) => _end(),
                      onHorizontalDragCancel: _end,
                      onTapUp: _tap,
                      child: CustomPaint(
                        painter: _RailPainter(track: t, lp: lp, live: live),
                      ),
                    ),
                  ),
                  // The moon, centred in the band. A widget rather than a
                  // painted path so it is the icon font's own glyph.
                  Positioned(
                    left: (t.start + t.end) / 2 * cell - 5,
                    top: 13,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.nightlight_round,
                        size: 10,
                        color: lp.oxygen,
                      ),
                    ),
                  ),
                  if (tipAt != null)
                    Positioned(
                      left: tipAt * cell,
                      top: -30,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: lp.surface,
                              borderRadius: BorderRadius.circular(
                                LpDimens.rChip,
                              ),
                              border: Border.all(color: lp.border),
                            ),
                            child: Text(
                              LpFormat.hour(QuietTrack.hourAt(tipAt), locale),
                              style: LpType.caption(
                                lp.oxygenText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Screen readers: two sliders, one per knob, an hour a step.
                  // A node with increase/decrease and a value must also say
                  // what the next and previous values are (the framework
                  // asserts on it), so each knob names its neighbours.
                  _KnobSemantics(
                    centerDx: _dxOf(t.start),
                    label: l10n.settingsQuietHoursStartHandle,
                    value: LpFormat.hour(t.startHour, locale),
                    increasedValue: LpFormat.hour(
                      t.withStart(t.start + 1).startHour,
                      locale,
                    ),
                    decreasedValue: LpFormat.hour(
                      t.withStart(t.start - 1).startHour,
                      locale,
                    ),
                    onIncrease: () => widget.onChanged(t.withStart(t.start + 1)),
                    onDecrease: () => widget.onChanged(t.withStart(t.start - 1)),
                  ),
                  _KnobSemantics(
                    centerDx: _dxOf(t.end),
                    label: l10n.settingsQuietHoursEndHandle,
                    value: LpFormat.hour(t.endHour, locale),
                    increasedValue: LpFormat.hour(
                      t.withEnd(t.end + 1).endHour,
                      locale,
                    ),
                    decreasedValue: LpFormat.hour(
                      t.withEnd(t.end - 1).endHour,
                      locale,
                    ),
                    onIncrease: () => widget.onChanged(t.withEnd(t.end + 1)),
                    onDecrease: () => widget.onChanged(t.withEnd(t.end - 1)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // The axis: noon, evening, midnight, morning, noon.
            SizedBox(
              height: QuietHoursBand.axisHeight,
              child: Stack(
                children: [
                  for (final p in const [0, 6, 12, 18, 24])
                    Positioned(
                      left: p == 24 ? null : (p == 0 ? 0 : p * cell - 22),
                      right: p == 24 ? 0 : null,
                      width: p == 0 || p == 24 ? null : 44,
                      child: Text(
                        LpFormat.hour(QuietTrack.hourAt(p), locale),
                        textAlign: p == 0
                            ? TextAlign.left
                            : p == 24
                            ? TextAlign.right
                            : TextAlign.center,
                        style: LpType.micro(lp.textFaint),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KnobSemantics extends StatelessWidget {
  const _KnobSemantics({
    required this.centerDx,
    required this.label,
    required this.value,
    required this.increasedValue,
    required this.decreasedValue,
    required this.onIncrease,
    required this.onDecrease,
  });

  final double centerDx;
  final String label;
  final String value;
  final String increasedValue;
  final String decreasedValue;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) => Positioned(
    left: centerDx - 22,
    top: -4,
    width: 44,
    height: 44,
    child: Semantics(
      slider: true,
      label: label,
      value: value,
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: const SizedBox.expand(),
    ),
  );
}

class _RailPainter extends CustomPainter {
  const _RailPainter({required this.track, required this.lp, this.live});

  final QuietTrack track;
  final LpColors lp;
  final _Grip? live;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / QuietTrack.cells;
    const top = (QuietHoursBand.height - QuietHoursBand.railHeight) / 2;
    const radius = Radius.circular(QuietHoursBand.railHeight / 2);
    final rail = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, size.width, QuietHoursBand.railHeight),
      radius,
    );
    canvas.drawRRect(rail, Paint()..color = lp.surfaceInset);
    canvas.drawRRect(
      rail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = lp.border,
    );
    final tick = Paint()
      ..color = lp.borderSubtle
      ..strokeWidth = 1;
    for (var h = 1; h < QuietTrack.cells; h++) {
      final x = h * cell;
      canvas.drawLine(
        Offset(x, top + 2),
        Offset(x, top + QuietHoursBand.railHeight - 2),
        tick,
      );
    }
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        track.start * cell,
        top,
        track.length * cell,
        QuietHoursBand.railHeight,
      ),
      radius,
    );
    canvas.drawRRect(band, Paint()..color = lp.oxygenSoft);
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = lp.oxygen.withValues(alpha: 0.55),
    );
    const midY = QuietHoursBand.height / 2;
    _knob(
      canvas,
      Offset(track.start * cell, midY),
      active: live == _Grip.start || live == _Grip.band,
    );
    _knob(
      canvas,
      Offset(track.end * cell, midY),
      active: live == _Grip.end || live == _Grip.band,
    );
  }

  void _knob(Canvas canvas, Offset c, {required bool active}) {
    if (active) {
      canvas.drawCircle(
        c,
        QuietHoursBand.knobRadius + 6,
        Paint()..color = lp.oxygenSoft,
      );
    }
    canvas.drawCircle(c, QuietHoursBand.knobRadius, Paint()..color = lp.surface);
    canvas.drawCircle(
      c,
      QuietHoursBand.knobRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = lp.oxygen,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 3, height: 10),
        const Radius.circular(2),
      ),
      Paint()..color = lp.oxygen.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.track != track || old.live != live || old.lp != lp;
}
