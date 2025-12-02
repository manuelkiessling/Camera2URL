//
//  camera2urlUITests.swift
//  camera2urlUITests
//

import XCTest

final class camera2urlUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here.
    }

    @MainActor
    func testExample() throws {
        throw XCTSkip("UI automation not implemented yet; tracked for future work.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        throw XCTSkip("Launch performance measurements run only in Xcode for now.")
    }
}

