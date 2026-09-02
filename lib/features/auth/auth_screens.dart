import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_links.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import 'apple_sign_in_button.dart';
import 'login_defaults.dart';
import '../../domain/repositories/repositories.dart';
import '../onboarding/onboarding_view_model.dart';

/// Frame 26 — Apple primary, email second-class but never hidden.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _appleBusy = false;
  bool _googleBusy = false;

  /// Native identity buttons follow the device — Apple on Apple platforms,
  /// Google on Android; email is always available.
  static bool get _showApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static bool get _showGoogle =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> _signInApple() => _signInWithIdentity(
    busy: _appleBusy,
    setBusy: (value) => _appleBusy = value,
    signIn: ref.read(quitStoreProvider.notifier).signInWithApple,
    retry: _signInApple,
  );

  Future<void> _signInGoogle() => _signInWithIdentity(
    busy: _googleBusy,
    setBusy: (value) => _googleBusy = value,
    signIn: ref.read(quitStoreProvider.notifier).signInWithGoogle,
    retry: _signInGoogle,
  );

  /// One flow for both native identity buttons. A new account onboards; one
  /// that already onboarded gets its journey restored from the backend.
  ///
  /// Three outcomes, each with its designated surface: a dismissed sheet is
  /// not an error and shows nothing; a failure goes to [showLpErrorDialog]
  /// with a retry; success routes on whether a journey came back. The busy
  /// flag is released in `finally`, not per branch, so an unexpected `Error`
  /// — which `on Exception` deliberately leaves to `LpErrors` — can never
  /// strand the button in its spinner.
  Future<void> _signInWithIdentity({
    required bool busy,
    required ValueSetter<bool> setBusy,
    required Future<bool> Function() signIn,
    required Future<void> Function() retry,
  }) async {
    if (busy) return;
    setState(() => setBusy(true));
    bool? restored;
    Exception? failure;
    try {
      restored = await signIn();
    } on SignInCancelledException {
      // Dismissed the native sheet — not an error.
    } on Exception catch (error) {
      failure = error;
    } finally {
      if (mounted) setState(() => setBusy(false));
    }
    if (!mounted) return;
    if (failure != null) {
      await showLpErrorDialog(context, error: failure, onRetry: retry);
    } else if (restored != null) {
      context.go(restored ? Routes.home : Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: Wordmark()),
              const Spacer(),
              Text(
                l10n.authSignInTitle,
                style: LpType.title(lp.textPrimary, size: 34),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.authSignInSubtitle,
                style: LpType.body14(lp.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_showApple) ...[
                AppleSignInButton(
                  l10n.authSignInWithApple,
                  busy: _appleBusy,
                  onTap: _signInApple,
                ),
                const SizedBox(height: 12),
              ],
              if (_showGoogle) ...[
                LpButton(
                  l10n.authSignInWithGoogle,
                  style: LpButtonStyle.surface,
                  busy: _googleBusy,
                  onTap: _signInGoogle,
                ),
                const SizedBox(height: 12),
              ],
              LpButton(
                l10n.authContinueWithEmail,
                style: LpButtonStyle.surface,
                onTap: () => context.push(Routes.register),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: lp.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l10n.authWhyAccountDivider,
                      style: LpType.caption(lp.textSecondary),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: lp.border)),
                ],
              ),
              const SizedBox(height: 20),
              LpCard(
                radius: LpDimens.rInput,
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.authWhyAccountCard,
                  style: LpType.body13(lp.textSecondary),
                ),
              ),
              const Spacer(),
              // "Restore Purchase" is gone: there is no billing SDK, so it
              // named a control that could not exist — the same reason the two
              // real Restore buttons were deleted rather than faked. It comes
              // back with subscriptions, where it is a store requirement.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegalLink(label: l10n.authTerms, url: LpLinks.terms),
                  Text(' · ', style: LpType.caption(lp.textSecondary)),
                  _LegalLink(label: l10n.authPrivacy, url: LpLinks.privacy),
                ],
              ),

              // Debug builds only — see the note in Settings. This entry
              // point was the worse of the two: it is reachable before anyone
              // has signed in, so the first thing a new user could do is give
              // themselves somebody else's twelve-day streak.
            ],
          ),
        ),
      ),
    );
  }
}

