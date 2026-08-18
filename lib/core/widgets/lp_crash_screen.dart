import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Replaces Flutter's red/grey error box when a widget subtree crashes.
///
/// This can render inside a BROKEN tree, so it must not depend on anything an
/// ancestor provides: no Theme (raw palette hexes below are a deliberate,
/// annotated deviation — they mirror LpColors' grounds), no AppLocalizations
/// (copy resolves from the platform locale via the const map below — the one
/// place UI strings live outside ARB files, because `Localizations` may be
/// exactly what just crashed).
class LpCrashScreen extends StatelessWidget {
  const LpCrashScreen({super.key, required this.details});

  final FlutterErrorDetails details;

  static const _copy = <String, ({String title, String body})>{
    'en': (
      title: 'well, this is awkward.',
      body:
          'this screen just fumbled — that\'s on us, not you. '
          'go back or restart the app and it should sort itself out.',
    ),
    'es': (
      title: 'vaya, qué corte.',
      body:
          'esta pantalla acaba de fallar — es cosa nuestra, no tuya. '
          'vuelve atrás o reinicia la app y debería arreglarse.',
    ),
    'fr': (
      title: 'bon, c\'est gênant.',
      body:
          'cet écran vient de planter — c\'est nous, pas toi. '
          'reviens en arrière ou relance l\'app et ça devrait rentrer dans l\'ordre.',
    ),
    'de': (
      title: 'okay, das ist peinlich.',
      body:
          'dieser Screen ist gerade abgestürzt — liegt an uns, nicht an dir. '
          'geh zurück oder starte die App neu, dann renkt sich das ein.',
    ),
    'pt': (
      title: 'ok, que vergonha.',
      body:
          'este ecrã acabou de falhar — a culpa é nossa, não tua. '
          'volta atrás ou reinicia a app e deve resolver-se.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final dark =
        ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark;
    final copy =
        _copy[ui.PlatformDispatcher.instance.locale.languageCode] ??
        _copy['en']!;
    // Midnight / Daylight Ember grounds + text tones, mirrored from LpColors.
    final ground = dark ? const Color(0xFF0A0C10) : const Color(0xFFF6F8F4);
    final title = dark ? const Color(0xFFFFFFFF) : const Color(0xFF191D27);
    final body = dark ? const Color(0xFF9AA3B2) : const Color(0xFF68727E);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: ground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🫠', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 14),
                Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  copy.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                    color: body,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 18),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: body.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
