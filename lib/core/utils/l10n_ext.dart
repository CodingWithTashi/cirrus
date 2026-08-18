import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

export '../../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// BCP-47 tag of the active locale for `intl` formatters.
  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}
