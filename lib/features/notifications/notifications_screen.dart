import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';

/// Everything the app has told this account, kept.
///
/// The reason it exists: a push is a courtesy that may never arrive. Somebody
/// declined the permission, or has no device registered, or swiped the shade
/// clear on the bus without reading it, or spent the day's buzz budget. All of
/// those people still had somebody answer them, and until this screen there
/// was nowhere to find that out.
///
/// Nothing here is invented. Every row was written by the server when it
/// decided to notify this account, so an empty list is the honest state of an
/// account nobody has replied to yet — not a loading failure dressed up.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen IS reading them. The badge drops now rather than on
    // a per-row tap, because the alternative is a number that survives the
    // user having plainly looked at everything under it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsStoreProvider.notifier).markAllRead();
    });
  }

  /// Back, from a deep link as well as from Home.
  ///
  /// `GoRouter.pop()` throws on an empty stack rather than doing nothing.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  void _open(AppNotification item) {
    ref.read(notificationsStoreProvider.notifier).markRead(item.id);
    final route = item.route;
    if (route == null || route.isEmpty) return;
    // Allow-listed exactly like a push payload's, and for the same reason:
    // this string came off the wire, and a destination is an instruction.
    if (!_allowed.any((a) => route == a || route.startsWith('$a/'))) return;
    context.push(route);
  }

  static const _allowed = {
    Routes.community,
    Routes.insight,
    Routes.coach,
    Routes.home,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeTag;
    final state = ref.watch(notificationsStoreProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: _back),
        title: Text(l10n.notificationsTitle),
      ),
      body: SafeArea(
        child: state.items.isEmpty
            ? LpErrorState(
                icon: Icons.notifications_off_outlined,
                title: l10n.notificationsEmptyTitle,
                body: l10n.notificationsEmptyBody,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NotificationRow(
                  item: state.items[i],
                  locale: locale,
                  onTap: () => _open(state.items[i]),
                ),
              ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.locale,
    required this.onTap,
  });

  final AppNotification item;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return PressScale(
      onTap: onTap,
      child: LpCard(
        radius: LpDimens.rInput,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The unread mark is a dot, not a bold row: an inbox where every
            // unread item shouts is an inbox nobody scans.
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isUnread ? lp.volt : Colors.transparent,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: LpType.body14(
                      lp.textPrimary,
                      weight: item.isUnread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(item.body, style: LpType.body13(lp.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    LpFormat.weekdayDate(item.createdAt, locale),
                    style: LpType.caption(lp.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bell on Home, with its unread count.
///
/// A drawn icon, not an emoji. It sits in chrome, between a real avatar and
/// the streak chip and directly above a nav bar of Material glyphs, so a
/// platform emoji here was the one thing on the screen the app had not drawn
/// itself — a different picture on every OS version, at a weight and colour
/// nothing else shares.
///
/// The badge renders NOTHING at zero rather than a `0`: a badge is a claim
/// that something is waiting, and it must not make one when nothing is. It
/// carries a ring in the background colour so the count stays legible where
/// it overlaps the bell, and caps at `9+` so a busy week cannot widen it into
/// the avatar beside it.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  /// Matches the avatar and streak chip beside it.
  static const double _size = 38;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final unread = ref.watch(notificationsStoreProvider).unread;

    return PressScale(
      onTap: () => context.push(Routes.notifications),
      child: Semantics(
        button: true,
        label: unread > 0
            ? l10n.notificationsBadgeLabel(unread)
            : l10n.notificationsTitle,
        child: SizedBox(
          width: _size,
          height: _size,
          // Positioned children so the count cannot change the bell's
          // footprint as it grows, and `Clip.none` so the badge may sit
          // proud of the corner.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 24,
                  color: unread > 0 ? lp.textPrimary : lp.textSecondary,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lp.ember,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: lp.background, width: 2),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      // `onEmber`, never `emberText`. This is ink on an ember
                      // FILL, and `emberText` is ember-coloured text for a
                      // dark GROUND — in Midnight Ember the two are the same
                      // hex, so the count rendered orange on orange and no
                      // user ever saw a number. Verified on device.
                      style: LpType.caption(
                        lp.onEmber,
                        weight: FontWeight.w700,
                      ).copyWith(fontSize: 10, height: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
