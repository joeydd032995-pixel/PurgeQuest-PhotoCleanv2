import XCTest

/// Regression test for the Hero tab saying "No hero found." after the game is reset and a race
/// is chosen again.
///
/// The hero and the achievement / cosmetic / quest seeds used to be created only at app launch.
/// "Reset all PurgeQuest data" deletes them and returns to onboarding, and finishing onboarding
/// did not create them again, so the main tabs opened on an empty store. This follows that exact
/// path (Settings > Reset > onboarding > Lost Souls > Hero tab) against the in-memory store the
/// DEBUG tour mode uses (see UITestSupport), so it never touches real data.
final class OnboardingResetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testResettingAndChoosingLostSoulsStillLeavesAHero() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestTour", "-UITestPhase", "main"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 25), "tab bar did not appear")
        dismissPhotoPrompt()

        // Settings > Reset all PurgeQuest data > Reset
        openSettings(in: app)
        let reset = app.buttons["Reset all PurgeQuest data"]
        scroll(to: reset, in: app)
        reset.tap()
        let alert = app.alerts["Reset all data?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "reset confirmation did not appear")
        alert.buttons["Reset"].tap()

        // Onboarding starts over: intro > permission > race.
        let next = app.buttons["Continue"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 15), "onboarding did not restart after the reset")
        next.tap()
        XCTAssertTrue(next.isEnabled, "Continue should be enabled on the permission page once photo access is granted")
        next.tap()

        // Choose Lost Souls. Its card sits in a lazy grid, so wait for the page and scroll to it.
        XCTAssertTrue(app.staticTexts["Choose Your Race"].waitForExistence(timeout: 10), "race page did not appear")
        let lostSouls = app.buttons["onboarding.race.necromancer"]
        scroll(to: lostSouls, in: app)
        lostSouls.tap()
        attachScreenshot("1-lost-souls-selected")

        // race > class > look > tutorial, then Enter the Dungeon.
        for _ in 0..<3 {
            XCTAssertTrue(next.waitForExistence(timeout: 5), "Continue button missing")
            next.tap()
        }
        let enter = app.buttons["Enter the Dungeon"].firstMatch
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "last onboarding page did not appear")
        enter.tap()

        // The Hero tab must show the hero that was just chosen.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "main tabs did not appear after onboarding")
        let heroTab = app.tabBars.buttons["Hero"]
        XCTAssertTrue(heroTab.waitForExistence(timeout: 5), "Hero tab not found")
        heroTab.tap()

        let summary = app.staticTexts["Lost Souls · Unholy Paladin · LV 1"]
        let found = summary.waitForExistence(timeout: 10)
        attachScreenshot("2-hero-tab-after-reset")

        XCTAssertFalse(
            app.staticTexts["No hero found."].exists,
            "The Hero tab says \"No hero found.\" after resetting and choosing a race again"
        )
        XCTAssertTrue(found, "The Hero tab does not show the chosen hero. Texts on screen: \(visibleTexts(app))")
    }

    // MARK: - Helpers

    /// Opens Settings, which iPhone folds under "More".
    @MainActor
    private func openSettings(in app: XCUIApplication) {
        let direct = app.tabBars.buttons["Settings"]
        if direct.exists {
            direct.tap()
            return
        }
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Settings tab not found")
        more.tap()
        let row = app.staticTexts["Settings"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings not found under More")
        row.tap()
    }

    /// Drags the page up from its left edge (clear of the pickers, toggles and cards in the
    /// middle) until the element can be tapped.
    @MainActor
    private func scroll(to element: XCUIElement, in app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.25))
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 10 {
            from.press(forDuration: 0.05, thenDragTo: to)
            attempts += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(element) never became reachable by scrolling")
    }

    /// Taps through the system Photos prompt if it is covering the app (CI pre-grants
    /// access, so this is only a fallback on a fresh simulator).
    @MainActor
    private func dismissPhotoPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow Full Access", "Allow Access to All Photos", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
        }
    }

    @MainActor
    private func visibleTexts(_ app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex.prefix(40).map(\.label)
    }

    /// Attaches the screen to the test result and, when SNAPSHOT_DIR is set (CI), saves it for
    /// the `ui-snapshots` artifact.
    @MainActor
    private func attachScreenshot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !directory.isEmpty {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("regression-\(name).png"))
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
