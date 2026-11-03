import SwiftUI

/// 01 连接介绍页（design.md 7.1）。
/// 引导流程根：右上角「跳过」→ 直接 dismiss 进 TabView（未连接态）；
/// 底部「开始连接」→ push KeyInputView。
struct OnboardingView: View {
    @Environment(ReadConnectionService.self) private var conn
    @Environment(\.dismiss) private var dismiss
    @State private var showKeyInput = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 眉标
                        Text("纸 间")
                            .font(.system(.caption, weight: .semibold))
                            .kerning(2)
                            .foregroundStyle(ZJ.accent)
                            .padding(.top, 20)

                        // 大标题
                        Text("把划过的线，收进纸间")
                            .font(.largeTitle)
                            .foregroundStyle(ZJ.ink)
                            .padding(.top, 10)

                        // 副标题
                        Text("让值得记住的文字，在纸间留下痕迹。")
                            .font(.body)
                            .foregroundStyle(ZJ.ink2)
                            .lineSpacing(7)
                            .padding(.top, 12)

                        // 三条功能说明
                        VStack(alignment: .leading, spacing: 0) {
                            FeatureRow(
                                icon: "quote.bubble",
                                title: "收集划线与想法",
                                description: "把你在微信读书里划过的线、写过的想法，整理到一处。"
                            )
                            FeatureRow(
                                icon: "iphone",
                                title: "保存在这台设备",
                                description: "不需要账号，内容只留在本机，随时回看。"
                            )
                            FeatureRow(
                                icon: "note.text",
                                title: "可以慢慢整理",
                                description: "搜索、筛选，再补上备注、标签和收藏。"
                            )
                        }
                        .padding(.top, 32)

                        // 说明块（Ato 确认的 Key 获取地址：https://weread.qq.com/r/weread-skills）
                        VStack(alignment: .leading, spacing: 6) {
                            Text("连接需要一个 API Key")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ZJ.ink)
                            Text("纸间用它读取你自己的划线与想法。Key 由你在微信读书官方提供的技能接口中获取（") +
                            Text("[weread.qq.com/r/weread-skills](https://weread.qq.com/r/weread-skills)")
                                .foregroundStyle(ZJ.accent) +
                            Text("），以 wrk- 开头；Key 只保存在这台设备的钥匙串里，不会写进代码。连接验证和读取划线、想法时，纸间会把 Key 发送给微信读书接口。下一步带你粘贴并验证。")
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(ZJ.ink2)
                        .lineSpacing(6)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.top, 24)

                        // 底部按钮区域占位
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 24)
                }

                // 底部主按钮（固定）
                VStack(spacing: 0) {
                    ZJPrimaryButton(title: "开始连接") {
                        showKeyInput = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .background(ZJ.bg.ignoresSafeArea(edges: .bottom))
                }
            }
            .background(ZJ.bg.ignoresSafeArea())
            .navigationDestination(isPresented: $showKeyInput) {
                KeyInputView()
                    .environment(conn)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("跳过") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(ZJ.accent)
                    .accessibilityLabel("跳过连接介绍")
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(ZJ.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ZJ.ink)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(ZJ.ink2)
                    .lineSpacing(6)
            }
        }
        .padding(.vertical, 14)
    }
}
