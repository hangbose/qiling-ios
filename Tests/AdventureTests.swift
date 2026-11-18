import XCTest
@testable import Qiling

final class AdventureTests: XCTestCase {
    func member(_ id: String, _ points: Int) -> SquadMember {
        SquadMember(id: id, name: id, points: points, xp: points, cheers: 0, updated: Date())
    }
    func testSingleMemberCannotCompleteRouteByGrinding() {
        let route = ExpeditionProgress(members: [member("a", 10000)])
        XCTAssertEqual(route.total, 700)
        XCTAssertFalse(route.finished)
    }
    func testDuplicateMemberDoesNotCountTwice() {
        XCTAssertEqual(ExpeditionProgress(members: [member("a", 700), member("a", 600)]).total, 700)
    }
    func testTwoMembersCompleteAndNegativePointsAreIgnored() {
        XCTAssertTrue(ExpeditionProgress(members: [member("a", 700), member("b", 700)]).finished)
        XCTAssertEqual(ExpeditionProgress(members: [member("a", -20)]).total, 0)
    }
    func testNewCompanionGrowthBoundaries() {
        for (xp, phase) in [(0,0), (49,0), (50,1), (299,1), (300,2), (999,2), (1000,3)] {
            XCTAssertEqual(CompanionKind.phase(xp), phase)
        }
    }
    func testOldSaveDecodesWithoutNewFields() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(SavedState())) as? [String: Any])
        object.removeValue(forKey: "companion")
        object.removeValue(forKey: "expeditionMemories")
        let restored = try JSONDecoder().decode(SavedState.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.companion)
        XCTAssertNil(restored.expeditionMemories)
        XCTAssertEqual(restored.petName, "星澜")
    }
}
