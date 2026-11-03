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

    enum CodingKeys: String, CodingKey {
        case updated, chapters
    }

    init(from decoder: Decoder) throws {
        // Keep this keyed-container check strict: an array/scalar response is not a
        // valid endpoint response and must still surface as a decoding error.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updated = try container.decodeLossyArrayIfPresent(BookmarkDTO.self, forKey: .updated)
        chapters = try container.decodeLossyArrayIfPresent(ChapterDTO.self, forKey: .chapters)
    }
}

struct BookmarkDTO: Decodable, Sendable {
    let bookmarkId: String
    let chapterUid: Int
    let markText: String?
    let createTime: Int?
    let range: String?
    let colorStyle: Int?
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case bookmarkId, chapterUid, markText, createTime, range, colorStyle, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmarkId = try container.decodeRequiredStringOrNumber(forKey: .bookmarkId)
        chapterUid = try container.decodeRequiredFlexibleInt(forKey: .chapterUid)
        markText = try? container.decodeIfPresent(String.self, forKey: .markText)
        createTime = container.decodeFlexibleIntIfPresent(forKey: .createTime)
        range = try? container.decodeIfPresent(String.self, forKey: .range)
        colorStyle = container.decodeFlexibleIntIfPresent(forKey: .colorStyle)
        type = container.decodeFlexibleIntIfPresent(forKey: .type)
    }

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

    enum CodingKeys: String, CodingKey {
        case chapterUid, chapterIdx, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chapterUid = try container.decodeRequiredFlexibleInt(forKey: .chapterUid)
        chapterIdx = container.decodeFlexibleIntIfPresent(forKey: .chapterIdx)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyArrayIfPresent<T: Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> [T]? {
        guard contains(key), !((try? decodeNil(forKey: key)) ?? false) else { return nil }
        var container = try nestedUnkeyedContainer(forKey: key)
        var values: [T] = []
        while !container.isAtEnd {
            // Taking an element decoder advances the array exactly once whether
            // decoding that element succeeds or fails.
            let elementDecoder = try container.superDecoder()
            if let value = try? T(from: elementDecoder) {
                values.append(value)
            }
        }
        return values
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        guard contains(key), !((try? decodeNil(forKey: key)) ?? false) else { return nil }
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeRequiredFlexibleInt(forKey key: Key) throws -> Int {
        if let value = decodeFlexibleIntIfPresent(forKey: key) { return value }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected an integer or numeric string"
        )
    }

    func decodeRequiredStringOrNumber(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key), !value.isEmpty { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key), value.isFinite {
            if value.rounded() == value,
               value >= Double(Int.min), value <= Double(Int.max) {
                return String(Int(value))
            }
            return String(value)
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected a bookmark identifier as a string or number"
        )
    }
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
