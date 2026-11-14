import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import '../../l10n/gen/app_localizations.dart';

export '../../l10n/gen/app_localizations.dart';

/// The localization delegates every `MaterialApp` takes: the app's, and any
/// a test builds for itself.
///
/// Not `AppLocalizations.localizationsDelegates`. gen-l10n still fills that
/// list from `flutter_localizations`, whose Material and Cupertino delegates
/// serve the deprecated SDK copies of those classes. A `material_ui` widget
/// asks for its own `MaterialLocalizations`; only English has a default built
/// into `MaterialApp`, so with the generated list the other five locales fail
/// on the first back button or dialog with "No MaterialLocalizations found"
/// (docs/10 §56.7). `GlobalMaterialLocalizations.delegates` is the list the
/// Flutter migration guide names: Material, Cupertino and Widgets together.
const List<LocalizationsDelegate<dynamic>> lpLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// BCP-47 tag of the active locale for `intl` formatters.
  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}
