import XCTest

final class DeckUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure=false }
    func keys(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","session-key-"))
    }
    func capture(_ name: String,_ app: XCUIApplication) {
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func test01AdaptiveKeysAndHide() {
        let app=XCUIApplication()
        for count in 1...3 {
            app.launchEnvironment=["CODEX_DECK_DEMO_COUNT":String(count)]
            XCUIDevice.shared.orientation = .portrait
            app.launch()
            XCTAssertTrue(keys(app).firstMatch.waitForExistence(timeout:10))
            XCTAssertEqual(keys(app).count,count)
            for key in keys(app).allElementsBoundByIndex {XCTAssertTrue(app.frame.contains(key.frame),"Every session key must fit on screen")}
            capture("iPhone-portrait-\(count)-sessions",app)
            if count==3 {
                app.buttons["hide-session-3"].tap()
                XCTAssertEqual(keys(app).count,2)
                capture("iPhone-after-hide",app)
            }
            app.terminate()
        }
        app.launchEnvironment=["CODEX_DECK_DEMO_COUNT":"3"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(keys(app).firstMatch.waitForExistence(timeout:10))
        XCTAssertEqual(keys(app).count,3)
        capture("iPhone-landscape-3-sessions",app)
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }
    func test02LiveConnectionAndFocus() throws {
        let app=XCUIApplication();app.launchEnvironment=[:];app.launch()
        // Pair on this device before running this test; never embed tokens in sources.
        let alert=XCUIApplication(bundleIdentifier:"com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout:3) {
            let text=alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator:" ").lowercased()
            if text.contains("local network") || text.contains("本地网络") || text.contains("區域網路") {
                for title in ["Allow","允许","允許"] where alert.buttons[title].exists {alert.buttons[title].tap();break}
            }
        }
        let status=app.staticTexts["connection-status"]
        let connected=NSPredicate(format:"label CONTAINS %@","Mac 已连接")
        expectation(for:connected,evaluatedWith:status)
        waitForExpectations(timeout:20)
        XCTAssertTrue(keys(app).firstMatch.waitForExistence(timeout:10))
        XCTAssertTrue(keys(app).firstMatch.isEnabled)
        XCTAssertFalse(keys(app).allElementsBoundByIndex.contains { $0.label.contains("Files mentioned by the user") })
        capture("iPhone-live-Codex",app)
        keys(app).firstMatch.tap()
        let focused=NSPredicate(format:"label CONTAINS %@","已发送到 Mac")
        expectation(for:focused,evaluatedWith:status)
        waitForExpectations(timeout:5)
        capture("iPhone-focus-sent",app)
    }
    func test03SettingsAndRelaunch() {
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(keys(app).firstMatch.waitForExistence(timeout:20))
        let names=keys(app).allElementsBoundByIndex.map(\.identifier)
        app.buttons["deck-settings"].tap()
        XCTAssertTrue(app.buttons["scan-pairing"].waitForExistence(timeout:5))
        XCTAssertTrue(app.navigationBars["我的键盘"].exists)
        capture("iPhone-settings",app)
        app.buttons["完成"].tap()
        app.terminate();app.launch()
        XCTAssertTrue(keys(app).firstMatch.waitForExistence(timeout:10))
        XCTAssertEqual(keys(app).allElementsBoundByIndex.map(\.identifier),names)
    }

    // The host test driver stops and restarts only the Deck companion during this case.
    func test04DisconnectRecovery() {
        let app=XCUIApplication();app.launch()
        let status=app.staticTexts["connection-status"]
        expectation(for:NSPredicate(format:"label CONTAINS %@","Mac 已连接"),evaluatedWith:status)
        waitForExpectations(timeout:20)
        let names=keys(app).allElementsBoundByIndex.map(\.label)
        print("DECK_READY_FOR_OUTAGE")
        expectation(for:NSPredicate(format:"label CONTAINS %@","重新连接"),evaluatedWith:status)
        waitForExpectations(timeout:30)
        XCTAssertEqual(keys(app).allElementsBoundByIndex.map(\.label),names)
        XCTAssertFalse(keys(app).firstMatch.isEnabled)
        capture("iPhone-reconnecting",app)
        expectation(for:NSPredicate(format:"label CONTAINS %@","Mac 已连接"),evaluatedWith:status)
        waitForExpectations(timeout:35)
        XCTAssertTrue(keys(app).firstMatch.isEnabled)
        capture("iPhone-recovered",app)
    }

    func test05KeepAwakeToggle() {
        let app=XCUIApplication();app.launch()
        let sun=app.buttons["keep-awake"]
        XCTAssertTrue(sun.waitForExistence(timeout:10))
        if sun.value as? String == "关闭" {sun.tap()}
        XCTAssertEqual(sun.value as? String,"开启")
        sun.tap()
        XCTAssertEqual(sun.value as? String,"关闭")
        XCTAssertTrue(app.staticTexts["connection-status"].label.contains("常亮已关闭"))
        app.terminate();app.launch()
        XCTAssertTrue(sun.waitForExistence(timeout:10))
        XCTAssertEqual(sun.value as? String,"关闭")
        sun.tap()
        XCTAssertEqual(sun.value as? String,"开启")
        capture("iPhone-keep-awake-enabled",app)
    }

}
