import Foundation
import Testing

@testable import ZhiJian

/// 假传输：给什么回包就返回什么，并记下最后一次请求以便断言。
private final class MockTransport: HTTPTransport, @unchecked Sendable {
    var responses: [(Data, Int)]
    var lastRequest: URLRequest?

    init(responses: [(Data, Int)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        guard !responses.isEmpty else {
            throw URLError(.notConnectedToInternet)
        }
        let (data, status) = responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private func gateway(_ mock: MockTransport) -> WeReadGateway {
    WeReadGateway(transport: mock) { "wrk-test-key" }
}

private func json(_ body: String) -> Data {
    Data(body.utf8)
}

struct WeReadGatewayTests {

    // MARK: - 请求体：参数必须平铺

    /// 最关键的一条。官方速查表：参数包进 `params` 会让分页静默失效——
    /// 不报错，只是永远只返回第一页。这个测试就是那道防线。
    @Test
    func requestBodyFlattensParams() throws {
        let gateway = WeReadGateway(transport: MockTransport(responses: [])) { "wrk-x" }
        let body = try gateway.requestBody(
            apiName: "/user/notebooks",
            params: ["count": 100, "lastSort": 42]
        )

        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["api_name"] as? String == "/user/notebooks")
        #expect(object["skill_version"] as? String == "1.0.5")
        #expect(object["count"] as? Int == 100)
        #expect(object["lastSort"] as? Int == 42)
        // 绝不允许出现嵌套的 params
        #expect(object["params"] == nil)
    }

    @Test
    func requestBodyRejectsNonJSONValues() {
        let gateway = WeReadGateway(transport: MockTransport(responses: [])) { "wrk-x" }
        #expect(throws: WeReadError.encodingFailed(apiName: "/book/info")) {
            _ = try gateway.requestBody(apiName: "/book/info", params: ["bad": Date()])
        }
    }

    // MARK: - 回包拦截顺序

    /// upgrade_info 必须压过 errcode：它代表“调用方式不再可信”。
    @Test
    func upgradeInfoBeatsErrcode() async {
        let mock = MockTransport(responses: [(
            json(#"{"errcode": 1234, "upgrade_info": {"message": "请升级"}}"#), 200
        )])
        let gateway = gateway(mock)

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛出 upgradeRequired")
        } catch let error as WeReadError {
            #expect(error == .upgradeRequired("请升级"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    @Test
    func errcodeNonZeroBecomesAPIError() async {
        let mock = MockTransport(responses: [(
            json(#"{"errcode": -2010, "errmsg": "登录已失效"}"#), 200
        )])
        let gateway = gateway(mock)

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛出 api 错误")
        } catch let error as WeReadError {
            #expect(error == .api(errcode: -2010, message: "登录已失效"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    /// `msg` 是 errmsg 缺失时的备用字段，两个都没有就只有 errcode。
    @Test
    func errcodeFallsBackToMsg() async {
        let mock = MockTransport(responses: [(json(#"{"errcode": 7, "msg": "服务繁忙"}"#), 200)])
        let gateway = gateway(mock)

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/user/notebooks")
            Issue.record("应当抛出 api 错误")
        } catch let error as WeReadError {
            #expect(error == .api(errcode: 7, message: "服务繁忙"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    @Test
    func errcodeZeroDecodesBusinessPayload() async throws {
        let mock = MockTransport(responses: [(
            json(#"{"errcode": 0, "totalBookCount": 3, "hasMore": 0}"#), 200
        )])
        let gateway = gateway(mock)

        struct Payload: Decodable {
            let totalBookCount: Int
            let hasMore: Int
        }

        let payload: Payload = try await gateway.call(apiName: "/user/notebooks")
        #expect(payload.totalBookCount == 3)
        #expect(payload.hasMore == 0)
    }

    @Test
    func httpFailureSurfacesStatusCode() async {
        let mock = MockTransport(responses: [(json(#"{"errcode": 0}"#), 401)])
        let gateway = gateway(mock)

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛出 httpStatus")
        } catch let error as WeReadError {
            #expect(error == .httpStatus(401))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    @Test
    func emptyBodyIsReported() async {
        let mock = MockTransport(responses: [(Data(), 200)])
        let gateway = gateway(mock)

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛出 emptyResponse")
        } catch let error as WeReadError {
            #expect(error == .emptyResponse(apiName: "/shelf/sync"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    // MARK: - Key 的传递与不外泄

    /// Key 必须进 Authorization 头，且是 Bearer 形式。
    @Test
    func apiKeyGoesIntoAuthorizationHeader() async throws {
        let mock = MockTransport(responses: [(json(#"{"errcode": 0}"#), 200)])
        let gateway = gateway(mock)

        let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")

        let request = try #require(mock.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer wrk-test-key")
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://i.weread.qq.com/api/agent/gateway")
    }

    /// 错误对象与日志都不许含 Key。这里直接断言错误描述里搜不到密钥片段。
    @Test
    func errorNeverLeaksAPIKey() async {
        let mock = MockTransport(responses: [(json(#"{"errcode": 99}"#), 500)])
        let gateway = WeReadGateway(transport: mock) { "wrk-super-secret-key" }

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛错")
        } catch let error as WeReadError {
            let description = error.errorDescription ?? ""
            #expect(!description.contains("wrk-"))
            #expect(!description.contains("super-secret"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    /// Key 由 provider 提供，provider 抛错就不发请求——
    /// 未连接状态下不能带着空 Authorization 去打接口。
    @Test
    func missingKeyStopsBeforeRequest() async {
        let mock = MockTransport(responses: [(json(#"{"errcode": 0}"#), 200)])
        let gateway = WeReadGateway(transport: mock) { throw WeReadError.missingAPIKey }

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛出 missingAPIKey")
        } catch let error as WeReadError {
            #expect(error == .missingAPIKey)
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
        #expect(mock.lastRequest == nil)
    }

    @Test
    func transportFailureBecomesRequestError() async {
        let mock = MockTransport(responses: [])
        let gateway = gateway(mock)

        do {
            let _: EmptyResponse = try await gateway.call(apiName: "/shelf/sync")
            Issue.record("应当抛出 request")
        } catch let error as WeReadError {
            #expect(error == .request(URLError(.notConnectedToInternet)))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }
}
