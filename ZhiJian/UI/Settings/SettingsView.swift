import SwiftUI
import SwiftData

/// 15 设置页（design.md 7.8）。
/// ScrollView，MadeWithAirBuild(.compact) 在最底部。
struct SettingsView: View {
    @Environment(ReadConnectionService.self) private var conn
    @Environment(\.modelContext) private var modelContext
    @State private var showConnection = false
    @State private var showDisconnectAlert: Bool = false
    @Query private var allQuotes: [Quote]
    @Query private var allThoughts: [Thought]

    private var totalImported: Int { allQuotes.count + allThoughts.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("设置")
                        .font(.largeTitle)
                        .foregroundStyle(ZJ.ink)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    // 分组 1：微信读书连接
                    SettingsGroup {
                        if conn.isConnected {
                            // 已连接态
                            SettingsRow {
                                HStack(spacing: 8) {
                                    Text("微信读书")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink)
                                    Spacer()
                                    ConnectionDot(isConnected: true)
                                    Text("已连接")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink3)
                                }
                            }
                            Divider().background(ZJ.border)
                            NavigationLink(destination: KeyInputView().environment(conn)) {
                                HStack {
                                    Text("API Key")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink)
                                    Spacer()
                                    Text("wrk-••••••••")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(ZJ.ink3)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                        .foregroundStyle(ZJ.ink3)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().background(ZJ.border)
                            SettingsRow {
                                HStack {
                                    Text("重新导入（暂不可用，请从书架同步）")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink)
                                    Spacer()
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 18))
                                        .foregroundStyle(ZJ.ink3)
                                }
                            }
                        } else {
                            // 断开态
                            SettingsRow {
                                HStack(spacing: 8) {
                                    Text("微信读书")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink)
                                    ConnectionDot(isConnected: false)
                                    Text("已断开")
                                        .font(.body)
                                        .foregroundStyle(ZJ.ink3)
                                    Spacer()
                                }
                            }
                            Divider().background(ZJ.border)
                            Button { showConnection = true } label: {
                                HStack {
                                    Text("连接微信读书")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(ZJ.accent)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                        .foregroundStyle(ZJ.accent)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 20)

                    // 分组标题：数据
                    Text("数据")
                        .font(.caption)
                        .foregroundStyle(ZJ.ink3)
                        .padding(.horizontal, 40)
                        .padding(.top, 18)
                        .padding(.bottom, 6)

                    // 分组 2：数据
                    SettingsGroup {
                        SettingsRow {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock")
                                            .font(.system(size: 19))
                                            .foregroundStyle(ZJ.ink3)
                                            .accessibilityHidden(true)
                                        Text("保存在这台设备")
                                            .font(.body)
                                            .foregroundStyle(ZJ.ink)
                                    }
                                    Text("不需要账号；内容、备注、标签和收藏都留在本机。")
                                        .font(.caption)
                                        .foregroundStyle(ZJ.ink3)
                                        .lineSpacing(4)
                                }
                                Spacer()
                            }
                        }
                        Divider().background(ZJ.border)
                        SettingsRow {
                            HStack {
                                Text("已整理内容")
                                    .font(.body)
                                    .foregroundStyle(ZJ.ink)
                                Spacer()
                                Text("\(totalImported) 条")
                                    .font(.body)
                                    .foregroundStyle(ZJ.ink3)
                                    .monospacedDigit()
                            }
                        }
                    }

                    // 分组标题：关于
                    Text("关于")
                        .font(.caption)
                        .foregroundStyle(ZJ.ink3)
                        .padding(.horizontal, 40)
                        .padding(.top, 18)
                        .padding(.bottom, 6)

                    // 分组 3：关于
                    SettingsGroup {
                        SettingsRow {
                            HStack {
                                Text("纸间")
                                    .font(.body)
                                    .foregroundStyle(ZJ.ink)
                                Spacer()
                                Text("版本 1.0")
                                    .font(.body)
                                    .foregroundStyle(ZJ.ink3)
                            }
                        }

                        if conn.isConnected {
                            Divider().background(ZJ.border)
                            // 断开连接（破坏性，error 色）
                            Button {
                                showDisconnectAlert = true
                            } label: {
                                HStack {
                                    Text("断开连接")
                                        .font(.body)
                                        .foregroundStyle(ZJ.error)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel("断开连接，会清除 API Key 但保留摘录")
                        }
                    }

                    // MadeWithAirBuild：ScrollView 里用 .compact 变体
                    MadeWithAirBuild(.compact)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 22)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
            }
            .background(ZJ.bg.ignoresSafeArea())
            .sheet(isPresented: $showConnection) { OnboardingView() }
            .navigationBarTitleDisplayMode(.inline)
            .alert("断开微信读书连接？", isPresented: $showDisconnectAlert) {
                Button("断开连接", role: .destructive) {
                    conn.disconnect()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会清除这台设备上保存的 API Key。已经整理好的摘录、备注、标签和收藏都会保留，随时可以重新连接。")
            }
        }
    }
}

// MARK: - 分组容器

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ZJ.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 行容器

private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
    }
}
