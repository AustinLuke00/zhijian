import SwiftUI

/// 02/03/04 Key 输入页（design.md 7.2）。
/// idle → 验证中 → 成功（push SyncView）/ 失败（内联错误 + 重试）。
///
/// 易错点：
/// - Key 永不回显全量：成功/失败后显示掩码。
/// - 禁止重复提交：验证中禁用所有交互。
/// - 错误行不弹窗，内联在输入框下方（.accessibilityLiveRegion 等价）。
struct KeyInputView: View {
    @Environment(ReadConnectionService.self) private var conn
    @Environment(\.dismiss) private var dismiss

    @State private var rawKey: String = ""
    @State private var phase: InputPhase = .idle
    @State private var errorMessage: String = ""
    @State private var showSync: Bool = false

    enum InputPhase { case idle, verifying, failed }

    // Key 的基本格式校验：以 wrk- 开头且长度 > 4
    private var canSubmit: Bool {
        rawKey.hasPrefix("wrk-") && rawKey.count > 4
    }

    // 显示掩码：wrk-7c2d••••3f9a（保留前4位+wrk-，末4位，中间••••）
    private func maskedKey(_ key: String) -> String {
        guard key.count > 12 else { return "wrk-••••" }
        let prefix = String(key.prefix(8))   // "wrk-xxxx"
        let suffix = String(key.suffix(4))
        return "\(prefix)••••\(suffix)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 大标题
                    Text("粘贴你的 API Key")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ZJ.ink)
                        .padding(.top, 20)

                    // 副标题
                    Text("以 wrk- 开头，粘贴后我们验证一次连接。")
                        .font(.body)
                        .foregroundStyle(ZJ.ink2)
                        .lineSpacing(7)
                        .padding(.top, 12)

                    // 输入框
                    HStack {
                        SecureField("wrk-…", text: $rawKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(ZJ.ink)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .disabled(phase == .verifying)
                            .accessibilityIdentifier("api-key-input")

                    }
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 32)

                    // 验证中说明
                    if phase == .verifying {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(ZJ.ink2)
                            Text("正在连接微信读书，通常只需片刻。")
                                .font(.callout)
                                .foregroundStyle(ZJ.ink2)
                        }
                        .padding(.top, 12)
                    }

                    // 错误行（内联，不弹窗）
                    if phase == .failed {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 17))
                                .foregroundStyle(ZJ.error)
                                .accessibilityHidden(true)
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(ZJ.error)
                                .lineSpacing(6)
                        }
                        .padding(.top, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.updatesFrequently)
                    }

                    // 脚注
                    Text("Key 仅保存在本机钥匙串；连接验证与读取内容时会发送给微信读书接口。")
                        .font(.footnote)
                        .foregroundStyle(ZJ.ink3)
                        .lineSpacing(5)
                        .padding(.top, 12)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
            }

            // 底部主按钮
            VStack(spacing: 0) {
                ZJPrimaryButton(
                    title: phase == .verifying ? "验证中…" : (phase == .failed ? "重试验证" : "验证并连接"),
                    isEnabled: phase != .verifying && canSubmit,
                    action: { Task { await verify() } }
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(ZJ.bg.ignoresSafeArea(edges: .bottom))
            }
        }
        .background(ZJ.bg.ignoresSafeArea())
        .navigationTitle("连接微信读书")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase == .verifying)
        .navigationDestination(isPresented: $showSync) {
            SyncView()
                .environment(conn)
        }
    }

    @MainActor
    private func verify() async {
        guard phase != .verifying && canSubmit else { return }
        phase = .verifying
        errorMessage = ""

        do {
            try await conn.connect(with: rawKey)
            // 验证通过 → 进同步页
            showSync = true
        } catch let e as WeReadError {
            phase = .failed
            errorMessage = errorText(for: e)
        } catch {
            phase = .failed
            errorMessage = "没能连接上。请检查 Key 是否正确，或稍后重试。"
        }
    }

    private func errorText(for error: WeReadError) -> String {
        switch error {
        case .invalidKeyFormat:
            return "Key 未通过验证，请重新粘贴。"
        case .request:
            return "网络连接不上，请稍后重试。"
        case .upgradeRequired(let msg):
            return msg
        default:
            // 其余原样展示接口返回的中文提示
            return error.localizedDescription
        }
    }
}
