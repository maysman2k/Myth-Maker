import XCTest
@testable import BusPulse

final class DeepLinkParserTests: XCTestCase {

    func testParsesBusShareToRoute() {
        let url = URL(string: "https://waitless.bricksinabag.com/share?type=bus&line=X7&service=42&to=Newcastle")!
        XCTAssertEqual(DeepLinkParser.parse(url),
                       .route(serviceID: 42, line: "X7", description: "Newcastle"))
    }

    func testParsesCustomSchemeRoute() {
        let url = URL(string: "waitless://share?type=route&line=62&service=7")!
        XCTAssertEqual(DeepLinkParser.parse(url),
                       .route(serviceID: 7, line: "62", description: ""))
    }

    func testParsesStopShare() {
        let url = URL(string: "https://waitless.bricksinabag.com/share?type=stop&atco=SCNE-10647&name=Killingworth")!
        XCTAssertEqual(DeepLinkParser.parse(url), .stop(atco: "SCNE-10647", name: "Killingworth"))
    }

    func testRejectsNonShareLinks() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "https://waitless.bricksinabag.com/health")!))
        XCTAssertNil(DeepLinkParser.parse(URL(string: "https://example.com/share?type=bus&service=1")!.deletingLastPathComponent()))
    }

    func testRejectsRouteWithoutService() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "waitless://share?type=bus&line=X7")!))
    }
}
