import Foundation

/// DTO → 写入载荷的映射。
///
/// 集中放在一个地方，是为了让“字段名怎么解读”只有一处答案：
/// `markedStatus == 1` 才算读完、`createTime` 是秒级时间戳、
/// `noteCount` 是划线条数而不是总笔记数——这些判断都不该散落在管线里。
enum DTOMapper {

    // MARK: - 有笔记的书

    static func bookPayload(from dto: NotebookBookDTO) -> BookPayload {
        BookPayload(
            bookId: dto.bookId,
            title: dto.resolvedTitle,
            author: dto.resolvedAuthor,
            cover: dto.resolvedCover,
            // noteCount = 划线条数，不是总笔记数（速查表明确提醒）
            highlightCount: dto.noteCount ?? 0,
            reviewCount: dto.reviewCount ?? 0,
            bookmarkCount: dto.bookmarkCount ?? 0,
            readingProgress: normalizedProgress(dto.readingProgress),
            isFinished: dto.markedStatus == 1
        )
    }

    /// `progress` 是 0–100 的整数。越界值钳回去，免得进度条画飞。
    static func normalizedProgress(_ raw: Int?) -> Int {
        guard let raw else { return 0 }
        return min(max(raw, 0), 100)
    }

    // MARK: - 划线

    static func quotePayloads(
        from dto: BookmarkListDTO,
        bookId: String
    ) -> [QuotePayload] {
        let chapterTitles = chapterTitleIndex(dto.chapters)
        return (dto.updated ?? [])
            // 接口已过滤书签，这里是双保险：只认 type=1
            .filter(\.isHighlight)
            .map { bookmark in
                QuotePayload(
                    bookmarkId: bookmark.bookmarkId,
                    bookId: bookId,
                    chapterUid: bookmark.chapterUid,
                    chapterTitle: chapterTitles[bookmark.chapterUid] ?? "",
                    chapterIdx: 0,
                    markText: bookmark.markText ?? "",
                    range: bookmark.range ?? "",
                    colorStyle: bookmark.colorStyle ?? 0,
                    createTime: bookmark.createdDate,
                    source: .weread
                )
            }
    }

    private static func chapterTitleIndex(_ chapters: [ChapterDTO]?) -> [Int: String] {
        guard let chapters else { return [:] }
        var index: [Int: String] = [:]
        for chapter in chapters {
            index[chapter.chapterUid] = chapter.title ?? ""
        }
        return index
    }

    // MARK: - 想法

    static func thoughtPayloads(
        from dto: ReviewPageDTO,
        bookId: String
    ) -> [ThoughtPayload] {
        (dto.reviews ?? []).map { wrapper in
            let review = wrapper.review
            return ThoughtPayload(
                reviewId: review.reviewId,
                bookId: bookId,
                content: review.content ?? "",
                // abstract / range 是条件字段，整本书评可能为空
                abstract: review.abstract ?? "",
                range: review.range ?? "",
                chapterUid: review.chapterUid ?? 0,
                chapterTitle: review.chapterName ?? "",
                chapterIdx: review.chapterIdx ?? 0,
                createTime: review.createdDate,
                star: review.star ?? -1
            )
        }
    }
}
