import SwiftUI
import SwiftData

/// 05/06/07 同步进度页（design.md 7.3）。
/// fullScreenCover，进度由 AsyncThrowingStream 驱动，主线程更新。
///
/// 四个状态：running / finished / failed / stopping（alert 确认中）。
struct SyncView: View {
    @Environment(ReadConnectionService.self) private var conn
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var phase: SyncViewPhase = .running
    @State private var progress: SyncProgress = .zero
    @State private var currentBookTitle: String = ""
    @State private var errorMessage: String = ""
    @State private var showStopAlert: Bool = false
    @State private var syncTask: Task<Void, Never>? = nil

    enum SyncViewPhase { case running, finished, failed }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题
                        Text(phaseTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(ZJ.ink)
                            .padding(.top, 20)

                        // 大数字
                        BigNumberView(
                            count: progress.importedTotal,
                            unit: "条",
                            subtitle: "划线 \(progress.importedQuotes) 条 · 想法 \(progress.importedThoughts) 条"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)

                        // 进度条
                        ZJProgressBar(
                            value: progressValue,
                            label: "导入进度",
                            percentText: "\(Int(progressValue * 100))%"
                        )
                        .padding(.top, 28)

                        // 当前书名（运行中）
                        if phase == .running {
                            VStack(alignment: .leading, spacing: 6) {
                                if !currentBookTitle.isEmpty {
                                    Text("正在读取《\(currentBookTitle)》")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink2)
                                        .accessibilityAddTraits(.updatesFrequently)
                                }
                                if progress.discoveredBooks > 0 {
                                    Text("第 \(progress.processedBooks) / \(progress.discoveredBooks) 本")
                                        .font(.footnote)
                                        .foregroundStyle(ZJ.ink3)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.top, 28)
                        }

                        // 完成态：书已整理完
                        if phase == .finished {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(ZJ.success)
                                    .accessibilityHidden(true)
                                Text("全部 \(progress.discoveredBooks) 本已整理完")
                                    .font(.body)
                                    .foregroundStyle(ZJ.success)
                            }
                            .padding(.top, 28)
                        }

                        // 失败态：原始错误
                        if phase == .failed {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("导入停在了第 \(progress.processedBooks) 本")
                                    .font(.subheadline)
                                    .foregroundStyle(ZJ.error)
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(ZJ.error)
                                        .lineSpacing(6)
                                }
                            }
                            .padding(.top, 28)
                        }

                        // 脚注
                        Text(footerText)
                            .font(.footnote)
                            .foregroundStyle(ZJ.ink3)
                            .lineSpacing(5)
                            .padding(.top, 16)

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 24)
                }

                // 底部按钮
                VStack(spacing: 8) {
                    if phase == .running {
                        ZJSecondaryButton("停止导入", icon: "xmark") {
                            showStopAlert = true
                        }
                        .padding(.horizontal, 24)
                    } else if phase == .finished {
                        ZJPrimaryButton(title: "查看书架") {
                            dismiss()
                        }
                        .padding(.horizontal, 24)
                    } else if phase == .failed {
                        ZJPrimaryButton(title: "重新尝试导入") {
                            startSync()
                        }
                        .padding(.horizontal, 24)
                        ZJSecondaryButton("返回书架") {
                            dismiss()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(ZJ.bg.ignoresSafeArea(edges: .bottom))
            }
            .background(ZJ.bg.ignoresSafeArea())
            .toolbar {
                if phase == .finished {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                            .foregroundStyle(ZJ.accent)
                    }
                }
            }
            .alert("停止这次导入？", isPresented: $showStopAlert) {
                Button("停止导入", role: .destructive) {
                    syncTask?.cancel()
                    syncTask = nil
                    dismiss()
                }
                Button("继续导入", role: .cancel) {}
            } message: {
                Text("已经整理好的 \(progress.importedTotal) 条会保留。下次重新检查并导入，不会重复保存。")
            }
            .onAppear { startSync() }
            .onDisappear { syncTask?.cancel() }
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .running: return "正在整理"
        case .finished: return "导入完成"
        case .failed: return "导入未完成"
        }
    }

    private var progressValue: Double {
        guard progress.discoveredBooks > 0 else { return phase == .finished ? 1.0 : 0.0 }
        return Double(progress.processedBooks) / Double(progress.discoveredBooks)
    }

    private var footerText: String {
        switch phase {
        case .running:
            return "导入的是划线与想法；书签只有数量，内容无法读取。"
        case .finished:
            return "下次同步只补新增内容，你写过的备注、标签和收藏都会保留。"
        case .failed:
            return "导入的是划线与想法；书签只有数量，内容无法读取。"
        }
    }

    private func startSync() {
        phase = .running
        errorMessage = ""

        syncTask = Task { @MainActor in
            do {
                let key = try conn.currentKey()
                let store = ImportStore(modelContainer: modelContext.container)
                let gateway = WeReadGateway(apiKeyProvider: { key })
                let pipeline = ImportPipeline(gateway: gateway, store: store)
                let (stream, summaryTask) = pipeline.run()

                try await withTaskCancellationHandler {
                    for try await p in stream {
                        try Task.checkCancellation()
                        self.progress = p
                    }
                    _ = try await summaryTask.value
                    try Task.checkCancellation()
                } onCancel: {
                    summaryTask.cancel()
                }
                phase = .finished
                progress.phase = .finished
            } catch is CancellationError {
                // 用户主动取消，不报错
            } catch let e as WeReadError {
                if !e.isCancellation {
                    phase = .failed
                    errorMessage = e.localizedDescription
                }
            } catch {
                phase = .failed
                errorMessage = error.localizedDescription
            }
        }
    }
}
