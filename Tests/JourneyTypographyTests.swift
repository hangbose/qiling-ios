import CoreText
import UIKit
import XCTest
@testable import Qiling

final class JourneyTypographyTests: XCTestCase {
    func testRegisteredJournalFontContainsEveryCoverAndDistrictTitle() throws {
        let registered = try XCTUnwrap(UIFont(name: "QilingJournal", size: 30))
        let face = CTFontCreateWithName(registered.fontName as CFString, 30, nil)
        let headings = ["伙伴营地", "小队邮局", "成长手帐", "旅行护照", "今日贡献", "校园足迹", "深大 · 精灵领地"]
        for heading in headings + BayDistrict.all.map(\.title) {
            let characters = Array(heading.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            XCTAssertTrue(CTFontGetGlyphsForCharacters(face, characters, &glyphs, characters.count), heading)
        }
    }
}
