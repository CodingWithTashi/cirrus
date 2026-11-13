import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/help_directory.dart';

/// More help (docs/15 QP-A7): the page that says an app is not the only way,
/// and where the other ways are for the country the phone is set to.
///
/// Two things, deliberately plain. A medicine section that says what the
/// evidence found and hands the decision to a doctor or pharmacist — no dose,
/// no promise, nothing a person could read as advice to take it. And the
/// official quit lines for the device's country, each with the page it was
/// checked against one tap away.
///
/// Reachable without a journey (see `Routes.help`): it is information, and the
/// one screen that should never sit behind a sign-in.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key, required this.source});

  /// The door this was opened through, for `help_viewed`.
  final String source;

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  /// The review the medicine paragraph rests on (docs/15 §11).
  static final _research = Uri.parse(
    'https://doi.org/10.1002/14651858.CD016058.pub3',
  );

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).helpViewed(widget.source);
  }

  /// The event goes first: a launch that fails (no dialler, no browser) is
  /// still somebody reaching for help, and that is what the event counts.
  void _open(Uri uri, String kind) {
    ref.read(analyticsProvider).helpLinkOpened(kind);
    ref.read(linkOpenerProvider)(uri).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final entries = HelpDirectory.forCountry(ref.watch(deviceRegionProvider));

    return Scaffold(
      appBar: AppBar(leading: const BackChevron()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(l10n.helpTitle, style: LpType.title(lp.textPrimary)),
            const SizedBox(height: 10),
            Text(l10n.helpIntro, style: LpType.body14(lp.textSecondary)),
            const SizedBox(height: 28),

            Text(
              l10n.helpMedicineTitle,
              style: LpType.heading(lp.textPrimary),
            ),
            const SizedBox(height: 10),
            LpCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.helpMedicineBody,
                    style: LpType.body14(lp.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _ActionChip(
                    label: l10n.helpMedicineSource,
                    onTap: () => _open(_research, 'medicine'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(l10n.helpPeopleTitle, style: LpType.heading(lp.textPrimary)),
            const SizedBox(height: 6),
            Text(l10n.helpPeopleNote, style: LpType.caption(lp.textSecondary)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(l10n.helpNoLocal, style: LpType.body14(lp.textPrimary))
            else
              for (final e in entries) ...[
                _EntryCard(entry: e, onOpen: _open),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 4),
            Text(l10n.helpDoctorLine, style: LpType.body14(lp.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onOpen});

  final HelpEntry entry;
  final void Function(Uri uri, String kind) onOpen;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.name,
            style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
          ),
          if (entry.phone != null) ...[
            const SizedBox(height: 4),
            Text(entry.phone!, style: LpType.body14(lp.textSecondary)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (entry.dial != null)
                _ActionChip(
                  label: l10n.helpCall,
                  onTap: () =>
                      onOpen(Uri(scheme: 'tel', path: entry.dial), 'call'),
                ),
              if (entry.url != null)
                _ActionChip(
                  label: l10n.helpOpenSite,
                  onTap: () => onOpen(Uri.parse(entry.url!), 'web'),
                ),
              _ActionChip(
                label: l10n.helpSourceLink,
                onTap: () => onOpen(Uri.parse(entry.sourceUrl), 'source'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tappable label. Never "selected": these are actions, not choices.
class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LpChip(
    label: label,
    selected: false,
    fontSize: 14,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    onTap: onTap,
  );
}
