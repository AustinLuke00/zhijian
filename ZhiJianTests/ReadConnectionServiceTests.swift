import Foundation
import Testing

@testable import ZhiJian

/// 测试用的钥匙串替身：内存字典，行为与真钥匙串一致（没有就是没有）。
///
/// 必须用替身，不能用真钥匙串：真钥匙串在测试之间是共享的，
/// 一个测试存进去的 Key 会漏进下一个测试，让 state 断言变成“看谁先跑”。
/// 这也是为什么连接流程要把存储做成可注入的。
private final class InMemoryKeyStore: APIKeyStoring, @unchecked Sendable {
    private(set) var storage: String?

    func loadKey() -> String? { storage }

    func saveKey(_ key: String) throws { storage = key }

    func deleteKey() { storage = nil }
}

/// 记下每次请求用的 Key 与请求体的假传输。
private final class RecordingTransport: HTTPTransport, @unchecked Sendable {
    var responder: (URLRequest) -> (Data, Int)
    private(set) var authorizationHeaders: [String] = []
    private(set) var requestBodies: [Data] = []

    init(responder: @escaping (URLRequest) -> (Data, Int)) {
        self.responder = responder
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        authorizationHeaders.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
        requestBodies.append(request.httpBody ?? Data())
        let (data, status) = responder(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    /// 最后一次请求体的 JSON 对象，用来断言 api_name 和参数。
    func lastBodyObject() throws -> [String: Any] {
        let body = try #require(requestBodies.last)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

@MainActor
struct ReadConnectionServiceTests {

    private func makeService(
        transport: RecordingTransport,
        store: InMemoryKeyStore = InMemoryKeyStore()
    ) -> ReadConnectionService {
        let gateway = WeReadGateway(transport: transport) { "" }
        return ReadConnectionService(gateway: gateway, keyStore: store)
    }

    // MARK: - 格式校验先行

    /// 格式不对必须一次请求都不发。
    @Test
    func invalidFormatSkipsNetwork() async {
        let transport = RecordingTransport { _ in (Data(#"{"errcode":0}"#.utf8), 200) }
        let service = makeService(transport: transport)

        do {
            try await service.connect(with: "not-a-key")
            Issue.record("应当抛出 invalidKeyFormat")
        } catch let error as WeReadError {
            #expect(error == .invalidKeyFormat)
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }

        #expect(transport.authorizationHeaders.isEmpty)
        #expect(service.state == .disconnected)
    }

    // MARK: - 验证通过才落盘

    @Test
    func validKeyIsSavedAfterVerification() async throws {
        let transport = RecordingTransport { _ in (Data(#"{"errcode":0}"#.utf8), 200) }
        let service = makeService(transport: transport)

        try await service.connect(with: "wrk-valid-key")

        #expect(service.state == .connected)
        #expect(transport.authorizationHeaders == ["Bearer wrk-valid-key"])
        #expect(service.lastError == nil)
    }

    /// 最关键的一条：Key 无效时**绝不能**写进钥匙串。
    /// 否则界面会停在“已连接”，一同步就报错——这种状态最难排查。
    @Test
    func failedVerificationNeverPersistsKey() async {
        let transport = RecordingTransport { _ in
            (Data(#"{"errcode":-2010,"errmsg":"登录已失效"}"#.utf8), 200)
        }
        let store = InMemoryKeyStore()
        let service = makeService(transport: transport, store: store)

        do {
            try await service.connect(with: "wrk-bad-key")
            Issue.record("应当抛出 api 错误")
        } catch let error as WeReadError {
            #expect(error == .api(errcode: -2010, message: "登录已失效"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }

        #expect(service.state == .disconnected)
        #expect(service.lastError != nil)
        // 真正的断言：钥匙串里根本没写过
        #expect(store.storage == nil)
    }

    /// 探活请求必须走 `/shelf/sync`：无参数、纯依赖 Key。
    @Test
    func verificationUsesShelfSync() async throws {
        let transport = RecordingTransport { _ in (Data(#"{"errcode":0}"#.utf8), 200) }
        let service = makeService(transport: transport)

        try await service.connect(with: "wrk-valid-key")

        let body = try transport.lastBodyObject()
        #expect(body["api_name"] as? String == "/shelf/sync")
    }

    // MARK: - 断开连接

    /// 断开 = 从钥匙串删除。不是“标记已断开”。
    @Test
    func disconnectClearsStoredKey() async throws {
        let transport = RecordingTransport { _ in (Data(#"{"errcode":0}"#.utf8), 200) }
        let service = makeService(transport: transport)

        try await service.connect(with: "wrk-valid-key")
        #expect(service.state == .connected)

        service.disconnect()
        #expect(service.state == .disconnected)

        // 断开之后 currentKey 必须拿不到东西
        do {
            _ = try service.currentKey()
            Issue.record("断开后不应还能取到 Key")
        } catch let error as WeReadError {
            #expect(error == .missingAPIKey)
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }
    }

    /// 未连接时取 Key 是明确错误，不是空字符串。
    @Test
    func currentKeyThrowsWhenDisconnected() {
        let transport = RecordingTransport { _ in (Data(#"{"errcode":0}"#.utf8), 200) }
        let service = makeService(transport: transport)

        #expect(throws: WeReadError.missingAPIKey) {
            _ = try service.currentKey()
        }
    }
}