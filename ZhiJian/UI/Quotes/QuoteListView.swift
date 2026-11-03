import SwiftUI
import SwiftData

/// 11/12/13 摘录列表（design.md 7.6）。
/// 支持搜索、筛选 chip 多选、排序。
/// 独立想法（quote == nil）作为独立条目单列。
struct QuoteListView: View {
    /// 按书筛选（从 BookDetailView「查看全部」进入时传入）。
    var filterBookId: String? = nil

    @Environment(ReadConnectionService.self) private var conn
    @State private var searchText: String = ""
    @State private var filterFavorite: Bool = false
    @State private var filterHasThoughts: Bool = false
    @State private var filterHasNotes: Bool = false
    @State private var filterBookTitle: String? = nil
    @State private var sortOrder: SortChoice = .importedDesc
    @State private var showSortSheet: Bool = false
    @State private var showBookFilter: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum SortChoice: String, CaseIterable {
        case importedDesc = "按导入时间（新→旧）"
        case importedAsc  = "按导入时间（旧→新）"
        case byTitle      = "按书名"
        case quoteTime    = "按划线时间"
    }

    // 是否有活跃筛选
    private var hasActiveFilter: Bool {
        filterFavorite || filterHasThoughts || filterHasNotes || filterBookId != nil || filterBookTitle != nil
    }

    private var activeFilterCount: Int {
        [filterFavorite, filterHasThoughts, filterHasNotes, filterBookId != nil || filterBookTitle != nil]
            .filter { $0 }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZJ.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    // 大标题 + 搜索 + chip
                    VStack(alignment: .leading, spacing: 0) {
                        Text("摘录")
                            .font(.largeTitle)
                            .foregroundStyle(ZJ.ink)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)

                        ZJSearchBar(text: $searchText, placeholder: "搜索划线、想法、备注或书名")
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        // 筛选 chip 横滑行
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "全部", isSelected: !hasActiveFilter) {
                                    clearFilters()
                                }
                                FilterChip(title: "已收藏", isSelected: filterFavorite) {
                                    filterFavorite.toggle()
                                }
                                FilterChip(title: "有想法", isSelected: filterHasThoughts) {
                                    filterHasThoughts.toggle()
                                }
                                FilterChip(title: "有备注", isSelected: filterHasNotes) {
                                    filterHasNotes.toggle()
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)
                        }
                        .padding(.top, 12)

                        // 活跃筛选提示
                        if hasActiveFilter {
                            HStack {
                                Text("已按 \(activeFilterCount) 个条件筛选")
                                    .font(.caption)
                                    .foregroundStyle(ZJ.ink3)
                                ZJTextButton(title: "清除") { clearFilters() }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // 摘录列表
                    QuoteResultList(
                        searchText: searchText,
                        filterBookId: filterBookId,
                        filterFavorite: filterFavorite,
                        filterHasThoughts: filterHasThoughts,
                        filterHasNotes: filterHasNotes,
                        sortOrder: sortOrder,
                        dynamicTypeSize: dynamicTypeSize
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSortSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 20))
                            .foregroundStyle(ZJ.accent)
                    }
                    .accessibilityLabel("排序")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSortSheet) {
                SortSheet(current: $sortOrder)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func clearFilters() {
        filterFavorite = false
        filterHasThoughts = false
        filterHasNotes = false
        filterBookTitle = nil
    }
}

// MARK: - 结果列表（独立子视图，让 @Query 使用动态谓词）

private struct QuoteResultList: View {
    let searchText: String
    let filterBookId: String?
    let filterFavorite: Bool
    let filterHasThoughts: Bool
    let filterHasNotes: Bool
    let sortOrder: QuoteListView.SortChoice
    let dynamicTypeSize: DynamicTypeSize

    // 划线列表
    @Query private var quotes: [Quote]
    // 独立想法（quote 为 nil）
    @Query private var orphanThoughts: [Thought]

