import XCTest
@testable import MalayMateCore

final class PackageSmokeTests: XCTestCase {
    func testCoreTargetIsImportable() {
        XCTAssertEqual(PackageAnchor.name, "MalayMateCore")
    }
}
