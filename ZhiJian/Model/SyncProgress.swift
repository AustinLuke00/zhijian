import Foundation

/// 同步进度。由 `AsyncStream` 吐出，UI 订阅后自己切主线程更新。
///
/// 注意 `importedCount` 是**实际入库条数**，不是接口返回的笔记总数——
/// 总数里含书签（拿不到内容），拿它当导入量数字会对不上（Ato 增补 D）。
struct SyncProgress: Sendable, Equatable {
    /// 已发现的有笔记的书（`/user/notebooks` 翻页过程中增长）。
    var discoveredBooks: Int
    /// 已处理完的书。
    var processedBooks: Int
    /// 已入库的划线数。
    var importedQuotes: Int
    /// 已入库的想法数。
    var importedThoughts: Int
    /// 当前阶段，用于文案。
    var phase: SyncPhase

    static let zero = SyncProgress(
        discoveredBooks: 0,
        processedBooks: 0,
        importedQuotes: 0,
        importedThoughts: 0,
        phase: .idle
    )

    var importedTotal: Int { importedQuotes + importedThoughts }
}

enum SyncPhase: String, Sendable, Equatable {
    case idle
    /// 正在翻「有笔记的书」列表。
    case listingBooks
    /// 正在逐本抓划线与想法。
    case fetchingNotes
    case finished
    case failed

    var displayName: String {
        switch self {
        case .idle: return "准备中"
        case .listingBooks: return "正在读取书架"
        case .fetchingNotes: return "正在导入划线与想法"
        case .finished: return "导入完成"
        case .failed: return "导入失败"
        }
    }
}

/// 导入结束后的汇总。
struct SyncSummary: Sendable, Equatable {
    var books: Int
    var quotes: Int
    var thoughts: Int

    static let zero = SyncSummary(books: 0, quotes: 0, thoughts: 0)

    var total: Int { quotes + thoughts }
}

/// 页面状态。brief 决定 6：用枚举，不用三个 Bool（会出现互相矛盾的组合）。
enum LoadState: Sendable, Equatable {
    case idle
    case loading(SyncProgress)
    case loaded
    case failed(String)
}
