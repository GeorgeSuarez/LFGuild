import XCTest

final class LFGuildUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()

        // Explicitly set the detection flag before setupSnapshot and launch.
        // This is a belt-and-suspenders approach: setupSnapshot also adds
        // -FASTLANE_SNAPSHOT via SnapshotHelper, but we set -UITesting directly
        // so it works regardless of SnapshotHelper's internal state.
        app.launchArguments += ["-UITesting"]
        app.launchEnvironment["UITESTING"] = "1"

        setupSnapshot(app)
        app.launch()

        let tabBar = app.tabBars.firstMatch
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: tabBar, handler: nil)
        waitForExpectations(timeout: 15)

        let tabs: [(name: String, tabLabel: String)] = [
            ("01Home", "Home"),
            ("02Search", "Search"),
            ("03Messages", "Messages"),
            ("04Profile", "Profile"),
        ]

        for (name, tabLabel) in tabs {
            let tabButton = tabBar.buttons[tabLabel]
            if tabButton.exists {
                tabButton.tap()
                sleep(2)
            }
            snapshot(name)
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
