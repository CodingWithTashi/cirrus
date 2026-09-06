import AppIntents
import WidgetKit

/// One tap, one puff, without opening Cirrus.
///
/// iOS 17+ only — interactive widgets did not exist before it. The iOS 16
/// fallback is a `widgetURL` deep link that opens the app, which is honest:
/// a control that looks interactive and silently does nothing is the failure
/// this codebase has already named once.
///
/// `openAppWhenRun = false` is the whole point.
@available(iOS 17.0, *)
struct LogPuffIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a puff"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "delta")
    var delta: Int

    init() {}

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        CirrusOutbox.append(delta: delta)
        WidgetCenter.shared.reloadTimelines(ofKind: CirrusKeys.kind)
        return .result()
    }
}
