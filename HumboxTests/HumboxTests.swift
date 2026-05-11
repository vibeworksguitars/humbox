import XCTest
@testable import Humbox

final class HumboxTests: XCTestCase {
    func testMemoFormattedDuration() {
        let memo = Memo(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 95,
                        title: "Test", contentType: .guitar)
        XCTAssertEqual(memo.formattedDuration, "1:35")
    }

    func testMemoMetaSummary() {
        let memo = Memo(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 18,
                        title: "Test", key: "Dm", bpm: 92, contentType: .guitar)
        XCTAssertTrue(memo.metaSummary.contains("Dm"))
        XCTAssertTrue(memo.metaSummary.contains("92 BPM"))
        XCTAssertTrue(memo.metaSummary.contains("guitar"))
    }
}