/// Auth forms scroll under a min-height so the keyboard never overflows
/// them; the Spacer-pinned footer stays put whenever there's room — the same
/// idiom as the community composer.
class _AuthScrollView extends StatelessWidget {
  const _AuthScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}

/// Frame 27 — live strength meter, casual copy, never red-alarm.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _show = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Firebase's floor. Checked here too so the common case never spends a
  /// round trip — and mapped in `guardAuth` so a backend with a stricter
  /// rule still gets the same copy instead of the glitch dialog (QA M4).
  static const int _minPasswordLength = 6;

  Future<void> _createAccount() async {
    if (!_email.text.contains('@')) {
      showLpSnack(context, context.l10n.authInvalidEmail);
      return;
    }
    if (_password.text.length < _minPasswordLength) {
      showLpSnack(context, context.l10n.authPasswordTooShort);
      return;
    }
    final email = _email.text.trim();
    setState(() => _busy = true);
    try {
      await ref
          .read(quitStoreProvider.notifier)
          .register(email: email, password: _password.text);
    } on EmailAlreadyInUseException {
      if (!mounted) return;
      setState(() => _busy = false);
      showLpSnack(context, context.l10n.authEmailInUse);
      return;
    } on WeakPasswordException {
      if (!mounted) return;
      setState(() => _busy = false);
      showLpSnack(context, context.l10n.authPasswordTooShort);
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showLpErrorDialog(context, error: error, onRetry: _createAccount);
      return;
    }
    if (!mounted) return;
    ref.read(onboardingProvider.notifier).setEmail(email);
    context.go(Routes.onboarding);
  }

  int get _strength {
    final len = _password.text.length;
    if (len == 0) return 0;
    if (len < 6) return 1;
    if (len < 10) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _AuthScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackChevron(onTap: () => context.pop()),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.authRegisterTitle,
                  style: LpType.title(lp.textPrimary),
                ),
                const SizedBox(height: 26),
                LpField(
                  label: l10n.authEmailLabel,
                  controller: _email,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                LpField(
                  label: l10n.authPasswordLabel,
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscure: !_show,
                  onChanged: (_) => setState(() {}),
                  trailing: PressScale(
                    onTap: () => setState(() => _show = !_show),
                    child: Text(
                      _show ? l10n.authHidePassword : l10n.authShowPassword,
                      style: LpType.caption(lp.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      AnimatedContainer(
                        duration: LpMotion.fast,
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: i < _strength ? lp.volt : lp.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Text(
                      _strength == 0
                          ? ''
                          : _strength < 2
                          ? l10n.authPasswordStrengthWeak
                          : _strength == 2
                          ? l10n.authPasswordStrengthDecent
                          : l10n.authPasswordStrengthStrong,
                      style: LpType.caption(lp.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                LpNoteCard(l10n.authNoSpamCard),
                const SizedBox(height: 14),
                LpButton(
                  l10n.authCreateAccount,
                  busy: _busy,
                  onTap: _createAccount,
                ),
                const SizedBox(height: 6),
                Center(
                  child: PressScale(
                    onTap: () => context.pushReplacement(Routes.login),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text.rich(
                        TextSpan(
                          text: '${l10n.authAlreadyHaveOne} ',
                          style: LpType.body13(lp.textSecondary),
                          children: [
                            TextSpan(
                              text: l10n.authLogIn,
                              style: LpType.body13(
                                lp.voltText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frame 28 — "Your streak missed you." Wrong password shakes the field.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _email = TextEditingController(
    text: LoginDefaults.email(ref.read(backendModeProvider)),
  );
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _shakeKey = GlobalKey<ShakeItState>();
  bool _show = false;
  bool _wrongPassword = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    LpHaptics.medium();
    final email = _email.text.trim();
    setState(() => _busy = true);
    final bool restored;
    try {
      restored = await ref
          .read(quitStoreProvider.notifier)
          .logIn(email: email, password: _password.text);
    } on InvalidCredentialsException {
      // Frame 28: wrong password shakes the field 2px, copy stays kind.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _wrongPassword = true;
      });
      _shakeKey.currentState?.shake();
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showLpErrorDialog(context, error: error, onRetry: _logIn);
      return;
    }
    if (!mounted) return;
    if (restored) {
      context.go(Routes.home);
    } else {
      // Registered but never onboarded — the backend has no journey yet.
      ref.read(onboardingProvider.notifier).setEmail(email);
      context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _AuthScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackChevron(onTap: () => context.pop()),
                ),
                const SizedBox(height: 16),
                Text(l10n.authLoginTitle, style: LpType.title(lp.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  l10n.authLoginSubtitle,
                  style: LpType.body14(lp.textSecondary),
                ),
                const SizedBox(height: 26),
                LpField(
                  label: l10n.authEmailLabel,
                  controller: _email,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                // Frame 28: wrong password shakes the field 2px, copy stays kind.
                ShakeIt(
                  key: _shakeKey,
                  child: LpField(
                    label: l10n.authPasswordLabel,
                    controller: _password,
                    focusNode: _passwordFocus,
                    obscure: !_show,
                    onChanged: (_) {
                      if (_wrongPassword) {
                        setState(() => _wrongPassword = false);
                      }
                    },
                    trailing: PressScale(
                      onTap: () => setState(() => _show = !_show),
                      child: Text(
                        _show ? l10n.authHidePassword : l10n.authShowPassword,
                        style: LpType.caption(lp.textSecondary),
                      ),
                    ),
                  ),
                ),
                if (_wrongPassword) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.authWrongPassword,
                    style: LpType.caption(
                      lp.dangerText,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: PressScale(
                    onTap: () => context.push(Routes.forgot),
                    child: Text(
                      l10n.authForgotPassword,
                      style: LpType.body13(
                        lp.voltText,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                LpButton(l10n.authLogIn, busy: _busy, onTap: _logIn),
                const SizedBox(height: 12),
                PressScale(
                  onTap: () => context.pushReplacement(Routes.register),
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        text: '${l10n.authNewHere} ',
                        style: LpType.body13(lp.textSecondary),
                        children: [
                          TextSpan(
                            text: l10n.authCreateAccount,
                            style: LpType.body13(
                              lp.voltText,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frame 29 — inline success state, resend disabled 30s with countdown.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(
    text: LoginDefaults.email(ref.read(backendModeProvider)),
  );
  final _emailFocus = FocusNode();
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _send() {
    LpHaptics.light();
    // Optimistic: the success banner shows at once, the request rides behind
    // (a real backend re-sends on the next tap if this one got lost).
    ref
        .read(quitStoreProvider.notifier)
        .requestPasswordReset(_email.text.trim())
        .ignore();
    setState(() {
      _sent = true;
      _cooldown = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _AuthScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackChevron(onTap: () => context.pop()),
                ),
                const SizedBox(height: 16),
                Text(l10n.authForgotTitle, style: LpType.title(lp.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  l10n.authForgotSubtitle,
                  style: LpType.body14(lp.textSecondary),
                ),
                const SizedBox(height: 26),
                LpField(
                  label: l10n.authEmailLabel,
                  controller: _email,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AnimatedOpacity(
                  opacity: _sent ? 1 : 0,
                  duration: LpMotion.normal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: lp.voltSoft,
                      borderRadius: BorderRadius.circular(LpDimens.rInput),
                      border: Border.all(
                        color: lp.volt.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '✓',
                          style: LpType.body13(
                            lp.voltText,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.authLinkSent,
                            style: LpType.body13(lp.textBody),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Opacity(
                  opacity: _cooldown > 0 ? 0.55 : 1,
                  child: LpButton(
                    _cooldown > 0
                        ? l10n.authResendCountdown(_cooldown)
                        : _sent
                        ? l10n.authResendLink
                        : l10n.commonContinue,
                    onTap: _cooldown > 0 ? null : _send,
                  ),
                ),
                const SizedBox(height: 12),
                LpTextButton(l10n.authBackToLogin, onTap: () => context.pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two legal links in the sign-in footer.
///
/// Underlined rather than merely tinted: these have to be recognisable as
/// links to a store reviewer looking for them, and colour alone is not enough
/// for someone who cannot distinguish it.
class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return GestureDetector(
      onTap: () => LpLinks.open(url),
      child: Text(
        label,
        style: LpType.caption(
          lp.textSecondary,
        ).copyWith(decoration: TextDecoration.underline),
      ),
    );
  }
}
