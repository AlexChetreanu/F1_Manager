import XCTest
@testable import F1App

final class NewsServiceTests: XCTestCase {
    private final class URLProtocolMock: URLProtocol {
        static var testURLs = [URL?: Data]()
        static var lastRequest: URLRequest?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.lastRequest = request
            if let url = request.url, let data = Self.testURLs[url] {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    func testFetchF1NewsBuildsProperRequestAndDecodes() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: config)
        let service = NewsService(session: session)
        let json = """
        [
          {"id":"1","title":"Title","link":"https://example.com","published_at":"2025-08-20T12:00:00Z","image_url":null,"source":"Autosport","excerpt":"A"}
        ]
        """.data(using: .utf8)!
        var comps = URLComponents(string: APIConfig.baseURL)!
        comps.path = "/api/news/f1"
        comps.queryItems = [
            URLQueryItem(name: "year", value: "2025"),
            URLQueryItem(name: "limit", value: "2")
        ]
        URLProtocolMock.testURLs = [comps.url!: json]

        // Execute
        let result = try await service.fetchF1News(year: 2025, limit: 2)

        // Verify
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Title")
        XCTAssertEqual(URLProtocolMock.lastRequest?.url?.query, "year=2025&limit=2")
    }
}
