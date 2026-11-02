import Foundation
import OSLog

/// 导入管线：书架 → 有笔记的书 → 逐本抓划线与想法 → 关联 → 落库。
///
/// 顺序是 brief 定死的，不要改：
/// ```
/// /shelf/sync      → 验证 Key（预热）
/// /user/notebooks  → 只拿「有笔记的书」，游标翻到 hasMore=0
/// 每本：/book/bookmarklist → 划线；/review/list/mine → 想法
/// ```
/// 不要遍历整个书架逐本查笔记：书架可能几百本，有笔记的通常几十本，
/// 逐本查会被限流而且慢得离谱。
///
/// 两个分页游标**互不相通**（Ato 增补 F）：
/// - `/user/notebooks` 用 `lastSort`
/// - `/review/list/mine` 用 `synckey`
/// 混用会静默返回重复页。
///
/// 进度用 `AsyncStream` 吐出，Service 自己不碰 UI 状态（brief 决定 7）。
struct ImportPipeline: Sendable {
    private let gateway: WeReadGateway
    private let store: ImportStore
    private static let log = Logger(subsystem: "com.jerry.zhijian", category: "import")

    /// 每批并发的书的数量。无界并发会被限流，4–6 是 brief 给的区间。
    static let batchSize = 5
    /// `/user/notebooks` 每页取多少本。
    static let notebookPageSize = 100
    /// 单本想法每页取多少条。
    static let reviewPageSize = 100

    init(gateway: WeReadGateway, store: ImportStore) {
        self.gateway = gateway
        self.store = store
    }

    /// 跑一次完整导入。
    ///
    /// - Returns: 进度流。调用方边跑边订阅；流结束时返回汇总。
    func run() -> (stream: AsyncThrowingStream<SyncProgress, Error>, summary: Task<SyncSummary, Error>) {
        let (stream, continuation) = AsyncThrowingStream<SyncProgress, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let summary = Task<SyncSummary, Error> {
            do {
                let result = try await perform(progress: continuation)
                continuation.finish()
                return result
            } catch {
                continuation.finish(throwing: error)
                throw error
            }
        }

        return (stream, summary)
    }

    // MARK: - 主流程

    private func perform(
        progress: AsyncThrowingStream<SyncProgress, Error>.Continuation
    ) async throws -> SyncSummary {
        // 0) 预热 + 验证 Key。失败就直接抛，不进下一步。
        try await gateway.validate(apiName: "/shelf/sync")

        var current = SyncProgress.zero
        current.phase = .listingBooks
        progress.yield(current)

        // 1) 翻「有笔记的书」，只认 count + lastSort 游标
        var notebooks: [NotebookBookDTO] = []
        var lastSort: Int?
        while true {
            try Task.checkCancellation()

            var params: [String: Any] = ["count": Self.notebookPageSize]
            if let lastSort { params["lastSort"] = lastSort }

            let page: NotebookPageDTO = try await gateway.call(
                apiName: "/user/notebooks",
                params: params
            )

            notebooks.append(contentsOf: page.books)

            current.discoveredBooks = notebooks.count
            progress.yield(current)

            guard page.hasMorePages, let nextSort = page.books.last?.sort else { break }
            // 游标没前进就停，否则会死循环重复拉同一页
            guard nextSort != lastSort else { break }
            lastSort = nextSort
        }

        current.phase = .fetchingNotes
        progress.yield(current)

        // 2) 分批并发抓每本书的划线与想法
        var totals = SyncSummary.zero
        for batch in notebooks.chunked(into: Self.batchSize) {
            try Task.checkCancellation()

            let counts = try await withThrowingTaskGroup(of: ImportCounts.self) { group in
                for bookDTO in batch {
                    let gateway = self.gateway
                    let store = self.store
                    group.addTask {
                        try await Self.importBook(bookDTO, gateway: gateway, store: store)
                    }
                }

                var collected = ImportCounts(quotes: 0, thoughts: 0)
                while let counts = try await group.next() {
                    collected.quotes += counts.quotes
                    collected.thoughts += counts.thoughts
                }
                return collected
            }

            totals.quotes += counts.quotes
            totals.thoughts += counts.thoughts
            totals.books += batch.count

            current.processedBooks += batch.count
            current.importedQuotes += counts.quotes
            current.importedThoughts += counts.thoughts
            progress.yield(current)
        }

        current.phase = .finished
        progress.yield(current)
        return totals
    }

    // MARK: - 单本书

    /// 抓一本书的划线与想法并落库。
    ///
    /// 一本失败会让整轮失败（TaskGroup 里抛错会取消同批其余任务）。
    /// 这是有意的：静默导入“40 本里的 39 本”比明确报错更难解释，
    /// 用户会以为全都导完了。真正出错时，宁可让用户看到错误再点一次。
    private static func importBook(
        _ dto: NotebookBookDTO,
        gateway: WeReadGateway,
        store: ImportStore
    ) async throws -> ImportCounts {
        try Task.checkCancellation()

        let bookId = dto.bookId
        let bookPayload = DTOMapper.bookPayload(from: dto)

        // 划线与想法两个接口互不依赖，并发取
        async let bookmarkList: BookmarkListDTO = gateway.call(
            apiName: "/book/bookmarklist",
            params: ["bookId": bookId]
        )
        async let firstReviewPage: ReviewPageDTO = gateway.call(
            // 注意这里是全小写的 bookid
            apiName: "/review/list/mine",
            params: ["bookid": bookId, "count": reviewPageSize]
        )

        let bookmarkDTO = try await bookmarkList
        var reviewDTOs = [try await firstReviewPage]

        // 想法分页：游标是 synckey，只认它
        var synckey = reviewDTOs[0].synckey ?? 0
        while reviewDTOs.last?.hasMorePages == true {
            try Task.checkCancellation()

            let page: ReviewPageDTO = try await gateway.call(
                apiName: "/review/list/mine",
                params: ["bookid": bookId, "count": reviewPageSize, "synckey": synckey]
            )
            reviewDTOs.append(page)

            guard let next = page.synckey, next != synckey else { break }
            synckey = next
        }

        let quotes = DTOMapper.quotePayloads(from: bookmarkDTO, bookId: bookId)
        let thoughts = reviewDTOs.flatMap { DTOMapper.thoughtPayloads(from: $0, bookId: bookId) }

        return try await store.persist(
            book: bookPayload,
            quotes: quotes,
            thoughts: thoughts
        )
    }
}

extension Array {
    /// 分批。用于把几百本书切成每批 4–6 本并发。
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
}
