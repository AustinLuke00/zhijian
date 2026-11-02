import Foundation
import SwiftData
import Testing

@testable import ZhiJian

/// 模型层测试。重点不是“能存能取”，而是 brief 决定 1、2、4、5 这四条
/// 一旦违反就会**静默**丢用户数据的规则。
@MainActor
struct QuoteModelTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeInMemoryContainer()
    }

    // MARK: - 决定 1：同步不覆盖用户数据

    /// 最重要的一条测试。
    /// 用户写了备注、加了标签、标了收藏，再同步一次——这些必须还在。
    @Test
    func resyncDoesNotOverwriteAnnotation() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let book = Book(bookId: "b1", title: "书", author: "作者", cover: "")
        context.insert(book)
        let quote = Quote(
            bookmarkId: "bm1",
            bookId: "b1",
            chapterUid: 1,
            markText: "原文",
            range: "10-20",
            createTime: Date()
        )
        quote.book = book
        context.insert(quote)

        let annotation = QuoteAnnotation(quoteId: "bm1", note: "我的想法", tags: ["重要"], isFavorite: true)
        annotation.quote = quote
        quote.annotation = annotation
        context.insert(annotation)
        try context.save()

        // 跑一次“同步”：模拟管线对同一条划线的二次写入
        let store = ImportStore(modelContainer: container)
        let counts = try await store.persist(
            book: BookPayload(
                bookId: "b1", title: "书（新版标题）", author: "作者", cover: "",
                highlightCount: 5, reviewCount: 2, bookmarkCount: 1,
                readingProgress: 30, isFinished: false
            ),
            quotes: [QuotePayload(
                bookmarkId: "bm1", bookId: "b1", chapterUid: 1,
                chapterTitle: "第一章", chapterIdx: 0,
                markText: "原文", range: "10-20", colorStyle: 1,
                createTime: Date(), source: .weread
            )],
            thoughts: []
        )

        // 已有划线不重复计数
        #expect(counts.quotes == 0)

        let descriptor = FetchDescriptor<QuoteAnnotation>()
        let annotations = try context.fetch(descriptor)
        #expect(annotations.count == 1)
        #expect(annotations.first?.note == "我的想法")
        #expect(annotations.first?.tags == ["重要"])
        #expect(annotations.first?.isFavorite == true)

        // 网络侧字段确实被更新了（同步不是完全没干活）
        let quoteDescriptor = FetchDescriptor<Quote>()
        let quotes = try context.fetch(quoteDescriptor)
        #expect(quotes.count == 1)
        #expect(quotes.first?.chapterTitle == "第一章")
    }

    // MARK: - 决定 2：幂等

    /// 同一个 bookmarkId 写两次，只能有一条。
    @Test
    func duplicateBookmarkIdIsNotDuplicated() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let payload = QuotePayload(
            bookmarkId: "bm1", bookId: "b1", chapterUid: 1,
            chapterTitle: "", chapterIdx: 0, markText: "原文",
            range: "10-20", colorStyle: 0, createTime: Date(), source: .weread
        )
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 1, reviewCount: 0, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )

        let first = try await store.persist(book: book, quotes: [payload], thoughts: [])
        #expect(first.quotes == 1)

        let second = try await store.persist(book: book, quotes: [payload], thoughts: [])
        #expect(second.quotes == 0)

        let context = ModelContext(container)
        let quotes = try context.fetch(FetchDescriptor<Quote>())
        #expect(quotes.count == 1)

        let books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1)
    }

    /// 想法同理：同一个 reviewId 只入一次。
    @Test
    func duplicateReviewIdIsNotDuplicated() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 0, reviewCount: 1, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )
        let thought = ThoughtPayload(
            reviewId: "r1", bookId: "b1", content: "想法",
            abstract: "原文", range: "10-20", chapterUid: 1,
            chapterTitle: "第一章", chapterIdx: 0, createTime: Date(), star: -1
        )

        #expect(try await store.persist(book: book, quotes: [], thoughts: [thought]).thoughts == 1)
        #expect(try await store.persist(book: book, quotes: [], thoughts: [thought]).thoughts == 0)
    }

    // MARK: - 决定 5：三元组配对

    /// range 对上就挂上去。
    @Test
    func thoughtLinksToQuoteByTriple() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 1, reviewCount: 1, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )
        _ = try await store.persist(
            book: book,
            quotes: [QuotePayload(
                bookmarkId: "bm1", bookId: "b1", chapterUid: 7,
                chapterTitle: "第七章", chapterIdx: 0, markText: "原文",
                range: "2959-3007", colorStyle: 0, createTime: Date(), source: .weread
            )],
            thoughts: [ThoughtPayload(
                reviewId: "r1", bookId: "b1", content: "我的点评",
                abstract: "原文", range: "2959-3007", chapterUid: 7,
                chapterTitle: "第七章", chapterIdx: 0, createTime: Date(), star: -1
            )]
        )

        let context = ModelContext(container)
        let thoughts = try context.fetch(FetchDescriptor<Thought>())
        #expect(thoughts.count == 1)
        #expect(thoughts.first?.quote?.bookmarkId == "bm1")
    }

    /// chapterUid 不同，即使 range 一样也不能乱配。
    @Test
    func mismatchedChapterDoesNotLink() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 1, reviewCount: 1, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )
        _ = try await store.persist(
            book: book,
            quotes: [QuotePayload(
                bookmarkId: "bm1", bookId: "b1", chapterUid: 7,
                chapterTitle: "", chapterIdx: 0, markText: "原文",
                range: "2959-3007", colorStyle: 0, createTime: Date(), source: .weread
            )],
            thoughts: [ThoughtPayload(
                reviewId: "r1", bookId: "b1", content: "整本书评",
                abstract: "", range: "2959-3007", chapterUid: 9,
                chapterTitle: "", chapterIdx: 0, createTime: Date(), star: -1
            )]
        )

        let context = ModelContext(container)
        let thoughts = try context.fetch(FetchDescriptor<Thought>())
        #expect(thoughts.first?.quote == nil)
    }

    /// 整本书评没有 range → 不丢弃，单独成条。
    @Test
    func thoughtWithoutRangeIsKeptUnlinked() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 0, reviewCount: 1, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )
        let counts = try await store.persist(
            book: book,
            quotes: [],
            thoughts: [ThoughtPayload(
                reviewId: "r1", bookId: "b1", content: "这本书很好",
                abstract: "", range: "", chapterUid: 0,
                chapterTitle: "", chapterIdx: 0, createTime: Date(), star: 5
            )]
        )

        #expect(counts.thoughts == 1)
        let context = ModelContext(container)
        let thoughts = try context.fetch(FetchDescriptor<Thought>())
        #expect(thoughts.count == 1)
        #expect(thoughts.first?.quote == nil)
        #expect(thoughts.first?.content == "这本书很好")
    }

    /// 一条划线挂多条想法（一对多，不是一对一）。
    @Test
    func oneQuoteCanHoldManyThoughts() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 1, reviewCount: 2, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )
        _ = try await store.persist(
            book: book,
            quotes: [QuotePayload(
                bookmarkId: "bm1", bookId: "b1", chapterUid: 3,
                chapterTitle: "", chapterIdx: 0, markText: "原文",
                range: "1-9", colorStyle: 0, createTime: Date(), source: .weread
            )],
            thoughts: [
                ThoughtPayload(
                    reviewId: "r1", bookId: "b1", content: "第一次想法",
                    abstract: "原文", range: "1-9", chapterUid: 3,
                    chapterTitle: "", chapterIdx: 0, createTime: Date(), star: -1
                ),
                ThoughtPayload(
                    reviewId: "r2", bookId: "b1", content: "第二次想法",
                    abstract: "原文", range: "1-9", chapterUid: 3,
                    chapterTitle: "", chapterIdx: 0, createTime: Date(), star: -1
                )
            ]
        )

        let context = ModelContext(container)
        let quotes = try context.fetch(FetchDescriptor<Quote>())
        #expect(quotes.count == 1)
        #expect(quotes.first?.thoughts.count == 2)
    }

    // MARK: - 决定 4：级联

    /// 删书 → 划线和想法一起没了。
    @Test
    func deletingBookCascades() async throws {
        let container = try makeContainer()
        let store = ImportStore(modelContainer: container)
        let book = BookPayload(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 1, reviewCount: 1, bookmarkCount: 0,
            readingProgress: 0, isFinished: false
        )
        _ = try await store.persist(
            book: book,
            quotes: [QuotePayload(
                bookmarkId: "bm1", bookId: "b1", chapterUid: 1,
                chapterTitle: "", chapterIdx: 0, markText: "原文",
                range: "1-9", colorStyle: 0, createTime: Date(), source: .weread
            )],
            thoughts: [ThoughtPayload(
                reviewId: "r1", bookId: "b1", content: "想法",
                abstract: "", range: "1-9", chapterUid: 1,
                chapterTitle: "", chapterIdx: 0, createTime: Date(), star: -1
            )]
        )

        let context = ModelContext(container)
        let books = try context.fetch(FetchDescriptor<Book>())
        let target = try #require(books.first)
        context.delete(target)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Quote>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Thought>()).isEmpty)
    }

    // MARK: - 计数口径

    /// 导入量只算划线 + 想法，不含书签。
    @Test
    func importableCountExcludesBookmarks() {
        let book = Book(
            bookId: "b1", title: "书", author: "作者", cover: "",
            highlightCount: 10, reviewCount: 4, bookmarkCount: 3,
            readingProgress: 0, isFinished: false
        )
        #expect(book.totalNoteCount == 17)
        #expect(book.importableCount == 0)
    }
}
