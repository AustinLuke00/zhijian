import Foundation

/// 网关与连接层的错误。
///
/// 两条硬约束（来自 brief 第五节，实现时不要放宽）：
/// 1. **错误对象里绝不携带 API Key** —— 它会被打到日志、也会直接显示在界面上。
/// 2. **不编造 errcode 含义** —— 官方没有提供完整错误码表，所以这里只有
///    “非 0 即错误”这一个判断，不把某个具体数字解释成“鉴权失败”之类。
///
/// 每个 case 只带“能安全展示和记录”的信息：错误码、接口名、原始中文提示。
/// 需要 `Equatable` 是为了测试能精确断言抛的是哪一个错误。
enum WeReadError: Error, LocalizedError, Equatable {
    /// 本地没有 Key（未连接，或 Keychain 读取失败）。
    case missingAPIKey
    /// 前缀不是 `wrk-`，本地就能判定，不发请求。
    case invalidKeyFormat
    /// 回包带 `upgrade_info`：必须立即暂停，优先级高于 errcode。
    case upgradeRequired(String)
    /// `errcode` 非 0。`message` 是回包里的原始中文提示，可能为 nil。
    case api(errcode: Int, message: String?)
    /// HTTP 状态码不在 2xx。
    case httpStatus(Int)
    /// 传输层失败（无网、超时、DNS…）。只带 URLError，不含请求头。
    case request(URLError)
    /// 响应不是 HTTPURLResponse。
    case notHTTPResponse
    /// 回包是空的。
    case emptyResponse(apiName: String)
    /// 回包结构变了 / 字段类型对不上。
    case decoding(apiName: String)
    /// 请求体拼不出来（业务参数不是 JSON 对象）。
    case encodingFailed(apiName: String)
    /// 用户取消。
    case cancelled
    /// SwiftData 写入失败（unique 撞 ID 会走到这里）。
    case persistence(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "还没有连接微信读书，请先填入 API Key。"
        case .invalidKeyFormat:
            return "这个 Key 的格式不对，微信读书的 Key 以 wrk- 开头。"
        case let .upgradeRequired(message):
            return message
        case let .api(errcode, message):
            if let message, !message.isEmpty { return message }
            return "微信读书接口返回错误（errcode \(errcode)）。"
        case let .httpStatus(code):
            return "微信读书接口返回 HTTP \(code)。"
        case let .request(error):
            return "网络请求失败：\(error.localizedDescription)"
        case .notHTTPResponse:
            return "微信读书返回的不是 HTTP 响应。"
        case let .emptyResponse(apiName):
            return "\(apiName) 返回了空内容。"
        case let .decoding(apiName):
            return "\(apiName) 的返回结构和预期不一致。"
        case let .encodingFailed(apiName):
            return "\(apiName) 的请求参数拼装失败。"
        case .cancelled:
            return "已取消。"
        case let .persistence(detail):
            return "本地保存失败：\(detail)"
        }
    }

    /// 出错的接口名。日志与测试用。
    var apiName: String? {
        switch self {
        case let .emptyResponse(apiName),
             let .decoding(apiName),
             let .encodingFailed(apiName):
            return apiName
        default:
            return nil
        }
    }

    var isCancellation: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
