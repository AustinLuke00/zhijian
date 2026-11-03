import SwiftUI

// MARK: - 动态色

extension Color {
    /// 用 0xRRGGBB 传入明暗两值，随系统外观自动切换，无需 Assets.xcassets。
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8)  & 0xFF) / 255,
                blue:  CGFloat( hex        & 0xFF) / 255,
                alpha: 1)
        })
    }
}

// MARK: - 色板（design.md 第 2 节）

enum ZJ {
    static let bg         = Color(light: 0xF8F8F4, dark: 0x1A1916)
    static let surface    = Color(light: 0xFFFFFF, dark: 0x242220)
    static let surfaceAlt = Color(light: 0xF0F0EC, dark: 0x2E2C28)
    static let ink        = Color(light: 0x2B2723, dark: 0xF2ECE1)
    static let ink2       = Color(light: 0x6E665C, dark: 0xB4AA9C)
    static let ink3       = Color(light: 0x6F675B, dark: 0x9C9386)
    static let accent     = Color(light: 0x8A5A3B, dark: 0xC9966E)
    static let accentSoft = Color(light: 0xEDE6DF, dark: 0x382C22)
    static let onAccent   = Color(light: 0xFFFFFF, dark: 0x1A1916)
    static let error      = Color(light: 0xB4422E, dark: 0xE6907C)
    static let success    = Color(light: 0x4C6B40, dark: 0x9DBE8C)
    static let border     = Color(light: 0xE4E4E0, dark: 0x3A3A34)
    static let bar        = Color(light: 0xC9A989, dark: 0x7E5F45)
}

// MARK: - 字体 Modifier（design.md 第 3 节）

/// 划线原文（列表内）：衬线 body，行距 17→27（附加 10pt）。
struct ZJQuoteBodyText: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var extra: CGFloat = 10
    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .serif))
            .lineSpacing(extra)
            .foregroundStyle(ZJ.ink)
    }
}

/// 划线原文（详情页）：衬线 title3，行距 22→34（附加 12pt），不截断。
struct ZJQuoteDetailText: ViewModifier {
    @ScaledMetric(relativeTo: .title3) private var extra: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .font(.system(.title3, design: .serif))
            .lineSpacing(extra)
            .foregroundStyle(ZJ.ink)
    }
}

extension View {
    func zjQuoteBody() -> some View { modifier(ZJQuoteBodyText()) }
    func zjQuoteDetail() -> some View { modifier(ZJQuoteDetailText()) }
}

// MARK: - 引用块（带 3pt bar 竖线）

/// 左侧 3pt bar 竖线 + 右侧原文，列表内 lineLimit(3)，详情不截断。
struct QuoteBlock: View {
    enum DisplayMode { case list, detail }
    let text: String
    var mode: DisplayMode = .list

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ZJ.bar)
                .frame(width: 3)
                .accessibilityHidden(true)
            Spacer().frame(width: 14)
            Group {
                switch mode {
                case .list:
                    Text(text)
                        .zjQuoteBody()
                        .lineLimit(3)
                case .detail:
                    Text(text)
                        .zjQuoteDetail()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 主按钮

struct ZJPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? ZJ.onAccent : ZJ.ink3)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isEnabled ? ZJ.accent : ZJ.surfaceAlt,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .disabled(!isEnabled)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - 描边次按钮

struct ZJSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(title)
                    .font(.body)
            }
            .foregroundStyle(ZJ.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZJ.border, lineWidth: 1))
        }
    }
}

// MARK: - 文字按钮

struct ZJTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(ZJ.accent)
                .frame(minWidth: 44, minHeight: 44)
        }
    }
}

// MARK: - 封面图组件

/// AsyncImage + accentSoft 占位（不闪白）。
/// loading / failure 都留在占位层，.redacted 做骨架效果。
struct CoverImage: View {
    let url: URL?
    let title: String
    let width: CGFloat
    let height: CGFloat
    var fontSize: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(ZJ.accentSoft)
            Text(title.prefix(1))
                .font(.system(size: fontSize, design: .serif))
                .foregroundStyle(ZJ.accent)
                .accessibilityHidden(true)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        Color.clear
                            .redacted(reason: .placeholder)
                    case .failure:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 状态点

struct ConnectionDot: View {
    let isConnected: Bool

    var body: some View {
        Circle()
            .fill(isConnected ? ZJ.success : ZJ.ink3)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

// MARK: - 说明块

struct InfoBlock: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ZJ.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(ZJ.ink2)
                .lineSpacing(6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 进度条

struct ZJProgressBar: View {
    let value: Double   // 0.0–1.0
    let label: String
    let percentText: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ZJ.ink3)
                Spacer()
                Text(percentText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ZJ.ink3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ZJ.surfaceAlt)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ZJ.accent)
                        .frame(width: max(0, geo.size.width * value), height: 6)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("已完成 \(Int(value * 100))%")
    }
}

// MARK: - 骨架行

struct SkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(ZJ.surfaceAlt)
                .frame(height: 18)
            RoundedRectangle(cornerRadius: 6)
                .fill(ZJ.surfaceAlt)
                .frame(height: 18)
                .padding(.trailing, 60)
            RoundedRectangle(cornerRadius: 6)
                .fill(ZJ.surfaceAlt)
                .frame(height: 14)
                .padding(.trailing, 120)
        }
        .padding(.vertical, 16)
        .accessibilityHidden(true)
    }
}

// MARK: - 提示横幅

struct TipBanner: View {
    let message: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ZJ.accent)
            Spacer()
            Button(actionLabel, action: action)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZJ.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ZJ.accentSoft, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 大数字

struct BigNumberView: View {
    let count: Int
    let unit: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(count, format: .number)
                    .font(.system(size: 46, weight: .regular).monospacedDigit())
                    .foregroundStyle(ZJ.ink)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(ZJ.ink2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("已整理 \(count) \(unit)")
            Text(subtitle)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(ZJ.ink3)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: - 空态视图

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(ZJ.ink3)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ZJ.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(ZJ.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let t = buttonTitle, let action = buttonAction {
                ZJTextButton(title: t, action: action)
            }
        }
        .padding(.top, 96)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 筛选 Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ZJ.accent : ZJ.ink2)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    isSelected ? ZJ.accentSoft : ZJ.surfaceAlt,
                    in: RoundedRectangle(cornerRadius: 11)
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - 搜索框

struct ZJSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(ZJ.ink3)
            TextField(placeholder, text: $text)
                .font(.subheadline)
                .foregroundStyle(ZJ.ink)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(ZJ.surfaceAlt, in: RoundedRectangle(cornerRadius: 11))
        .frame(minHeight: 44)
        .accessibilityLabel("搜索摘录")
    }
}
