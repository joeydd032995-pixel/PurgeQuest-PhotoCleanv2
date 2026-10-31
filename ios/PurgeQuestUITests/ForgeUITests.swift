import XCTest

/// Forge flows against the DEBUG `ForgeUITestRoot` (in-memory store, seeded hero and owned gear).
final class ForgeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(failSave: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestForge"] + (failSave ? ["-UITestFailSave"] : [])
        app.launch()
        return app
    }

    private func openGear(_ app: XCUIApplication) {
        let gear = app.buttons["Gear options"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "Forge did not appear")
        gear.tap()
    }

    private func summary(_ app: XCUIApplication) -> String {
        let label = app.staticTexts["forge.summary"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        return label.label
    }

    @MainActor
    func testGearEditsStayInTheDraftUntilSaveAndCancelDiscards() throws {
        let app = launch()
        openGear(app)
        let staff = app.buttons["Ashen Bough I"]
        XCTAssertTrue(staff.waitForExistence(timeout: 5))
        staff.tap()
        app.buttons["Cancel editing without saving"].tap()
        XCTAssertTrue(summary(app).contains("weapon=weapon.shard"), "Cancel must discard the equipment draft: \(summary(app))")

        app.buttons["forge.open"].tap()
        openGear(app)
        app.buttons["Ashen Bough I"].tap()
        let save = app.buttons["Save Hero"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(summary(app).contains("weapon=weapon.staff.1.1"), "Save must persist the equipment: \(summary(app))")
    }

    @MainActor
    func testSaveFailureIsSurfacedAndNothingIsApplied() throws {
        let app = launch(failSave: true)
        openGear(app)
        app.buttons["Ashen Bough I"].tap()
        app.buttons["Save Hero"].tap()

        let alert = app.alerts["Couldn't save your hero"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "A failed save must not look like success")
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Save Hero"].exists, "The Forge must stay open after a failed save")

        app.buttons["Cancel editing without saving"].tap()
        XCTAssertTrue(summary(app).contains("weapon=weapon.shard"), "Rollback must restore the previous equipment: \(summary(app))")
    }

    @MainActor
    func testUnownedGearIsNeverOffered() throws {
        let app = launch()
        openGear(app)
        XCTAssertTrue(app.buttons["Ashen Bough I"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Ashen Bough II"].exists, "Only owned gear may be offered")
    }
}
