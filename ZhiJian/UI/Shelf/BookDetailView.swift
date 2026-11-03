import SwiftUI
import SwiftData

/// 10 书籍详情（design.md 7.5）。
/// 封面 + 统计 + 本书摘录预览 3 条。
/// /book/info 按需单本调（此处先用 notebooks 的数据，详情页留扩展位）。
struct BookDetailView: View {
    let book: Book

    @Query private var quotes: [Quote]
    @Query private var thoughts: [Thought]

    // 按此书筛选
    init(book: Book) {
        self.book = book
        let bookId = book.bookId
        _quotes = Query(
            filter: #Predicate<Quote> { $0.bookId == bookId },
            sort: \Quote.createTime,
            order: .reverse
        )
        _thoughts = Query(
            filter: #Predicate<Thought> { $0.bookId == bookId },
            sort: \Thought.createTime,
            order: .reverse
        )
    }

    private var coverURL: URL? { URL(string: book.cover) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 封面行
                HStack(alignment: .top, spacing: 16) {
                    CoverImage(
                        url: coverURL,
                        title: book.title,
                        width: 96,
                        height: 136,
                        fontSize: 36
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(book.title)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(ZJ.ink)
                            .lineLimit(3)
                        Text(book.author)
                            .font(.body)
                            .foregroundStyle(ZJ.ink2)
                            .padding(.top, 4)

                        Spacer().frame(height: 18)

                        Text("阅读进度 \(book.readingProgress)%")
                            .font(.caption)
                            .foregroundStyle(ZJ.ink3)
                            .monospacedDigit()
                        ZJProgressBar(
                            value: Double(book.readingProgress) / 100.0,
                            label: "",
                            percentText: ""
                        )
                        .frame(width: 150)
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // 三列统计
                HStack(spacing: 0) {
                    StatColumn(value: book.highlightCount, label: "划线")
                    StatColumn(value: book.reviewCount, label: "想法")
                    StatColumn(value: book.bookmarkCount, label: "书签")
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)

                // 书签说明（必须有）
                Text("书签只有数量，内容无法导入。")
                    .font(.caption)
                    .foregroundStyle(ZJ.ink3)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // 本书摘录预览
                HStack {
                    Text("本书摘录")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(ZJ.ink)
                    Spacer()
                    NavigationLink(destination: QuoteListView(filterBookId: book.bookId)) {
                        Text("查看全部")
                            .font(.subheadline)
                            .foregroundStyle(ZJ.accent)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)

                if quotes.isEmpty && thoughts.isEmpty {
                    Text("这本书还没有可展示的摘录。")
                        .font(.subheadline)
                        .foregroundStyle(ZJ.ink2)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 0) {
                        // 最多展示 3 条划线
                        ForEach(Array(quotes.prefix(3))) { quote in
                            NavigationLink(destination: QuoteDetailView(quote: quote)) {
                                QuotePreviewRow(quote: quote)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer().frame(height: 32)
            }
        }
        .background(ZJ.bg.ignoresSafeArea())
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // 重新导入此书（未来扩展）
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(ZJ.accent)
                }
                .accessibilityLabel("重新导入")
            }
        }
    }
}

private struct StatColumn: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(ZJ.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(ZJ.ink3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) 条\(label)")
    }
}

private struct QuotePreviewRow: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuoteBlock(text: quote.markText, mode: .list)

            HStack {
                // 章节 + 日期
                Text("\(quote.chapterTitle.isEmpty ? "无章节" : quote.chapterTitle)")
                    .font(.caption)
                    .foregroundStyle(ZJ.ink3)
                    .lineLimit(1)
                Spacer()
                Text(quote.createTime.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(ZJ.ink3)
                    .monospacedDigit()
            }

            // 想法折叠摘要
            if !quote.thoughts.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                        .foregroundStyle(ZJ.ink2)
                        .accessibilityHidden(true)
                    Text("想法 \(quote.thoughts.count) 条 · \(quote.thoughts.first?.content ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(ZJ.ink2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
