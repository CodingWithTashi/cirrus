import SwiftUI

/// Midnight Ember, on the wrist.
///
/// The same deliberate deviation the home-screen widget documents in
/// `CLAUDE.md`'s theming section: a SwiftUI view outside the Flutter engine
/// draws itself, so it cannot read `context.lp` and cannot follow the three
/// palette families. It wears Midnight Ember always — which on a watch is also
/// simply correct, because watchOS has no light mode.
///
/// Every value carries its hex in a comment, and `test/ios_watch_test.dart`
/// checks the comment against `LpColors.midnight()` **and** the RGB components
/// against the comment — so neither half can drift alone. `danger` is the same
/// `#FF5C5C` it is in all six palettes: an alert must not change meaning when
/// the reader changes their theme.
extension Color {
    static let cwVoid = Color(red: 0.039, green: 0.047, blue: 0.063) // #0A0C10
    static let cwSurface = Color(red: 0.086, green: 0.102, blue: 0.133) // #161A22
    static let cwSurfaceLow = Color(red: 0.063, green: 0.075, blue: 0.102) // #10131A
    static let cwBorder = Color(red: 0.137, green: 0.165, blue: 0.212) // #232A36
    static let cwTextDim = Color(red: 0.604, green: 0.639, blue: 0.698) // #9AA3B2
    static let cwVolt = Color(red: 0.784, green: 0.961, blue: 0.259) // #C8F542
    static let cwOnVolt = Color(red: 0.039, green: 0.047, blue: 0.063) // #0A0C10
    static let cwEmber = Color(red: 1.0, green: 0.541, blue: 0.0) // #FF8A00
    static let cwDanger = Color(red: 1.0, green: 0.361, blue: 0.361) // #FF5C5C
}
