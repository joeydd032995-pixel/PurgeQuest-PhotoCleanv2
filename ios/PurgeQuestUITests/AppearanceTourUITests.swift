import XCTest

/// Screenshot tour of the real app in Light and Dark: splash, onboarding intro,
/// every tab, and a combat room. It is opt-in (needs SNAPSHOT_DIR, i.e.
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

    /// The optional Verdigris palette (green-black / sage): representative screens only.
    @MainActor
    func testVerdigrisPalette() {
        for mode in ["light", "dark"] {
            let app = launch(mode, phase: "main", palette: "verdigris")
            guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
                XCTFail("tab bar did not appear (verdigris \(mode))")
                app.terminate()
                continue
            }
            dismissPhotoPrompt()
            settle(1.5)
            shot("verdigris-\(mode)-10-library")
            for name in ["Bestiary", "Armory"] {
                if open(tab: name, in: app) {
                    settle(1.5)
                    shot("verdigris-\(mode)-\(name.lowercased())")
                }
            }
            if open(tab: "Settings", in: app) {
                settle(1.5)
                shot("verdigris-\(mode)-settings")
            }
            app.terminate()
        }
    }

    /// The Dashboard's date range, switched on and being edited, in all four looks. The range is preset
    /// through the `-UITestDateScope` launch argument (UITestSupport), so the tour never has to drive the
    /// date pickers. Each look is checked on the picture: the Library row must read "Exclude ...", not
    /// "All dates", or the preset did not arrive. The clear button's size is asserted as well (at least
    /// 44 x 44 pt), which the pictures cannot guard.
    @MainActor
    func testDatesRange() {
        let range = #"{"mode":"exclude","from":{"year":2025,"month":10,"day":12}}"#
        for palette in ["classic", "verdigris"] {
            for mode in ["light", "dark"] {
                let app = launch(mode, phase: "main", palette: palette, extra: ["-UITestDateScope", range])
                guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
                    XCTFail("tab bar did not appear (dates \(palette) \(mode))")
                    app.terminate()
                    continue
                }
                dismissPhotoPrompt()
                settle(1.5)
                shot("dates-\(palette)-\(mode)-1-library")
                // The clear button must be a real tap target: 44 x 44 pt is the smallest size Apple recommends.
                let clear = app.buttons["dashboard.dates.clear"]
                if clear.exists {
                    let size = clear.frame.size
                    XCTAssertGreaterThanOrEqual(size.width, 44, "the clear button is too narrow to hit (\(palette) \(mode))")
                    XCTAssertGreaterThanOrEqual(size.height, 44, "the clear button is too short to hit (\(palette) \(mode))")
                } else {
                    XCTFail("the clear button was not found with a range on (\(palette) \(mode))")
                }
                let row = app.buttons["dashboard.dates"]
                if row.waitForExistence(timeout: 5) {
                    row.tap()
                    // 20 s, not 5: this is the first sheet a cold simulator presents, and on a slow runner 5 s was not
                    // always enough (the screen it waits on is the same one that passes on a warm run).
                    if app.buttons["dates.apply"].waitForExistence(timeout: 20) {
                        settle(1.0)
                        shot("dates-\(palette)-\(mode)-2-sheet")
                        // Pull the sheet up to its full height so the date rows and quick picks show too.
                        // Best-effort: if it does not move, this picture repeats the last one.
                        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
                        let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
                        low.press(forDuration: 0.1, thenDragTo: high)
                        settle(1.0)
                        shot("dates-\(palette)-\(mode)-3-sheet-full")
                    } else {
                        XCTFail("the Dates sheet did not open (\(palette) \(mode))")
                    }
                } else {
                    XCTFail("the Dates row was not found on the Library screen (\(palette) \(mode))")
                }
                app.terminate()
            }
        }
    }

    /// The Wraith, Forest Spirit and Phantom Purge art, which a fresh simulator never reaches. Launch
    /// hooks (UITestSupport) wear a pet, mark the Wraiths as met and pretend the event is running.
    @MainActor
    func testNewArt() {
        for mode in ["light", "dark"] {
            let app = launch(mode, phase: "main", extra: [
                "-UITestEquip", "pet.spiritBlue",
                "-UITestMet", "mistWraith,tatterWraith,voidWraith",
                "-UITestEvent", "halloween"
            ])
            guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
                XCTFail("tab bar did not appear (new art \(mode))")
                app.terminate()
                continue
            }
            dismissPhotoPrompt()
            settle(1.5)
            shot("newart-\(mode)-10-library-event")
            if open(tab: "Hero", in: app) {
                settle(1.5)
                shot("newart-\(mode)-20-hero-pet")
            }
            if open(tab: "Bestiary", in: app) {
                settle(1.5)
                captureVideoPhantoms(app, mode)
            }
            if open(tab: "Armory", in: app) {
                settle(1.5)
                capturePets(app, mode)
            }
            app.terminate()
        }
    }

    /// A Golem (the dark lava variant) wearing something in every slot. The sword is held in the hand on the right
    /// of the screen, the shield in the one on the left, and every worn slot has a tag around the plaque.
    @MainActor
    func testGearOnGolem() {
        for mode in ["light", "dark"] {
            let app = launch(mode, phase: "main", extra: [
                "-pq.race", "golem",
                "-UITestVariant", "3",
                "-UITestEquip", "skin.iron,head.iron,armor.iron,armor.golem.legs,armor.golem.hands,weapon.shard,shield.crux,fx.sparks,pet.spiritBlue"
            ])
            guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
                XCTFail("tab bar did not appear (golem gear \(mode))")
                app.terminate()
                continue
            }
            dismissPhotoPrompt()
            if open(tab: "Hero", in: app) {
                settle(2.0)
                shot("gear-\(mode)-20-golem-hero")
            }
            if open(tab: "Armory", in: app) {
                settle(1.5)
                shot("gear-\(mode)-22-armory-with-gear")
            }
            app.terminate()
        }
    }

    /// The equipped weapon has to sit in the hero's fist on every race and every kind of art pack, not just the Golem:
    /// one Hero-tab shot per pack, each wearing its own race's signature weapon and a shield, Light mode only.
    /// (The Elven archer carries the bow; the other Elven paint uses a sword.)
    @MainActor
    func testWeaponHeldAcrossRaces() {
        let heroes: [(race: String, variant: String, weapon: String)] = [
            ("valkyrie", "1", "weapon.valkyrie"),
            ("forest_ranger", "1", "weapon.forest_ranger"),
            ("forest_ranger", "3", "weapon.shard"),
            ("seer", "2", "weapon.seer"),
            ("blood_alchemist", "1", "weapon.blood_alchemist"),
            ("dark_oracle", "3", "weapon.dark_oracle"),
            ("necromancer", "2", "weapon.necromancer"),
            ("skeleton_crusader", "1", "weapon.skeleton_crusader"),
            ("skeleton_crusader", "4", "weapon.skeleton_crusader"),
            ("golem", "1", "weapon.golem")
        ]
        for hero in heroes {
            let name = "\(hero.race)-v\(hero.variant)"
            let app = launch("light", phase: "main", extra: [
                "-pq.race", hero.race,
                "-UITestVariant", hero.variant,
                "-UITestEquip", "\(hero.weapon),shield.crux"
            ])
            guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
                XCTFail("tab bar did not appear (held weapon \(name))")
                app.terminate()
                continue
            }
            dismissPhotoPrompt()
            if open(tab: "Hero", in: app) {
                settle(1.5)
                shot("held-\(name)")
            }
            app.terminate()
        }
    }

    /// Opens the Video Phantoms family and scrolls through it, where the three Wraiths live.
    @MainActor
    private func captureVideoPhantoms(_ app: XCUIApplication, _ mode: String) {
        let tile = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Video Phantoms"))
            .firstMatch
        guard tile.waitForExistence(timeout: 5) else {
            XCTFail("Video Phantoms tile not found (\(mode))")
            return
        }
        tile.tap()
        settle(1.5)
        for step in 0..<3 {
            shot("newart-\(mode)-21-video-phantoms-\(step)")
            app.swipeUp()
            settle(1.0)
        }
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        settle(1.0)
    }

    /// Filters the Armory to Pets (the chip bar scrolls sideways) and shows the new sprites.
    @MainActor
    private func capturePets(_ app: XCUIApplication, _ mode: String) {
        let chip = app.buttons["Pets"]
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.21))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.21))
        for _ in 0..<6 where !(chip.exists && chip.isHittable) {
            from.press(forDuration: 0.1, thenDragTo: to)
            settle(0.5)
        }
        guard chip.exists && chip.isHittable else {
            XCTFail("Pets filter not reachable in the Armory (\(mode))")
            return
        }
        chip.tap()
        settle(1.5)
        shot("newart-\(mode)-22-armory-pets-0")
        app.swipeUp()
        settle(1.0)
        shot("newart-\(mode)-22-armory-pets-1")
    }

    /// Flips the palette from inside Settings, as a player would, and captures the
    /// repaint (the earlier tests launch with a saved palette instead).
    @MainActor
    func testSwitchingPaletteLive() {
        // No palette launch argument here (see `launch`): the picker's own writes must win.
        let app = launch("dark", phase: "main", palette: nil)
        guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
            XCTFail("tab bar did not appear (live switch)")
            app.terminate()
            return
        }
        dismissPhotoPrompt()
        guard open(tab: "Settings", in: app) else {
            app.terminate()
            return
        }
        settle(1.0)
        tapPalette("Classic", in: app)   // start from a known palette whatever earlier runs left behind
        shot("live-1-classic-settings")

        tapPalette("Verdigris", in: app)
        // The change repaints in place: Settings stays open and shows the new summary.
        XCTAssertTrue(
            app.staticTexts["Green-black in Dark, pale sage in Light."].waitForExistence(timeout: 5),
            "Settings should stay open, showing the Verdigris summary, after a palette change"
        )
        shot("live-2-after-verdigris")
        if open(tab: "Armory", in: app) {
            settle(1.5)
            shot("live-3-armory-verdigris")
        }
        if open(tab: "Settings", in: app) {
            settle(1.0)
            tapPalette("Classic", in: app)
            XCTAssertTrue(
                app.staticTexts["Charcoal in Dark, parchment in Light."].waitForExistence(timeout: 5),
                "Settings should stay open, showing the Classic summary, after switching back"
            )
            shot("live-4-back-to-classic")
        }
        app.terminate()
    }

    @MainActor
    private func tapPalette(_ name: String, in app: XCUIApplication) {
        let segment = app.buttons[name]
        guard segment.waitForExistence(timeout: 5) else {
            XCTFail("palette segment \(name) not found")
            return
        }
        segment.tap()
        settle(2.0)
    }

    /// Two screens the main tour never reaches: the duplicate card and the Room Summary. It plays one real room
    /// (every card marked for deletion) and stops on the summary without confirming, so nothing is deleted. The
    /// name starts with Z so it runs last: it is the one test that asks the app questions after a dive has
    /// started, which the main tour avoids (see the note above its combat step). It is best-effort: a screen it
    /// cannot reach is reported as a note, not a failure, so it can never fail the tour.
    @MainActor
    func testZRoomSummaryAndDuplicateCard() {
        for mode in ["dark", "light"] { captureRoomSummary(mode) }
    }

    @MainActor
    private func captureRoomSummary(_ mode: String) {
        let app = launch(mode, phase: "main")
        guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
            note("room summary (\(mode)): the tab bar did not appear")
            app.terminate()
            return
        }
        dismissPhotoPrompt()
        settle(1.5)
        let enter = app.buttons["Enter the dungeon and start a cleanup session"]
        guard enter.waitForExistence(timeout: 10) else {
            note("room summary (\(mode)): the Enter button was not found")
            app.terminate()
            return
        }
        enter.tap()
        dismissPhotoPrompt()
        // The scan: a plain sleep, nothing asks the app anything until it has finished.
        settle(25.0)

        let summaryTitle = app.staticTexts["Review this room"]
        let confirmGroup = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Confirm'")).firstMatch
        let delete = app.buttons["Delete"]
        let keep = app.buttons["Keep"]
        var shotDuplicate = false
        var shotCoach = false
        var shotPill = false
        // The first card: the swipe arrows, and the size of the two decision buttons, measured on the device.
        if delete.waitForExistence(timeout: 10), keep.exists {
            settle(0.6)
            shot("\(mode)-11a-coach-mark")
            shotCoach = true
            let d = delete.frame, k = keep.frame
            note("measure (\(mode)): Delete \(Int(d.width))x\(Int(d.height)) pt, Keep \(Int(k.width))x\(Int(k.height)) pt, "
                 + "screen \(Int(app.frame.width))x\(Int(app.frame.height)) pt, "
                 + "both on screen: \(app.frame.contains(d) && app.frame.contains(k))")
        } else {
            note("room summary (\(mode)): the first card was not a single card, so no coach mark shot")
        }
        // A hard budget, so a screen that stops answering can never run the job out of time.
        let deadline = Date().addingTimeInterval(180)
        for _ in 0..<40 where Date() < deadline {
            if summaryTitle.exists { break }
            if confirmGroup.exists {
                // A duplicate group resolves through its own per-copy controls instead of DELETE and KEEP.
                if !shotDuplicate {
                    settle(0.8)
                    shot("\(mode)-13-duplicate-card")
                    shotDuplicate = true
                }
                confirmGroup.tap()
            } else if delete.exists {
                delete.tap()
                // The Undo pill is up for five seconds after a decision: shoot it, and measure it against the buttons.
                if !shotPill {
                    let pill = app.buttons["Undo delete"]
                    if pill.waitForExistence(timeout: 2) {
                        shot("\(mode)-12-undo-pill")
                        shotPill = true
                        let p = pill.frame
                        // Measure against whichever decision controls are on screen now. After a delete the next card can
                        // be a duplicate group, which has per-copy buttons and no "Delete" or "Keep" (or the room can have
                        // ended). A control that is not there is skipped: asking an absent element for its frame fails the
                        // test, and this test must only ever report.
                        var covered: [String] = []
                        for name in ["Delete", "Keep", "Mark this copy for deletion", "Keep this copy"] {
                            let control = app.buttons[name]
                            if control.exists, p.intersects(control.frame) { covered.append(name) }
                        }
                        note("measure (\(mode)): Undo pill \(Int(p.width))x\(Int(p.height)) pt at y \(Int(p.minY)), "
                             + "covers: \(covered.isEmpty ? "no decision button" : covered.joined(separator: ", "))")
                    }
                }
            } else {
                settle(1.0)
            }
            settle(0.9)
        }
        if summaryTitle.waitForExistence(timeout: 10) {
            settle(1.0)
            shot("\(mode)-14-room-summary")
        } else {
            note("room summary (\(mode)): never reached the Room Summary")
        }
        if !shotDuplicate { note("room summary (\(mode)): no duplicate group came up in this room") }
        if !shotCoach || !shotPill { note("room summary (\(mode)): coach mark shot \(shotCoach), undo pill shot \(shotPill)") }
        app.terminate()
    }

    /// The card caught mid-drag, short of the commit line and past it, toward Delete and toward Keep. The app draws the
    /// pose itself (`-UITestCardPose`), because a UI test cannot hold a finger down and take a screenshot at once.
    /// Best-effort, like the Room Summary test: a pose that does not come up is a note, not a failure. The name starts
    /// with Z so it runs last.
    @MainActor
    func testZCardDragPoses() {
        let poses: [(name: String, value: String)] = [
            ("left-half", "L55"), ("left-armed", "L125"), ("right-half", "R55"), ("right-armed", "R125")
        ]
        for mode in ["dark", "light"] {
            for pose in poses {
                captureFirstCard(mode, label: "card pose \(pose.name)", shotName: "\(mode)-15-card-\(pose.name)",
                                 extra: ["-UITestCardPose", pose.value])
            }
        }
    }

    /// Each family's skin on the first card, in Light and Dark. The first card of a dive is whatever the room dealt, so
    /// the app is told which skin to wear (`-UITestFamily`). Best-effort, and last, like the poses.
    @MainActor
    func testZFamilySkins() {
        let families = ["dragons", "undead", "relics", "behemoths", "phantoms", "glitch"]
        for mode in ["dark", "light"] {
            for family in families {
                captureFirstCard(mode, label: "family skin \(family)", shotName: "\(mode)-16-skin-\(family)",
                                 extra: ["-UITestFamily", family])
            }
        }
    }

    /// Launches, enters the dungeon, waits out the scan with a plain sleep and shoots the first card. Nothing asks the
    /// app anything while it scans: a scanning app can stop answering accessibility queries.
    @MainActor
    private func captureFirstCard(_ mode: String, label: String, shotName: String, extra: [String]) {
        let app = launch(mode, phase: "main", extra: extra)
        guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
            note("\(label) (\(mode)): the tab bar did not appear")
            app.terminate()
            return
        }
        dismissPhotoPrompt()
        settle(1.5)
        let enter = app.buttons["Enter the dungeon and start a cleanup session"]
        guard enter.waitForExistence(timeout: 10) else {
            note("\(label) (\(mode)): the Enter button was not found")
            app.terminate()
            return
        }
        enter.tap()
        dismissPhotoPrompt()
        settle(25.0)
        shot(shotName)
        app.terminate()
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
        dismissPhotoPrompt()
        requireLibraryPhotos(in: app, mode)
        settle(1.5)
        shot("\(mode)-10-library")
        app.swipeUp()
        settle(1.0)
        shot("\(mode)-12-library-scrolled")

        for (index, name) in ["Hero", "Bestiary", "Armory"].enumerated() {
            if open(tab: name, in: app) {
                settle(1.5)
                shot("\(mode)-\(20 + index)-\(name.lowercased())")
                if name == "Hero" { captureForge(app, mode) }
            }
        }
        for (index, name) in ["Trophies", "Settings"].enumerated() {
            if open(tab: name, in: app) {
                settle(1.5)
                shot("\(mode)-\(30 + index)-\(name.lowercased())")
            }
        }

        // Combat goes last, and nothing asks the app anything after it. While a dive scans a real photo
        // library the app can stop answering accessibility queries for a long time, and every query that
        // times out fails the test, so everything above must not depend on it. Return to the Library, go in,
        // wait with a plain sleep, take the picture, and end the app without asking it anything.
        if open(tab: "Library", in: app) {
            settle(1.0)
            app.swipeDown()
            settle(0.5)
            let enter = app.buttons["Enter the dungeon and start a cleanup session"]
            if enter.waitForExistence(timeout: 5) {
                enter.tap()
                dismissPhotoPrompt()
                settle(20.0)
                shot("\(mode)-11-combat")
            }
        }
        app.terminate()
    }

    /// The Hero Forge (largest custom screen, force-dark until Light mode landed).
    @MainActor
    private func captureForge(_ app: XCUIApplication, _ mode: String) {
        // The button carries its own accessibility label, not its visible title.
        let forge = app.buttons["Open the hero forge to customize your hero's look"]
        guard forge.waitForExistence(timeout: 5) else {
            XCTFail("Forge button not found on the Hero tab (\(mode))")
            return
        }
        forge.tap()
        settle(2.0)
        shot("\(mode)-23-forge")
        let cancel = app.buttons["Cancel editing without saving"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() }
        settle(1.0)
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

    /// Taps through the system Photos prompt if it is covering the app (CI pre-grants
    /// access, so this is only a fallback on a fresh simulator).
    @MainActor
    private func dismissPhotoPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow Full Access", "Allow Access to All Photos", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                settle(1.0)
                return
            }
        }
    }

    @MainActor
    /// `palette: nil` leaves the palette setting alone. Launch arguments sit in a defaults
    /// layer that shadows anything the Settings picker writes, so a test that taps the
    /// picker must not pass one.
    private func launch(_ mode: String, phase: String, palette: String? = "classic", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestTour", "-UITestPhase", phase, "-pq.appearance", mode] + extra
        if let palette { app.launchArguments += ["-pq.colorTheme", palette] }
        app.launch()
        return app
    }

    /// The Library must show photos before the first screenshot. A run whose simulator library is empty (the
    /// sample pictures are added with `simctl addmedia`, which can run before Photos is ready on a slow boot)
    /// would photograph an empty Library and an "All clear" dive, so it says so plainly and early instead.
    @MainActor
    private func requireLibraryPhotos(in app: XCUIApplication, _ mode: String) {
        let withPhotos = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", ".*[1-9][0-9]* photos.*")).firstMatch
        if !withPhotos.waitForExistence(timeout: 30) {
            XCTFail("The simulator photo library is empty (\(mode)): the Library never showed any photos. The sample pictures were probably added before Photos was ready, so re-run the job.")
        }
    }

    /// A message for the tour's output that does not fail the test.
    private func note(_ message: String) {
        print("tour note: \(message)")
        let attachment = XCTAttachment(string: message)
        attachment.lifetime = .keepAlways
        add(attachment)
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
