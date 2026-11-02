import Foundation
import SwiftData

/// SwiftData 容器的组装。
///
/// 模型类型只在这里登记一次，App 和测试共用，避免两边列表不一致。
enum ModelContainerFactory {
    static let models: [any PersistentModel.Type] = [
        Book.self,
        Quote.self,
        Thought.self,
        QuoteAnnotation.self
    ]

    /// 真机/模拟器用的持久化容器。
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: schema(), configurations: ModelConfiguration(isStoredInMemoryOnly: false))
    }

    /// 测试与预览用的内存容器。
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: schema(), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private static func schema() -> Schema {
        Schema(models)
    }
}
