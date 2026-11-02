import Foundation

/// `/user/notebooks` 一页的回包。
///
/// 字段名照抄官方速查表，**不要按编码习惯改**（比如把 `bookId` 改成 `id`）。
struct NotebookPageDTO: Decodable, Sendable {
    let books: [NotebookBookDTO]
    let totalBookCount: Int?
    let totalNoteCount: Int?
    let hasMore: Int

    enum CodingKeys: String, CodingKey {
        case books
        case totalBookCount
        case totalNoteCount
        case hasMore
    }

    /// `hasMore` 有时是布尔、有时是 0/1，这里统一成 Bool 后再用。
    var hasMorePages: Bool { hasMore != 0 }
}

struct NotebookBookDTO: Decodable, Sendable {
    let bookId: String
    let book: NotebookBookInfoDTO
    let reviewCount: Int?
    let noteCount: Int?
    let bookmarkCount: Int?
    let readingProgress: Int?
    let markedStatus: Int?
    let sort: Int?

    var resolvedTitle: String { book.title }
    var resolvedAuthor: String { book.author ?? "" }
    var resolvedCover: String { book.cover ?? "" }
}

struct NotebookBookInfoDTO: Decodable, Sendable {
    let title: String
    let author: String?
    let cover: String?
}

/// `/book/bookmarklist` 的回包。
///
/// `type` 已由接口过滤（只返回 type=1 的划线），这里不解出书签。
struct BookmarkListDTO: Decodable, Sendable {
    let updated: [BookmarkDTO]?
    let chapters: [ChapterDTO]?
}

struct BookmarkDTO: Decodable, Sendable {
    let bookmarkId: String
    let chapterUid: Int
    let markText: String?
    let createTime: Int?
    let range: String?
    let colorStyle: Int?
    let type: Int?

    /// 只要 type=1（划线）。接口已经过滤过，这里是双保险：
    /// 万一将来接口把书签一起返回，也不能把书签当划线导进来。
    var isHighlight: Bool { (type ?? 1) == 1 }

    /// 微信读书的时间戳是秒。
    var createdDate: Date {
        guard let createTime, createTime > 0 else { return .now }
        return Date(timeIntervalSince1970: TimeInterval(createTime))
    }
}

struct ChapterDTO: Decodable, Sendable {
    let chapterUid: Int
    let chapterIdx: Int?
    let title: String?
}

/// `/review/list/mine` 的回包。
///
/// 游标是 `synckey`，与 `/user/notebooks` 的 `lastSort` 是两套，不通用。
struct ReviewPageDTO: Decodable, Sendable {
    let reviews: [ReviewDTO]?
    let totalCount: Int?
    let hasMore: Int?
    let synckey: Int?

    var hasMorePages: Bool { (hasMore ?? 0) != 0 }
}

struct ReviewDTO: Decodable, Sendable {
    let review: ReviewContentDTO
}

struct ReviewContentDTO: Decodable, Sendable {
    let reviewId: String
    let content: String?
    /// 对应划线原文。条件字段：整本书评可能没有。
    let abstract: String?
    /// 条件字段：整本书评可能没有。
    let range: String?
    let chapterUid: Int?
    let chapterIdx: Int?
    let chapterName: String?
    let createTime: Int?
    /// 0–5；-1 表示无评分。
    let star: Int?

    var createdDate: Date {
        guard let createTime, createTime > 0 else { return .now }
        return Date(timeIntervalSince1970: TimeInterval(createTime))
    }
}

/// `/shelf/sync` 的回包。本轮只用它验证 Key，不把书架灌进列表。
struct ShelfSyncDTO: Decodable, Sendable {
    let books: [ShelfBookDTO]?
}

struct ShelfBookDTO: Decodable, Sendable {
    let bookId: String?
    let title: String?
}
