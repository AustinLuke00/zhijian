import SwiftUI
import SwiftData

@main
struct ZhiJianApp: App {
    private let container: ModelContainer = {
        do {
            return try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("无法创建 ModelContainer：\(error)")
        }
    }()

    @State private var connectionService: ReadConnectionService = {
        let store = APIKeyStore()
        let gateway = WeReadGateway(apiKeyProvider: {
            guard let key = store.loadKey() else { throw WeReadError.missingAPIKey }
            return key
        })
        return ReadConnectionService(gateway: gateway, keyStore: store)
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(connectionService)
        }
    }
}
