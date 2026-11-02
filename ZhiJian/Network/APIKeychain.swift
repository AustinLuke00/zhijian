import Foundation

/// Key 在钥匙串里的地址。
///
/// 用一个 `kSecAttrService` + `kSecAttrAccount` 的组合定位，查询时走
/// `kSecClassGenericPassword`。
enum APIKeychain {
    static let service = "com.jerry.zhijian.weread"
    static let account = "api-key"

    /// 微信读书的 Key 前缀。本地就能判定，不必浪费一次网络请求。
    static let keyPrefix = "wrk-"

    /// Key 的可见格式：`wrk-` 开头，后面至少一段非空字符。
    /// 只做前缀判断，不猜长度、不校验字符集——Key 的构成规则由微信读书决定，
    /// 我们一旦自己收紧，将来对方换格式就会把合法 Key 拒之门外。
    static func looksLikeKey(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(keyPrefix), trimmed.count > keyPrefix.count else {
            return false
        }
        return !trimmed.dropFirst(keyPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
