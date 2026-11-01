import XCTest

/// Screenshot tour of the real app in Light and Dark: splash, onboarding intro,
/// every tab, and the empty combat room. It is opt-in (needs SNAPSHOT_DIR, i.e.
/// TEST_RUNNER_SNAPSHOT_DIR with xcodebuild) so normal runs skip it, and it is
/// best-effort: a screen that cannot be reached is reported but does not stop
/// the rest of the tour. Launch hooks live in UITestSupport (DEBUG builds).
final class AppearanceTourUITests: XCTestCase {
    private var directory = ""

    override func setUpWithError() throws {
        continueAfterFailure = true
        guard let value = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !value.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_SNAPSHOT_DIR to capture the appearance tour.")
        }
        directory = value
        try FileManager.default.createDirectory(atPath: value, withIntermediateDirectories: true)
    }

    @MainActor
    func testTourInLightAndDark() {
        for mode in ["light", "dark"] {
            captureLaunchScreens(mode)
            tourMainTabs(mode)
        }
    }

    // MARK: - Launch screens

    @MainActor
    private func captureLaunchScreens(_ mode: String) {
        let splash = launch(mode, phase: "splash")
        settle(1.5)
        shot("\(mode)-00-splash")
        splash.terminate()

        let onboarding = launch(mode, phase: "onboarding")
        if onboarding.buttons["Continue"].waitForExistence(timeout: 20) {
            settle(1.0)
            shot("\(mode)-01-onboarding")
        } else {
            XCTFail("onboarding intro did not appear (\(mode))")
        }
        onboarding.terminate()
    }

    // MARK: - Main tabs

    @MainActor
    private func tourMainTabs(_ mode: String) {
        let app = launch(mode, phase: "main")
        guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
            XCTFail("tab bar did not appear (\(mode))")
            app.terminate()
            return
        }
        settle(1.5)
        shot("\(mode)-10-library")

        // Empty combat room (the simulator library has no photos).
        let enter = app.buttons["Enter the dungeon and start a cleanup session"]
        if enter.waitForExistence(timeout: 5) {
            enter.tap()
            settle(2.0)
            shot("\(mode)-11-combat-empty")
            let back = app.buttons["Back to Library"]
            if back.waitForExistence(timeout: 5) { back.tap() }
            settle(1.0)
        }

        for (index, name) in ["Hero", "Bestiary", "Armory"].enumerated() {
            if open(tab: name, in: app) {
                settle(1.5)
                shot("\(mode)-\(20 + index)-\(name.lowercased())")
            }
        }
        for (index, name) in ["Trophies", "Settings"].enumerated() {
            if open(tab: name, in: app) {
                settle(1.5)
                shot("\(mode)-\(30 + index)-\(name.lowercased())")
            }
        }
        app.terminate()
    }

    /// Opens a tab directly, or through "More" when iPhone folds it away.
    @MainActor
    private func open(tab name: String, in app: XCUIApplication) -> Bool {
        let direct = app.tabBars.buttons[name]
        if direct.exists {
            direct.tap()
            return true
        }
        let more = app.tabBars.buttons["More"]
        guard more.exists else {
            XCTFail("tab \(name) not found")
            return false
        }
        more.tap()
        settle(0.8)
        let row = app.staticTexts[name].firstMatch
        guard row.waitForExistence(timeout: 5) else {
            XCTFail("tab \(name) not found under More")
            return false
        }
        row.tap()
        return true
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ mode: String, phase: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestTour", "-UITestPhase", phase, "-pq.appearance", mode]
        app.launch()
        return app
    }

    private func settle(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("tour-\(name).png"))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