    init(
        searchText: String,
        filterBookId: String?,
        filterFavorite: Bool,
        filterHasThoughts: Bool,
        filterHasNotes: Bool,
        sortOrder: QuoteListView.SortChoice,
        dynamicTypeSize: DynamicTypeSize
    ) {
        self.searchText = searchText
        self.filterBookId = filterBookId
        self.filterFavorite = filterFavorite
        self.filterHasThoughts = filterHasThoughts
        self.filterHasNotes = filterHasNotes
        self.sortOrder = sortOrder
        self.dynamicTypeSize = dynamicTypeSize

        // 构建 Quote 查询谓词
        // 注意：#Predicate 里不能直接捕获参数，必须先赋给局部 let
        let bId = filterBookId

        let sortDescriptors: [SortDescriptor<Quote>] = {
            switch sortOrder {
            case .importedDesc: return [SortDescriptor(\.createTime, order: .reverse)]
            case .importedAsc:  return [SortDescriptor(\.createTime, order: .forward)]
            case .byTitle:      return [SortDescriptor(\.bookId, order: .forward)]
            case .quoteTime:    return [SortDescriptor(\.createTime, order: .reverse)]
            }
        }()

        // 搜索必须在 Swift 侧覆盖网络字段、关系字段和本地 Annotation。
        // 不能先用只匹配 markText 的 SQL 谓词，否则书名/作者/想法/备注命中的记录
        // 会在二次过滤前就被丢掉。
        if let bId {
            _quotes = Query(filter: #Predicate<Quote> { $0.bookId == bId }, sort: sortDescriptors)
        } else {
            _quotes = Query(sort: sortDescriptors)
        }

        // 独立想法（没有关联划线）— range 为空或 range 非空但没匹配上的，统一显示
        // #Predicate 关系字段 == nil 不可靠，这里取全部然后 Swift 侧过滤
        if let bId {
            _orphanThoughts = Query(filter: #Predicate<Thought> { $0.bookId == bId })
        } else {
            _orphanThoughts = Query()
        }
    }

    /// 独立想法（Swift 侧过滤 quote == nil）
    private var filteredOrphanThoughts: [Thought] {
        guard !filterFavorite, !filterHasNotes else { return [] }
        return orphanThoughts.filter { thought in
            guard thought.quote == nil else { return false }
            guard !searchText.isEmpty else { return true }
            return thought.content.localizedStandardContains(searchText) ||
                thought.book?.title.localizedStandardContains(searchText) == true ||
                thought.book?.author.localizedStandardContains(searchText) == true
        }
    }

    /// 划线侧二次过滤（收藏、有想法、有备注）
    private var filteredQuotes: [Quote] {
        var result = quotes
        if filterFavorite {
            result = result.filter { $0.annotation?.isFavorite == true }
        }
        if filterHasThoughts {
            result = result.filter { !$0.thoughts.isEmpty }
        }
        if filterHasNotes {
            result = result.filter {
                guard let note = $0.annotation?.note else { return false }
                return !note.isEmpty
            }
        }
        if !searchText.isEmpty {
            result = result.filter { quote in
                quote.markText.localizedStandardContains(searchText) ||
                quote.thoughts.contains { $0.content.localizedStandardContains(searchText) } ||
                (quote.annotation?.note.localizedStandardContains(searchText) ?? false) ||
                (quote.annotation?.tags.contains { $0.localizedStandardContains(searchText) } ?? false) ||
                (quote.book?.title.localizedStandardContains(searchText) ?? false) ||
                (quote.book?.author.localizedStandardContains(searchText) ?? false) ||
                quote.chapterTitle.localizedStandardContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        let quotes = filteredQuotes
        let orphans = filteredOrphanThoughts

        if quotes.isEmpty && orphans.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: searchText.isEmpty ? "还没有摘录" : "没有找到相关摘录",
                message: searchText.isEmpty
                    ? "连接微信读书后，划过的线和写过的想法会出现在这里。"
                    : "换个关键词，或清除筛选条件再试试。",
                buttonTitle: searchText.isEmpty ? nil : "清除筛选",
                buttonAction: nil
            )
        } else {
            ScrollView {
                // 总数
                Text("共 \(quotes.count + orphans.count) 条")
                    .font(.footnote)
                    .foregroundStyle(ZJ.ink3)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                LazyVStack(spacing: 0) {
                    ForEach(quotes) { quote in
                        NavigationLink(destination: QuoteDetailView(quote: quote)) {
                            QuoteListRow(quote: quote, compact: dynamicTypeSize >= .accessibility2)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(orphans) { thought in
                        NavigationLink(destination: OrphanThoughtDetailView(thought: thought)) {
                            OrphanThoughtRow(thought: thought)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 划线行

private struct QuoteListRow: View {
    let quote: Quote
    let compact: Bool   // accessibility2+ 时精简显示

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuoteBlock(text: quote.markText, mode: .list)

            // 书名·章节（meta）
            Text("\(quote.book?.title ?? "") · \(quote.chapterTitle)")
                .font(.caption)
                .foregroundStyle(ZJ.ink3)
                .lineLimit(1)

            if !compact {
                // 想法折叠
                if !quote.thoughts.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                            .foregroundStyle(ZJ.ink2)
                            .accessibilityHidden(true)
                        Text("想法：\(quote.thoughts.first?.content ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(ZJ.ink2)
                            .lineLimit(1)
                    }
                }

                // 标签 + 收藏
                if let ann = quote.annotation, (ann.isFavorite || !ann.tags.isEmpty) {
                    HStack(spacing: 8) {
                        ForEach(ann.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12))
                                .foregroundStyle(ZJ.ink2)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 7))
                        }
                        Spacer()
                        if ann.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(ZJ.accent)
                                .accessibilityLabel("已收藏")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(quote.markText)，\(quote.book?.title ?? "")，\(quote.annotation?.isFavorite == true ? "已收藏" : "")")
    }
}

// MARK: - 独立想法行

private struct OrphanThoughtRow: View {
    let thought: Thought

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(thought.content)
                .font(.subheadline)
                .foregroundStyle(ZJ.ink2)
                .lineLimit(3)
            Text("独立想法 · 未关联划线 · \(thought.book?.title ?? "")")
                .font(.caption)
                .foregroundStyle(ZJ.ink3)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - 排序 Sheet

private struct SortSheet: View {
    @Binding var current: QuoteListView.SortChoice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(QuoteListView.SortChoice.allCases, id: \.self) { choice in
            Button {
                current = choice
                dismiss()
            } label: {
                HStack {
                    Text(choice.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(ZJ.ink)
                    Spacer()
                    if current == choice {
                        Image(systemName: "checkmark")
                            .foregroundStyle(ZJ.accent)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
