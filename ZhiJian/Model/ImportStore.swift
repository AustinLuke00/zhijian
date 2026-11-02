import Foundation
import SwiftData
import OSLog

/// 导入的写入口。跑在后台 context 上（`@ModelActor`），不占主线程。
///
/// 这个文件里最重要的一条：**`save()` 会抛错，必须处理。**
/// `bookmarkId` / `reviewId` / `bookId` 上有 `@Attribute(.unique)`，
/// 重复同步时撞 ID 会让 save 直接失败。不捕获的话，
/// 表现是“第二次同步什么都没导进来”，而且很难从界面上看出来。
@ModelActor
actor ImportStore {
    private static let log = Logger(subsystem: "com.jerry.zhijian", category: "import-store")

    /// 批量写入一本书的划线与想法。
    ///
    /// 写入顺序：先 upsert 书 → 写划线 → 写想法 → 配对。
    /// 配对放在最后，因为想法要挂到已经落库的划线上。
    ///
    /// - Returns: 本次实际新增的条数（划线 + 想法）。
    ///   进度页用这个数，不用接口返回的“笔记总数”——那里面含书签，对不上。
    func persist(
        book: BookPayload,
        quotes: [QuotePayload],
        thoughts: [ThoughtPayload]
    ) throws -> ImportCounts {
        try saveThrowing()

        let bookModel = try upsertBookModel(book)
        let newQuotes = try insertQuotes(quotes, into: bookModel)
        let newThoughts = try insertThoughts(thoughts, into: bookModel)
        try linkThoughtsToQuotes(bookId: book.bookId)
        try saveThrowing()

        return ImportCounts(quotes: newQuotes, thoughts: newThoughts)
    }

    /// 只 upsert 书籍（导入管线的第一步也会用到）。
    func upsertBook(_ payload: BookPayload) throws {
        _ = try upsertBookModel(payload)
        try saveThrowing()
    }

    // MARK: - 写入

    /// 已存在则更新计数，不存在则新建。
    /// 更新时**只更新网络侧字段**，不碰用户改过的东西。
    private func upsertBookModel(_ payload: BookPayload) throws -> Book {
        let bookId = payload.bookId
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.title = payload.title
            existing.author = payload.author
            existing.cover = payload.cover
            existing.highlightCount = payload.highlightCount
            existing.reviewCount = payload.reviewCount
            existing.bookmarkCount = payload.bookmarkCount
            existing.readingProgress = payload.readingProgress
            existing.isFinished = payload.isFinished
            existing.updatedAt = .now
            return existing
        }

        let book = Book(
            bookId: payload.bookId,
            title: payload.title,
            author: payload.author,
            cover: payload.cover,
            highlightCount: payload.highlightCount,
            reviewCount: payload.reviewCount,
            bookmarkCount: payload.bookmarkCount,
            readingProgress: payload.readingProgress,
            isFinished: payload.isFinished
        )
        modelContext.insert(book)
        return book
    }

    /// 返回新增条数。已存在的（同一个 bookmarkId）跳过——这是幂等的来源。
    private func insertQuotes(_ payloads: [QuotePayload], into book: Book) throws -> Int {
        var inserted = 0
        for payload in payloads {
            // 必须先落到局部常量：#Predicate 会把 payload.bookmarkId 解析成
            // 对 payload 的 keypath，而不是一个字符串字面量，宏展开会失败。
            let bookmarkId = payload.bookmarkId
            let descriptor = FetchDescriptor<Quote>(
                predicate: #Predicate { $0.bookmarkId == bookmarkId }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                // 已存在：只补网络侧字段。绝不碰 annotation。
                existing.chapterTitle = payload.chapterTitle
                existing.chapterIdx = payload.chapterIdx
                existing.markText = payload.markText
                existing.range = payload.range
                existing.colorStyle = payload.colorStyle
                continue
            }

            let quote = Quote(
                bookmarkId: payload.bookmarkId,
                bookId: payload.bookId,
                chapterUid: payload.chapterUid,
                chapterTitle: payload.chapterTitle,
                chapterIdx: payload.chapterIdx,
                markText: payload.markText,
                range: payload.range,
                colorStyle: payload.colorStyle,
                createTime: payload.createTime,
                source: payload.source
            )
            quote.book = book
            modelContext.insert(quote)
            inserted += 1
        }
        return inserted
    }

    private func insertThoughts(_ payloads: [ThoughtPayload], into book: Book) throws -> Int {
        var inserted = 0
        for payload in payloads {
            let reviewId = payload.reviewId
            let descriptor = FetchDescriptor<Thought>(
                predicate: #Predicate { $0.reviewId == reviewId }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                existing.content = payload.content
                existing.abstract = payload.abstract
                existing.range = payload.range
                existing.chapterUid = payload.chapterUid
                existing.chapterTitle = payload.chapterTitle
                existing.chapterIdx = payload.chapterIdx
                existing.star = payload.star
                continue
            }

            let thought = Thought(
                reviewId: payload.reviewId,
                bookId: payload.bookId,
                content: payload.content,
                abstract: payload.abstract,
                range: payload.range,
                chapterUid: payload.chapterUid,
                chapterTitle: payload.chapterTitle,
                chapterIdx: payload.chapterIdx,
                createTime: payload.createTime,
                star: payload.star
            )
            thought.book = book
            modelContext.insert(thought)
            inserted += 1
        }
        return inserted
    }

    /// 用 `(bookId, chapterUid, range)` 三元组把想法挂到划线上。
    ///
    /// 一条划线可以挂多条想法（一对多）。匹配不上的想法保持 `quote == nil`，
    /// 单独展示，**不丢弃、不硬塞**。
    private func linkThoughtsToQuotes(bookId: String) throws {
        let quoteDescriptor = FetchDescriptor<Quote>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        let quotes = try modelContext.fetch(quoteDescriptor)
        guard !quotes.isEmpty else { return }

        var index: [String: Quote] = [:]
        for quote in quotes where !quote.range.isEmpty {
            // 同一个键可能有多条划线，先到先得。
            if index[quote.matchKey] == nil {
                index[quote.matchKey] = quote
            }
        }
        guard !index.isEmpty else { return }

        // 关系与 nil 的比较在 #Predicate 里不可靠，所以按 bookId 取回后在 Swift 侧过滤。
        let thoughtDescriptor = FetchDescriptor<Thought>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        for thought in try modelContext.fetch(thoughtDescriptor) {
            guard thought.quote == nil else { continue }
            guard let key = thought.matchKey, let quote = index[key] else { continue }
            thought.quote = quote
            if !quote.thoughts.contains(where: { $0.reviewId == thought.reviewId }) {
                quote.thoughts.append(thought)
            }
        }
    }

    // MARK: - 保存

    /// 统一的保存口。unique 撞车会走到这里，转成明确错误抛出去。
    private func saveThrowing() throws {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            Self.log.error("SwiftData 保存失败：\(error.localizedDescription, privacy: .public)")
            throw WeReadError.persistence(error.localizedDescription)
        }
    }
}

/// 本次导入的新增条数。进度页用它，不用接口的“笔记总数”。
struct ImportCounts: Sendable, Equatable {
    var quotes: Int
    var thoughts: Int

    var total: Int { quotes + thoughts }
}

// MARK: - 写入载荷

/// 网络侧数据的中间形态。DTO 到 Model 的映射在管线里做，
/// 这样 `ImportStore` 不依赖网络类型，测试可以直接造 payload。
struct BookPayload: Sendable {
    let bookId: String
    let title: String
    let author: String
    let cover: String
    let highlightCount: Int
    let reviewCount: Int
    let bookmarkCount: Int
    let readingProgress: Int
    let isFinished: Bool
}

struct QuotePayload: Sendable {
    let bookmarkId: String
    let bookId: String
    let chapterUid: Int
    let chapterTitle: String
    let chapterIdx: Int
    let markText: String
    let range: String
    let colorStyle: Int
    let createTime: Date
    let source: QuoteSource
}

struct ThoughtPayload: Sendable {
    let reviewId: String
    let bookId: String
    let content: String
    let abstract: String
    let range: String
    let chapterUid: Int
    let chapterTitle: String
    let chapterIdx: Int
    let createTime: Date
    let star: Int
}
