import Foundation
import OSLog

/// 微信读书网关的唯一出口。
///
/// 三件事是这个类型存在的理由，改代码时不要绕开：
///
/// 1. **参数平铺。** `api_name`、业务参数、`skill_version` 必须在 body 的同一层。
///    官方速查表明确写了：包进 `params` 会让分页静默失效——不报错、不崩溃，
///    只是永远只返回第一页。这种 bug 在几十本书的场景下极难发现，
///    所以这里把“平铺”做成唯一可用的调用方式，没有提供“包进 params”的入口。
///
/// 2. **`skill_version` 每次注入。** 调用方不需要、也不应该自己传它；
///    版本常量只有一处（below），将来升 1.0.6 只改一行。
///
/// 3. **响应按固定顺序拦截**：`upgrade_info` → `errcode` → 解析业务数据。
///    `upgrade_info` 必须最先查：它代表“接口要升级了，现在的调用方式不再可信”，
///    优先级高于任何 errcode。
///
/// 另外两条安全约束：
/// - **任何日志、任何错误对象都不含 API Key。** 错误只带 errcode 与 api_name。
/// - **不编造 errcode 的含义。** 官方没有给错误码表，所以这里只判断“非 0 即错”，
///   把回包里的原始中文提示透传出去。
struct WeReadGateway: Sendable {
    static let endpoint = URL(string: "https://i.weread.qq.com/api/agent/gateway")!
    /// 以 `skills/SKILL.md` 顶部的 version 为准。仓库 README 上的 1.0.4 是没同步的旧值。
    static let skillVersion = "1.0.5"

    private let transport: any HTTPTransport
    private let apiKeyProvider: @Sendable () async throws -> String

    init(
        transport: any HTTPTransport = URLSessionTransport(),
        apiKeyProvider: @escaping @Sendable () async throws -> String
    ) {
        self.transport = transport
        self.apiKeyProvider = apiKeyProvider
    }

    /// 复用同一个传输层、换成固定 Key 的网关副本。
    ///
    /// 连接流程需要它：Key 还没进钥匙串时，就要先用候选 Key 打一次探活，
    /// 而持久网关的 provider 读的是钥匙串。
    func withAPIKey(_ key: String) -> WeReadGateway {
        WeReadGateway(transport: transport) { key }
    }

    /// 打一次网关。业务参数会与 `api_name`、`skill_version` 平铺在 body 顶层。
    ///
    /// - Parameter params: 该接口的业务参数，例如 `["bookId": "123"]`。
    ///   注意 `/review/list/mine` 的参数名是全小写 `bookid`，调用方自己负责写对。
    func call<T: Decodable>(
        apiName: String,
        params: [String: Any] = [:]
    ) async throws -> T {
        let body = try requestBody(apiName: apiName, params: params)
        return try await send(body: body, apiName: apiName)
    }

    /// 只要“这次请求成没成”，不关心回包内容。用于只做写操作或只做探活的场景。
    func callIgnoringResponse(
        apiName: String,
        params: [String: Any] = [:]
    ) async throws {
        let body = try requestBody(apiName: apiName, params: params)
        let _: EmptyResponse = try await send(body: body, apiName: apiName)
    }

    /// 只发一次请求、不解析业务数据的探活。连接流程里用它验证 Key。
    func validate(apiName: String = "/shelf/sync", params: [String: Any] = [:]) async throws {
        try await callIgnoringResponse(apiName: apiName, params: params)
    }

    // MARK: - 请求体

    /// 拼请求体。参数平铺是这里唯一的形态——见类型注释第 1 条。
    func requestBody(apiName: String, params: [String: Any]) throws -> Data {
        var payload: [String: Any] = params
        payload["api_name"] = apiName
        payload["skill_version"] = Self.skillVersion

        guard JSONSerialization.isValidJSONObject(payload) else {
            throw WeReadError.encodingFailed(apiName: apiName)
        }
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw WeReadError.encodingFailed(apiName: apiName)
        }
    }

    // MARK: - 发送与拦截

    private func send<T: Decodable>(body: Data, apiName: String) async throws -> T {
        let apiKey = try await apiKeyProvider()

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let data: Data
        let status: Int
        do {
            let (received, response) = try await transport.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw WeReadError.notHTTPResponse
            }
            status = http.statusCode
            data = received
        } catch let error as WeReadError {
            throw error
        } catch {
            if error is CancellationError { throw WeReadError.cancelled }
            if let urlError = error as? URLError {
                if urlError.code == .cancelled { throw WeReadError.cancelled }
                // 只打 api_name 与错误码，绝不打 request.allHTTPHeaderFields（里面有 Key）
                Self.log.error("\(apiName, privacy: .public) 传输失败：\(urlError.code.rawValue, privacy: .public)")
                throw WeReadError.request(urlError)
            }
            Self.log.error("\(apiName, privacy: .public) 传输失败：\(error.localizedDescription, privacy: .public)")
            throw WeReadError.request(URLError(.unknown))
        }

        guard (200..<300).contains(status) else {
            Self.log.error("\(apiName, privacy: .public) HTTP \(status, privacy: .public)")
            throw WeReadError.httpStatus(status)
        }
        guard !data.isEmpty else {
            throw WeReadError.emptyResponse(apiName: apiName)
        }

        // 拦截顺序：upgrade_info → errcode → 业务数据
        let decoder = JSONDecoder()
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            Self.log.error("\(apiName, privacy: .public) 回包外层解析失败")
            throw WeReadError.decoding(apiName: apiName)
        }

        if let upgrade = envelope.upgradeInfo {
            let message = upgrade.message ?? "微信读书接口需要升级，请更新纸间后再同步。"
            Self.log.error("\(apiName, privacy: .public) 收到 upgrade_info，暂停同步")
            throw WeReadError.upgradeRequired(message)
        }

        if let errcode = envelope.errcode, errcode != 0 {
            let message = envelope.message
            // 日志只含 api_name 与 errcode —— 这是 brief 的硬性要求
            Self.log.error("\(apiName, privacy: .public) errcode \(errcode, privacy: .public)")
            throw WeReadError.api(errcode: errcode, message: message)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.log.error("\(apiName, privacy: .public) 业务数据解析失败")
            throw WeReadError.decoding(apiName: apiName)
        }
    }

    private static let log = Logger(subsystem: "com.jerry.zhijian", category: "weread")

    /// 只解析错误拦截需要的字段。业务字段不在这里定义，各接口各自解码。
    struct Envelope: Decodable {
        let errcode: Int?
        let errmsg: String?
        let msg: String?
        let upgradeInfo: UpgradeInfo?

        enum CodingKeys: String, CodingKey {
            case errcode
            case errmsg
            case msg
            case upgradeInfo = "upgrade_info"
        }

        var message: String? {
            if let errmsg, !errmsg.isEmpty { return errmsg }
            if let msg, !msg.isEmpty { return msg }
            return nil
        }
    }

    struct UpgradeInfo: Decodable {
        let message: String?
        let url: String?
    }
}

/// 表示“只要它没报错就行”的空回包目标类型。
struct EmptyResponse: Decodable {}
