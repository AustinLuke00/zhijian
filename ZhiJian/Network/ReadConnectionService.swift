import Foundation
import Observation
import OSLog

/// 连接状态。UI 直接读它，不需要再自己拼“有没有连过”。
enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connected
}

/// 连接微信读书的流程编排。
///
/// 顺序是 brief 定死的，**不要为了少一次请求而调换**：
///
/// 1. **本地格式校验**（`wrk-` 前缀）→ 不合法直接失败，一次请求都不发。
/// 2. **打 `/shelf/sync` 验证** → 只有真的通了才算连接成功。
///    为什么用 `/shelf/sync`：它无参数、只依赖 Key 本身，是纯粹的探活接口；
///    Key 无效时它会以 errcode 失败，正好当作验证结果。
/// 3. **写钥匙串** → 只有验证通过才落盘。
///
/// 反过来（先存再验）会留下一个“连上了但其实不通”的状态，
/// 界面显示已连接、一同步就报错，这种状态最难排查。
///
/// 断开连接走 `disconnect()`：真删 Keychain，本地摘录保留。
@MainActor
@Observable
final class ReadConnectionService {
    private(set) var state: ConnectionState = .disconnected
    private(set) var lastError: WeReadError?

    private let gateway: WeReadGateway
    private let keyStore: any APIKeyStoring
    private static let log = Logger(subsystem: "com.jerry.zhijian", category: "connection")

    init(gateway: WeReadGateway, keyStore: any APIKeyStoring = APIKeyStore()) {
        self.gateway = gateway
        self.keyStore = keyStore
        refreshState()
    }

    /// 启动时同步一次状态：钥匙串里有 Key 就是已连接。
    /// 这里不做网络验证——启动就打接口会让离线打开 App 时莫名卡住。
    func refreshState() {
        state = keyStore.loadKey() == nil ? .disconnected : .connected
    }

    var isConnected: Bool { state == .connected }

    /// 连接：校验格式 → 验证 → 存 Key。
    ///
    /// - Throws: 格式不对抛 `invalidKeyFormat`；接口不通抛 gateway 的错误；
    ///   写入失败抛 `persistence`。
    @MainActor
    func connect(with rawKey: String) async throws {
        let candidate = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) 本地格式校验：不发请求
        guard APIKeychain.looksLikeKey(candidate) else {
            let error = WeReadError.invalidKeyFormat
            lastError = error
            throw error
        }

        // 2) 用候选 Key 打一次探活。注意这里走的是一个临时网关，
        //    因为持久网关的 provider 读的是钥匙串——此刻还没存进去。
        let probingGateway = gateway.withAPIKey(candidate)

        do {
            try await probingGateway.validate(apiName: "/shelf/sync")
        } catch let error as WeReadError {
            lastError = error
            throw error
        } catch {
            let wrapped = WeReadError.request(URLError(.unknown))
            lastError = wrapped
            throw wrapped
        }

        // 3) 验证通过才落盘
        do {
            try keyStore.saveKey(candidate)
        } catch {
            lastError = .persistence("钥匙串写入失败")
            throw error
        }

        lastError = nil
        state = .connected
        Self.log.info("已连接微信读书")
    }

    /// 断开：真删 Keychain 里的 Key。本地摘录保留，不删。
    @MainActor
    func disconnect() {
        keyStore.deleteKey()
        lastError = nil
        state = .disconnected
    }

    /// 当前保存的 Key。只给需要它的人（导入管线）用，不展示、不记录。
    func currentKey() throws -> String {
        guard let key = keyStore.loadKey() else {
            throw WeReadError.missingAPIKey
        }
        return key
    }
}
