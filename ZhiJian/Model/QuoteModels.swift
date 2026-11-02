import Foundation
import SwiftData

/// 摘录的来源。
///
/// 本轮只有 `.weread`。`.scan`（纸质书拍照 OCR）是第四阶段的事，
/// 现在就把字段留出来，将来不用迁移整张表——这是 brief 决定 3。
enum QuoteSource: String, Codable, CaseIterable, Sendable {
    case weread
    case scan

    var displayName: String {
        switch self {
        case .weread: return "微信读书"
        case .scan: return "拍照录入"
        }
    }
}

/// 一本书。字段全部来自 `/user/notebooks` 的 `books[].book` 与计数。
///
/// `bookId` 上有 unique 约束（brief 决定 2）：重复同步不会灌出两本同样的书。
/// 注意 unique 撞车时 `context.save()` 会**抛错**，写入侧必须捕获，不能无脑 save。
@Model
final class Book {
    @Attribute(.unique) var bookId: String
    var title: String
    var author: String
    var cover: String

    /// 微信读书返回的划线数（`noteCount`）。
    /// 注意：这只是划线条数，**不是**总笔记数。
    var highlightCount: Int
    var reviewCount: Int
    /// 书签只有数量，拿不到内容——所以 UI 上不能承诺“导入书签”。
    var bookmarkCount: Int
    /// 0–100 整数（1 = 1%）。
    var readingProgress: Int
    /// `markedStatus == 1` 表示读完。
    var isFinished: Bool

    var createdAt: Date
    var updatedAt: Date

    /// 级联删除：删掉一本书，它的划线和想法一起走（brief 决定 4）。
    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote] = []

    @Relationship(deleteRule: .cascade, inverse: \Thought.book)
    var thoughts: [Thought] = []

    init(
        bookId: String,
        title: String,
        author: String,
        cover: String,
        highlightCount: Int = 0,
        reviewCount: Int = 0,
        bookmarkCount: Int = 0,
        readingProgress: Int = 0,
        isFinished: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.title = title
        self.author = author
        self.cover = cover
        self.highlightCount = highlightCount
        self.reviewCount = reviewCount
        self.bookmarkCount = bookmarkCount
        self.readingProgress = readingProgress
        self.isFinished = isFinished
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 笔记总数（统计口径）= 划线 + 想法 + 书签。
    ///
    /// 这个数**大于**实际能导入的内容条数（书签拿不到内容）。
    /// 进度页要用实际入库条数，别拿它当导入量，否则数字对不上。
    var totalNoteCount: Int {
        highlightCount + reviewCount + bookmarkCount
    }

    /// 本轮实际导入的条数：划线 + 想法，不含书签。
    var importableCount: Int {
        quotes.count + thoughts.count
    }
}

/// 一条划线（微信读书的“划线”，书签已被接口过滤掉）。
///
/// **这里只放网络数据。** 备注、标签、收藏在 `QuoteAnnotation` 里——
/// brief 决定 1：同步只写这个模型，永不触碰 Annotation，
/// 否则用户写的备注会在下一次同步被冲掉。这是整个数据层最重要的一条。
@Model
final class Quote {
    @Attribute(.unique) var bookmarkId: String
    var bookId: String
    var chapterUid: Int
    var chapterTitle: String
    var chapterIdx: Int
    var markText: String
    /// 形如 `"2959-3007"`。想法靠它与划线配对（brief 决定 5）。
    var range: String
    var colorStyle: Int
    var createTime: Date
    var source: QuoteSource

    /// 反向关系用 nullify：删一条划线不该把整本书删掉。
    var book: Book?

    /// 一条划线可能挂多条想法（同一段划了多次、不同时间写了想法）。
    /// 所以这里是**一对多**，不是一对一（Ato 增补 E）。
    @Relationship(deleteRule: .cascade, inverse: \Thought.quote)
    var thoughts: [Thought] = []

    /// 用户自己的备注与标签。同步不碰它。
    @Relationship(deleteRule: .cascade, inverse: \QuoteAnnotation.quote)
    var annotation: QuoteAnnotation?

    init(
        bookmarkId: String,
        bookId: String,
        chapterUid: Int,
        chapterTitle: String = "",
        chapterIdx: Int = 0,
        markText: String,
        range: String = "",
        colorStyle: Int = 0,
        createTime: Date,
        source: QuoteSource = .weread
    ) {
        self.bookmarkId = bookmarkId
        self.bookId = bookId
        self.chapterUid = chapterUid
        self.chapterTitle = chapterTitle
        self.chapterIdx = chapterIdx
        self.markText = markText
        self.range = range
        self.colorStyle = colorStyle
        self.createTime = createTime
        self.source = source
    }

    /// 配对键：`(bookId, chapterUid, range)`。
    /// 三条都对上才认为是“这条想法写在这条划线上”。
    var matchKey: String {
        Self.matchKey(bookId: bookId, chapterUid: chapterUid, range: range)
    }

    static func matchKey(bookId: String, chapterUid: Int, range: String) -> String {
        "\(bookId)#\(chapterUid)#\(range)"
    }
}

/// 一条想法 / 点评。
///
/// `quoteId` 为 nil 表示“匹配不上任何划线”——整本书评、章节点评的
/// `abstract` / `range` 可能为空。**不丢弃**，单独成条展示（brief 决定 5）。
@Model
final class Thought {
    @Attribute(.unique) var reviewId: String
    var bookId: String
    var content: String
    /// 对应的划线原文。条件字段，整本书评可能为空。
    var abstract: String
    /// 条件字段，可能为空。
    var range: String
    var chapterUid: Int
    var chapterTitle: String
    var chapterIdx: Int
    var createTime: Date
    /// 0–5；-1 表示没有评分。
    var star: Int

    var book: Book?
    /// nil = 没配上划线，单独展示。
    var quote: Quote?

    init(
        reviewId: String,
        bookId: String,
        content: String,
        abstract: String = "",
        range: String = "",
        chapterUid: Int = 0,
        chapterTitle: String = "",
        chapterIdx: Int = 0,
        createTime: Date,
        star: Int = -1
    ) {
        self.reviewId = reviewId
        self.bookId = bookId
        self.content = content
        self.abstract = abstract
        self.range = range
        self.chapterUid = chapterUid
        self.chapterTitle = chapterTitle
        self.chapterIdx = chapterIdx
        self.createTime = createTime
        self.star = star
    }

    /// 有 range 才能参与配对；整本书评这类没有 range 的，保持 nil。
    var matchKey: String? {
        guard !range.isEmpty else { return nil }
        return Quote.matchKey(bookId: bookId, chapterUid: chapterUid, range: range)
    }
}

/// 用户对一条划线的自有数据：备注、标签、收藏。
///
/// 这是 brief 决定 1 的另一半。它**只**由用户操作产生，
/// 导入管线永远不会写它——同步覆盖不到这里，备注就不会丢。
@Model
final class QuoteAnnotation {
    /// 一条划线最多一个 annotation，用 quoteId 定位。
    @Attribute(.unique) var quoteId: String
    var note: String
    /// SwiftData 存数组比建一张关联表省事，标签数量很小。
    var tags: [String]
    var isFavorite: Bool
    var updatedAt: Date

    var quote: Quote?

    init(
        quoteId: String,
        note: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        updatedAt: Date = .now
    ) {
        self.quoteId = quoteId
        self.note = note
        self.tags = tags
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
    }
}
