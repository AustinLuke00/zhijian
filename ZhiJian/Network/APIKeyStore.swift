import Foundation
import Security
import OSLog

/// 微信读书 API Key 在钥匙串里的读写。
///
/// 三个决定，都与“这是用户自己的凭证”直接相关：
///
/// 1. **`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。**
///    这条是 brief 明确的：Key 不进 iCloud 钥匙串、不进任何备份或换机迁移。
///    它只属于这台设备上的这个用户；换手机要重新填一次，这是有意为之。
///    代价：卸载后重装需要重新连接。收益：Key 不会跟着备份跑到别处。
///
/// 2. **断开连接 = 真的从钥匙串删除。** 不是“标记已断开”。
///    用户点断开，就是要它消失；留在钥匙串里只是自我安慰。
///
/// 3. **断开只清 Key，不动本地摘录。** 导入进来的划线和想法是用户的内容，
///    不因为断开连接而删除。这一点在 UI 上也要说清楚。
///
/// Key 的取值只在这个文件里进出钥匙串；网关通过 `apiKeyProvider` 拿到它，
/// 不持有、不缓存、不打日志。
protocol APIKeyStoring: Sendable {
    func loadKey() -> String?
    func saveKey(_ key: String) throws
    func deleteKey()
}

struct APIKeyStore: APIKeyStoring {
    private static let log = Logger(subsystem: "com.jerry.zhijian", category: "keychain")

    /// 读取当前保存的 Key。没有则返回 nil（不是错误——未连接是正常状态）。
    func loadKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: APIKeychain.service,
            kSecAttrAccount as String: APIKeychain.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
                return nil
            }
            return key.isEmpty ? nil : key
        case errSecItemNotFound:
            return nil
        default:
            // 只记状态码，不记任何内容
            Self.log.error("钥匙串读取失败：\(status, privacy: .public)")
            return nil
        }
    }

    /// 保存 Key。已存在则覆盖。
    ///
    /// 注意 `kSecAttrAccessible` 只在**新增**时生效。所以这里先尝试更新，
    /// 没更新到任何条目时，先删掉遗留条目再按正确的可访问性重新写入——
    /// 否则一个旧版本留下的、可迁移的条目会一直带着错误的可访问性活下去。
    func saveKey(_ key: String) throws {
        let data = Data(key.utf8)

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: APIKeychain.service,
            kSecAttrAccount as String: APIKeychain.account
        ]
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess { return }

        // 没有可更新的条目（或更新受阻）：清掉残留，按正确可访问性新建。
        SecItemDelete(updateQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: APIKeychain.service,
            kSecAttrAccount as String: APIKeychain.account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("钥匙串写入失败：\(addStatus, privacy: .public)")
            throw WeReadError.persistence("钥匙串写入失败（\(addStatus)）")
        }
    }

    /// 断开连接：真的从钥匙串里删掉。本地摘录不受影响。
    func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: APIKeychain.service,
            kSecAttrAccount as String: APIKeychain.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound 说明本来就没有，不算失败
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.log.error("钥匙串删除失败：\(status, privacy: .public)")
        }
    }
}
