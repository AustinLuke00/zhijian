import SwiftUI
import SwiftData

/// 14 摘录详情（design.md 7.7）。
/// 原文 + 多条想法（逐条展开）+ 备注 + 标签 + 收藏。
/// 备注/标签/收藏写到 QuoteAnnotation，绝不碰 Quote。
struct QuoteDetailView: View {
    let quote: Quote
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""
    @State private var tagInput: String = ""
    @State private var showTagEditor: Bool = false
    @State private var saveError: String? = nil
    @State private var showSavedHint: Bool = false
    @State private var saveHintTask: Task<Void, Never>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var annotation: QuoteAnnotation? {
        quote.annotation
    }

    private var isFavorite: Bool {
        annotation?.isFavorite ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 元信息
                Text("\(quote.book?.title ?? "") · \(quote.chapterTitle) · \(quote.createTime.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(ZJ.ink3)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // 引用块（不截断）
                QuoteBlock(text: quote.markText, mode: .detail)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                // 想法区块
                VStack(alignment: .leading, spacing: 0) {
                    Text("想法 · \(quote.thoughts.count) 条")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(ZJ.ink)
                        .padding(.horizontal, 24)
                        .padding(.top, 30)

                    if quote.thoughts.isEmpty {
                        Text("这条划线还没有想法。")
                            .font(.subheadline)
                            .foregroundStyle(ZJ.ink2)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else {
                        ForEach(Array(quote.thoughts.enumerated()), id: \.offset) { idx, thought in
                            ThoughtItem(index: idx + 1, thought: thought)
                        }
                    }
                }

                // 备注区块
                VStack(alignment: .leading, spacing: 6) {
                    Text("备注")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(ZJ.ink)

                    ZStack(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("写点备注…")
                                .font(.subheadline)
                                .foregroundStyle(ZJ.ink3)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                        TextEditor(text: $noteText)
                            .font(.subheadline)
                            .foregroundStyle(ZJ.ink2)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 76)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .onChange(of: noteText) { _, _ in saveNote() }
                    }
                    .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("备注，可编辑")

                    if let err = saveError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(ZJ.error)
                    }

                    if showSavedHint {
                        Text("已保存")
                            .font(.caption)
                            .foregroundStyle(ZJ.success)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                // 标签区块
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(ZJ.ink)

                    FlowLayout {
                        ForEach(annotation?.tags ?? [], id: \.self) { tag in
                            TagChip(label: tag) {
                                removeTag(tag)
                            }
                        }
                        Button {
                            tagInput = ""
                            showTagEditor = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13))
                                Text("添加标签")
                                    .font(.system(size: 13))
                            }
                            .foregroundStyle(ZJ.accent)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(ZJ.border, style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                        }
                        .accessibilityLabel("添加标签")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)

                Spacer().frame(height: 32)
            }
        }
        .background(ZJ.bg.ignoresSafeArea())
        .navigationTitle("摘录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 21))
                        .foregroundStyle(isFavorite ? ZJ.accent : ZJ.ink3)
                }
                .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
            }
        }
        .sheet(isPresented: $showTagEditor) {
            NavigationStack {
                Form {
                    TextField("标签名称", text: $tagInput)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(addTag)
                }
                .navigationTitle("添加标签")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showTagEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("添加", action: addTag)
                            .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            noteText = annotation?.note ?? ""
        }
    }

    // MARK: - 操作

    private func ensureAnnotation() -> QuoteAnnotation {
        if let ann = quote.annotation { return ann }
        let ann = QuoteAnnotation(quoteId: quote.bookmarkId)
        ann.quote = quote
        quote.annotation = ann
        modelContext.insert(ann)
        return ann
    }

    private func saveNote() {
        saveError = nil
        let ann = ensureAnnotation()
        ann.note = noteText
        ann.updatedAt = .now
        do {
            try modelContext.save()
            flashSavedHint()
        } catch {
            saveError = "没能保存，请重试。"
        }
    }

    private func toggleFavorite() {
        let ann = ensureAnnotation()
        ann.isFavorite.toggle()
        ann.updatedAt = .now
        saveAnnotation()
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        let ann = ensureAnnotation()
        if !ann.tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
            ann.tags.append(tag)
            ann.updatedAt = .now
            saveAnnotation()
        }
        showTagEditor = false
    }

    private func removeTag(_ tag: String) {
        let ann = ensureAnnotation()
        ann.tags.removeAll { $0 == tag }
        ann.updatedAt = .now
        saveAnnotation()
    }

    private func saveAnnotation() {
        do {
            try modelContext.save()
            saveError = nil
            flashSavedHint()
        } catch {
            saveError = "没能保存，请重试。"
        }
    }

    private func flashSavedHint() {
        saveHintTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) {
            showSavedHint = true
        }
        saveHintTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                showSavedHint = false
            }
        }
    }
}

// MARK: - 想法条目

private struct ThoughtItem: View {
    let index: Int
    let thought: Thought

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("想法 \(index)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ZJ.accent)
            Text(thought.content)
                .font(.body)
                .foregroundStyle(ZJ.ink2)
                .lineSpacing(6)
            Text(thought.createTime.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(ZJ.ink3)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }
}

// MARK: - 标签 Chip（可删除）

private struct TagChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ZJ.ink2)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(ZJ.ink3)
            }
            .accessibilityLabel("删除标签 \(label)")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
        .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - 独立想法详情

/// 没有关联划线的想法详情（独立想法版式，design.md 7.7）。
struct OrphanThoughtDetailView: View {
    let thought: Thought
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 元信息
                Text("独立想法 · 未关联划线 · \(thought.book?.title ?? "")")
                    .font(.caption)
                    .foregroundStyle(ZJ.ink3)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // 想法正文（比关联想法更重，因为它本身就是主体）
                Text(thought.content)
                    .font(.body)
                    .foregroundStyle(ZJ.ink)
                    .lineSpacing(7)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                Text(thought.createTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(ZJ.ink3)
                    .monospacedDigit()
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer().frame(height: 32)
            }
        }
        .background(ZJ.bg.ignoresSafeArea())
        .navigationTitle("摘录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FlowLayout（标签自动换行）

/// 简单的流式布局，让标签自动换行。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX)
        }
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
