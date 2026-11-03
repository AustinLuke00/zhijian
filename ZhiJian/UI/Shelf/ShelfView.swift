import SwiftUI
import SwiftData

/// 拟物木质书架。数据仅来自 notebooks 入库后且确有划线或想法的书。
struct ShelfView: View {
    @Environment(ReadConnectionService.self) private var conn
    @Query(sort: \Book.title) private var storedBooks: [Book]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showConnection = false
    @State private var showSync = false

    private var books: [Book] {
        storedBooks.filter { $0.highlightCount > 0 || $0.reviewCount > 0 }
    }

    private var booksPerShelf: Int {
        dynamicTypeSize >= .accessibility2 ? 4 : 5
    }

    private var shelves: [[Book]] {
        stride(from: 0, to: books.count, by: booksPerShelf).map { start in
            Array(books[start ..< min(start + booksPerShelf, books.count)])
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                countHeader

                if books.isEmpty {
                    ShelfEmptyState(action: primaryAction)
                } else {
                    SkeuomorphicShelfView(shelves: shelves)
                }
            }
            .background(ShelfPalette.page.ignoresSafeArea())
            .toolbarBackground(ShelfPalette.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("书架")
                        .font(.headline)
                        .foregroundStyle(ShelfPalette.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("同步", action: primaryAction)
                        .font(.body)
                        .foregroundStyle(ShelfPalette.accent)
                        .accessibilityHint(conn.isConnected ? "重新导入微信读书笔记" : "连接微信读书并导入笔记")
                }
            }
            .sheet(isPresented: $showConnection) { OnboardingView() }
            .fullScreenCover(isPresented: $showSync) { SyncView() }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var countHeader: some View {
        Text("\(books.count) 本有笔记的书")
            .font(.footnote)
            .foregroundStyle(ShelfPalette.ink2)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(ShelfPalette.page)
    }

    private func primaryAction() {
        if conn.isConnected { showSync = true } else { showConnection = true }
    }
}

/// 可滚动书柜；导航栏与 Tab 栏留在木质内容区之外。
private struct SkeuomorphicShelfView: View {
    let shelves: [[Book]]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(shelves.enumerated()), id: \.offset) { _, books in
                    ShelfRow(books: books)
                }
            }
        }
        .background(WoodBackboard())
    }
}

private struct ShelfRow: View {
    let books: [Book]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        ShelfBook(book: book)
                    }
                    .buttonStyle(ShelfPressStyle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(book.title)，\(book.author)，划线 \(book.highlightCount) 条，想法 \(book.reviewCount) 条")
                    .accessibilityHint("打开书籍详情")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 142, alignment: .bottom)

            ShelfPlank()

            // 层板下的暗部也提供下一层书本所需的视觉纵深。
            Color.black.opacity(0.34)
                .frame(height: 16)
                .accessibilityHidden(true)
        }
    }
}

private struct ShelfBook: View {
    let book: Book

    private var coverURL: URL? {
        guard !book.cover.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: book.cover)
    }

    /// 稳定的小幅高度变化，不因刷新或列表重排跳动。
    private var height: CGFloat { CGFloat(74 + StableBookHash.value(book.title, modulo: 11)) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 3pt 书脊厚度：高光边与深色侧面。
            Rectangle()
                .fill(Color.white.opacity(0.48))
                .frame(width: 1, height: height - 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.black.opacity(0.24))
                .frame(width: 3, height: height - 1)
                .frame(maxWidth: .infinity, alignment: .leading)

            StableCoverImage(url: coverURL, title: book.title, height: height)
                .padding(.leading, 3)

            // 底部纸页边。
            Rectangle()
                .fill(Color.white.opacity(0.56))
                .frame(width: 49, height: 2)
        }
        .frame(width: 52, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.28), radius: 5, x: 2, y: 3)
        .frame(width: 52, height: 88, alignment: .bottom)
        .contentShape(Rectangle())
    }
}

private struct StableCoverImage: View {
    let url: URL?
    let title: String
    let height: CGFloat

    private var placeholderColor: Color {
        ShelfPalette.placeholderColors[StableBookHash.value(title, modulo: ShelfPalette.placeholderColors.count)]
    }

    private var initial: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map(String.init) ?? "书"
    }

    var body: some View {
        ZStack {
            placeholderColor
            Text(initial)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.white.opacity(0.92))
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)

            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear // 加载与失败始终露出稳定首字占位，不闪白。
                    }
                }
            }
        }
        .frame(width: 49, height: height)
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct ShelfPlank: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [ShelfPalette.plankTop, ShelfPalette.plankMiddle, ShelfPalette.plankBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(ShelfPalette.plankHighlight)
                .frame(height: 2)
            VStack(spacing: 5) {
                Color.clear.frame(height: 7)
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
            }
        }
        .frame(height: 24)
        .shadow(color: .black.opacity(0.50), radius: 12, y: 4)
        .accessibilityHidden(true)
    }
}

private struct WoodBackboard: View {
    var body: some View {
        ZStack {
            ShelfPalette.backboard
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    Spacer()
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.025) : Color.black.opacity(0.11))
                        .frame(height: CGFloat(1 + index % 3))
                }
                Spacer()
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ShelfEmptyState: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            WoodBackboard()
                .frame(height: 92)
                .overlay(alignment: .bottom) { ShelfPlank() }

            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .foregroundStyle(ShelfPalette.ink3)
                    .accessibilityHidden(true)
                Text("还没有导入带笔记的书")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ShelfPalette.ink)
                    .multilineTextAlignment(.center)
                Button("立即连接并导入", action: action)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(ShelfPalette.accent, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 12)
                    .accessibilityHint("连接或同步微信读书笔记")
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ShelfPalette.page)
        }
    }
}

private struct ShelfPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed && !reduceMotion ? -3 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private enum StableBookHash {
    static func value(_ text: String, modulo: Int) -> Int {
        guard modulo > 0 else { return 0 }
        // FNV-1a：与进程随机化无关，重启后仍使用同一占位色和高度。
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(modulo))
    }
}

/// 书架专属局部颜色，避免改变并行开发中的全局 Theme。
private enum ShelfPalette {
    static let page = Color(light: 0xF8F8F4, dark: 0x1A1916)
    static let ink = Color(light: 0x2B2723, dark: 0xF2ECE1)
    static let ink2 = Color(light: 0x6E665C, dark: 0xB4AA9C)
    static let ink3 = Color(light: 0x6F675B, dark: 0x9C9386)
    static let accent = Color(light: 0x8A5A3B, dark: 0xC9966E)

    static let backboard = Color(light: 0x1E1209, dark: 0x0A0806)
    static let plankTop = Color(light: 0xD4A472, dark: 0xA07040)
    static let plankMiddle = Color(light: 0xC08040, dark: 0x7A5020)
    static let plankBottom = Color(light: 0x7A4D20, dark: 0x4A2E0C)
    static let plankHighlight = Color(light: 0xE8C090, dark: 0xA07040)

    static let placeholderColors: [Color] = [
        Color(hex: 0x7B4B2A), Color(hex: 0x4A7B6B), Color(hex: 0x3A5E8A),
        Color(hex: 0x7B6B3A), Color(hex: 0x6B4A7B), Color(hex: 0x8A3A40),
        Color(hex: 0x4B7B4B), Color(hex: 0x5A6B7B), Color(hex: 0x7B5A2A)
    ]
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
