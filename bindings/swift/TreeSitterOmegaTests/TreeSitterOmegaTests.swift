import XCTest
import SwiftTreeSitter
import TreeSitterOmega

final class TreeSitterOmegaTests: XCTestCase {
    func testCanLoadGrammar() throws {
        let parser = Parser()
        let language = Language(language: tree_sitter_omega())
        XCTAssertNoThrow(try parser.setLanguage(language),
                         "Error loading Omega grammar")
    }
}
