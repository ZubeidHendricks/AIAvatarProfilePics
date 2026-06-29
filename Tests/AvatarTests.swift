import XCTest
import UIKit
// AvatarService.swift compiled into this test target.

final class AvatarTests: XCTestCase {
    private func image(_ s: CGFloat = 400) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: f).image { c in
            UIColor.systemIndigo.setFill(); c.fill(CGRect(x: 0, y: 0, width: s, height: s))
        }
    }

    func testStyleCatalog() {
        XCTAssertGreaterThanOrEqual(AvatarStyle.all.count, 4)
    }

    func testGenerateProducesImageForEachStyle() async throws {
        for style in AvatarStyle.all {
            let out = try await OnDeviceAvatarService().generate(from: image(), style: style)
            XCTAssertNotNil(out.cgImage, "no output for \(style.id)")
        }
    }
}
