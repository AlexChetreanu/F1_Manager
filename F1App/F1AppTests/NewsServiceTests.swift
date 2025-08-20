import XCTest
@testable import F1App

final class NewsServiceTests: XCTestCase {
    private final class URLProtocolStub: URLProtocol {
        static var lastRequest: URLRequest?
        static var responseData: Data = Data()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            URLProtocolStub.lastRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: URLProtocolStub.responseData)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    func testFetchF1NewsBuildsCorrectRequest() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        URLProtocolStub.responseData = "[{\"id\":\"1\",\"title\":\"t\",\"link\":\"l\",\"published_at\":\"2024-01-01T00:00:00Z\",\"image_url\":null,\"source\":\"s\",\"excerpt\":\"e\"}]".data(using: .utf8)!
        let session = URLSession(configuration: config)
        let service = NewsService(baseURL: "https://example.com", session: session)

        _ = try await service.fetchF1News(year: 2024, limit: 10)

        let components = URLComponents(url: URLProtocolStub.lastRequest!.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.path, "/api/news/f1")
        XCTAssertTrue(components?.queryItems?.contains(URLQueryItem(name: "year", value: "2024")) ?? false)
        XCTAssertTrue(components?.queryItems?.contains(URLQueryItem(name: "limit", value: "10")) ?? false)
    }
}
