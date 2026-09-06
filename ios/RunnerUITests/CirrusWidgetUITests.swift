import XCTest

/// Drives the SIMULATOR'S HOME SCREEN for the Cirrus widget — the half of the
/// widget loop no Flutter test can reach, because adding a widget, tapping it
/// and killing the app in between all happen in Springboard, outside the
/// app's process. The Android equivalent is the hand loop in docs/10 §23.
///
/// Preconditions (the Mac side sets these up; see ios/CirrusWidget/README.md):
///  * the app is installed and SIGNED IN with a journey — use
///    `integration_test/j_widget_session_test.dart` for that;
///  * an iOS 17+ simulator is booted (interactive widgets), on its first home
///    page.
///
/// Each method stands alone so the Mac-side script can interleave them with
/// its own checks of the App Group plist:
///
///   xcodebuild test-without-building -workspace ios/Runner.xcworkspace \
///     -scheme RunnerUITests -destination "platform=iOS Simulator,id=<udid>" \
///     -only-testing:RunnerUITests/CirrusWidgetUITests/testAddWidget
///
/// Springboard's labels are Apple's and change between iOS versions; every
/// lookup here tolerates the iOS 17 and iOS 18 spellings and fails with the
/// accessibility tree in the message so the next spelling is a one-line fix.
final class CirrusWidgetUITests: XCTestCase {

    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Steps

    /// Long-press → Edit/+ → search "Cirrus" → Add Widget → Done.
    func testAddWidget() throws {
        goHome()
        // Already there from an earlier run? Then nothing to do.
        if findWidgetPage() { return }

        enterJiggleMode()

        let addWidget = containing(springboard.buttons, "Add Widget")
        if !addWidget.waitForExistence(timeout: 3) {
            // iOS 18: an "Edit" button top-left opens a menu holding "Add Widget".
            let edit = springboard.buttons["Edit"]
            XCTAssertTrue(edit.waitForExistence(timeout: 5), "no Add Widget and no Edit button:\n\(tree())")
            edit.tap()
            let item = containing(springboard.buttons, "Add Widget")
            XCTAssertTrue(item.waitForExistence(timeout: 5), "no Add Widget in the Edit menu:\n\(tree())")
            item.tap()
        } else {
            addWidget.tap()
        }

        // Springboard has other search fields (the App Library's sits
        // off-screen), so pick the gallery's by its placeholder.
        let search = springboard.searchFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'widget'")
        ).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "no widget gallery search field:\n\(tree())")
        search.tap()
        search.typeText("Cirrus")

        let row = galleryRow()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Cirrus is not in the widget gallery:\n\(tree())")
        row.tap()

        // iOS 18 labels it " Add Widget" — the SF symbol is a leading space.
        let add = containing(springboard.buttons, "Add Widget")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "no Add Widget on the size page:\n\(tree())")
        add.tap()

        let done = springboard.buttons["Done"]
        if done.waitForExistence(timeout: 5) { done.tap() }

        goHome()
        XCTAssertTrue(findWidgetPage(), "the widget's + never appeared:\n\(tree())")
    }

    /// Kill the app: the taps that follow must be logged with no Flutter
    /// process alive, which is the whole feature.
    func testTerminateApp() {
        app.terminate()
        goHome()
    }

    func testTapPlus() {
        goHome()
        XCTAssertTrue(findWidgetPage(), "no + on any home page:\n\(tree())")
        plusButton.tap()
        sleep(2)
    }

    func testTapMinus() {
        goHome()
        XCTAssertTrue(findWidgetPage(), "no − on any home page:\n\(tree())")
        minusButton.tap()
        sleep(2)
    }

    /// Foreground the app so `_WidgetSync` drains the outbox.
    func testLaunchApp() {
        app.launch()
        sleep(8)
    }

    /// The medium family: same gallery flow, second page of the size picker.
    func testAddMediumWidget() throws {
        goHome()
        enterJiggleMode()
        let addWidget = containing(springboard.buttons, "Add Widget")
        if !addWidget.waitForExistence(timeout: 3) {
            let edit = springboard.buttons["Edit"]
            XCTAssertTrue(edit.waitForExistence(timeout: 5), "no Edit button:\n\(tree())")
            edit.tap()
            let item = containing(springboard.buttons, "Add Widget")
            XCTAssertTrue(item.waitForExistence(timeout: 5), "no Add Widget in the Edit menu:\n\(tree())")
            item.tap()
        } else {
            addWidget.tap()
        }
        let search = springboard.searchFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'widget'")
        ).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "no gallery search field:\n\(tree())")
        search.tap()
        search.typeText("Cirrus")
        let row = galleryRow()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Cirrus is not in the gallery:\n\(tree())")
        row.tap()
        let add = containing(springboard.buttons, "Add Widget")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "no Add Widget on the size page:\n\(tree())")
        // Page two of the size picker is systemMedium.
        springboard.swipeLeft()
        sleep(1)
        add.tap()
        let done = springboard.buttons["Done"]
        if done.waitForExistence(timeout: 5) { done.tap() }
    }

    /// Page two of the home screen, where Springboard put the widget — for a
    /// screenshot of a widget that has no `+` to page towards (the empty card).
    func testShowSecondPage() {
        goHome()
        springboard.swipeLeft()
        sleep(2)
    }

    /// The widget's own words, for the Mac side to compare with the plist.
    func testDumpWidget() {
        goHome()
        _ = findWidgetPage()
        NSLog("CIRRUS-WIDGET-TREE-BEGIN\n\(tree())\nCIRRUS-WIDGET-TREE-END")
    }

    // MARK: - Helpers

    private var plusButton: XCUIElement {
        first(springboard.buttons, ["Log a puff", "+"])
    }

    private var minusButton: XCUIElement {
        first(springboard.buttons, ["Remove a puff", "−", "-"])
    }

    /// Springboard puts a new widget on whichever page has room — often the
    /// one holding the app's icon, not page one. Pages left until it shows.
    @discardableResult
    private func findWidgetPage() -> Bool {
        for _ in 0..<4 {
            if plusButton.waitForExistence(timeout: 2) { return true }
            springboard.swipeLeft()
            sleep(1)
        }
        return false
    }

    private func goHome() {
        XCUIDevice.shared.press(.home)
        springboard.activate()
        // Twice, so a folder, a search or a second page all fall back to page one.
        XCUIDevice.shared.press(.home)
        sleep(1)
    }

    private func enterJiggleMode() {
        // An empty patch of the first page: below the icons, above the dock.
        let spot = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        spot.press(forDuration: 2.0)
        sleep(1)
        // On some builds the long press opens a context menu instead.
        let editMenu = springboard.buttons["Edit Home Screen"]
        if editMenu.waitForExistence(timeout: 1) { editMenu.tap() }
    }

    /// The app's row in the widget gallery. Not the app's home-screen icon,
    /// which sits behind the sheet with the same label and a zero frame.
    private func galleryRow() -> XCUIElement {
        springboard.descendants(matching: .any).matching(
            NSPredicate(
                format: "label == 'Cirrus' AND elementType != %d",
                XCUIElement.ElementType.icon.rawValue
            )
        ).firstMatch
    }

    private func first(_ query: XCUIElementQuery, _ labels: [String]) -> XCUIElement {
        let predicate = NSPredicate(format: "label IN %@ OR identifier IN %@", labels, labels)
        return query.matching(predicate).firstMatch
    }

    private func containing(_ query: XCUIElementQuery, _ text: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func tree() -> String {
        springboard.debugDescription
    }
}
