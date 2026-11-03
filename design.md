# 纸间（ZhiJian）· iOS 视觉与交互设计规范 v1

版本：2026-11-03　设计：Colo（@design）　实现：Pluso（@developer）
依据：`brief.md` 第七节（用户亲口定的风格）、`brief-addendum-ato.md`（Ato 对官方仓库的核实）、Jerry 的八屏范围、Pluso 步骤 1–4 的数据接口。

---

## 0. 适用范围与硬约束

| 项 | 值 |
|---|---|
| 平台 | iOS 17+，仅 iPhone，SwiftUI |
| 基准画幅 | 393 × 852 pt（iPhone 15/16 逻辑分辨率）；全部数值单位 pt |
| 依赖 | 无第三方库；**无自定义字体、无图片资产、无网络图片** |
| 图形来源 | 系统字体（SF Pro / New York / PingFang SC）+ SF Symbols + 代码绘制的矩形与圆角 |
| 界面语言 | 简体中文，全 App 统一；文案字符串见第 9 节 |
| 深浅色 | 必须同时支持，色值见第 2 节，全部文字组合 ≥ 4.5:1 |

本规范不留任何隐式视觉选择：颜色、字号、行距、间距、圆角、控件高度、图标、状态文案均已给值。实现时若遇到规范未覆盖的控件，按「同屏最接近的既有组件」复用，不新造样式。

「无账号」的等价说明：纸间没有登录态，也不出现任何平台登录按钮（不出现 Sign in with Apple 等）。**「未连接 / 已断开连接」就是本 App 的 signed-out 状态**，第 7.8、8 节给出它的完整版式与唯一退出动作「断开连接」。

---

## 1. 情绪与三条底线

情绪：简洁、温暖、安静、有阅读氛围。Apple 原生设计语言，极简主义。暖米白纸面、暖黑正文、单一低饱和棕，靠留白与字阶建立层级。

三条底线（违反即不算本稿）：
1. **不加装饰**：无插画、无渐变、无投影、无模糊材质堆叠、无背景纹理。
2. **不靠容器分组**：不用大量卡片堆叠，不用密集分割线；分组只靠 32pt 留白 + 字阶。细分隔线仅允许出现在设置分组的行间（1pt）。
3. **不做后台管理系统视觉**：无仪表盘、无密集控件条、无双列数据网格、无彩色标签墙。

单手优先：所有主操作固定在屏幕下方（拇指可达区），顶部只放标题与少量次要操作；层级不超过 2 级 push。

---

## 2. 颜色（精确色值，含深色模式）

### 2.1 语义色表

| 语义 | 浅色 | 深色 | 用途 |
|---|---|---|---|
| `bg` 背景 | `#F8F8F4` | `#1A1916` | 全屏底、Tab 栏底 |
| `surface` 纸面 | `#FFFFFF` | `#242220` | 设置分组块、弹窗、Toast |
| `surfaceAlt` 次级填充 | `#F0F0EC` | `#2E2C28` | 输入框、未启用按钮、说明块、搜索框、骨架 |
| `ink` 正文 | `#2B2723` | `#F2ECE1` | 标题、正文、划线原文 |
| `ink2` 辅助文字 | `#6E665C` | `#B4AA9C` | 副标题、作者、说明、想法正文 |
| `ink3` 三级文字 | `#6F675B` | `#9C9386` | 时间戳、计数、占位符、未选中 Tab、右侧箭头 |
| `accent` **唯一强调色** | `#8A5A3B` | `#C9966E` | 可点击文字/图标、选中态、主按钮、进度条、状态点 |
| `accentSoft` 强调底 | `#EDE6DF` | `#3A2C22` | 选中 chip、提示横幅 |
| `onAccent` 按钮文字 | `#FFFFFF` | `#1A1916` | 主按钮上的文字 |
| `error` 错误 | `#B4422E` | `#E6907C` | 错误文字、错误图标、破坏性按钮 |
| `success` 成功 | `#4C6B40` | `#9DBE8C` | 完成态文字、已连接状态点 |
| `border` 细分隔 | `#E4E4E0` | `#3A3A34` | 仅设置分组行间 1pt；不承载状态 |
| `bar` 引用竖线 | `#C9A989` | `#7E5F45` | 划线原文左侧 3pt 竖线 |

`accent` 是全 App 唯一彩色强调；`error`/`success` 只用于状态语义，不做装饰。正文一律 `ink`，不得用 `accent` 书写正文。

### 2.2 对比度实测（WCAG 相对亮度，正文阈值 4.5:1）

| 组合 | 浅色 | 深色 |
|---|---|---|
| `ink / bg` | 13.40 | 14.88 |
| `ink / surface` | 14.21 | 13.44 |
| `ink2 / bg` | 5.11 | 7.64 |
| `ink3 / bg` | 5.04 | 5.78 |
| `accent / bg` | 5.26 | 6.73 |
| `accent / accentSoft` | 4.55 | 5.16 |
| `onAccent / accent`（按钮） | 5.82 | 6.73 |
| `error / bg` | 5.05 | 7.20 |
| `success / bg` | 5.45 | 8.48 |
| `ink3 / surfaceAlt`（最弱组合） | 4.69 | 4.63 |

所有文字与强调组合均 ≥ 4.5:1，最低 4.55:1（`accent / accentSoft`，浅色）。`border` 与 `bg` 对比很低，因此规定它**只做分组、绝不承载状态或可点击含义**。

### 2.3 零资产实现（推荐，直接可用）

不建 Color Set，纯代码动态色，深浅自动跟随：

```swift
import SwiftUI

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

enum ZJ {
    static let bg         = Color(light: 0xF7F3EC, dark: 0x1C1916)
    static let surface    = Color(light: 0xFCFAF5, dark: 0x26221D)
    static let surfaceAlt = Color(light: 0xF0EBE0, dark: 0x302B24)
    static let ink        = Color(light: 0x2B2723, dark: 0xF2ECE1)
    static let ink2       = Color(light: 0x6E665C, dark: 0xB4AA9C)
    static let ink3       = Color(light: 0x6F675B, dark: 0x9C9386)
    static let accent     = Color(light: 0x8A5A3B, dark: 0xC9966E)
    static let accentSoft = Color(light: 0xEFE1D4, dark: 0x3A2C22)
    static let onAccent   = Color(light: 0xFFFFFF, dark: 0x1C1916)
    static let error      = Color(light: 0xB4422E, dark: 0xE6907C)
    static let success    = Color(light: 0x4C6B40, dark: 0x9DBE8C)
    static let border     = Color(light: 0xE7DFD1, dark: 0x3A342C)
    static let bar        = Color(light: 0xC9A989, dark: 0x7E5F45)
}
```

---

## 3. 字体（系统字体，不打包资产）

字号一律用 SwiftUI 语义字体（自动跟随 Dynamic Type），行距用 `.lineSpacing()` 补差；下表 pt/行距为**默认字号（Large / 标准）下的基准值**。中文由系统自动回退 PingFang SC，不显式指定中文字体名。

| 用途 | 语义字体 / Dynamic Type | pt / 行距 | 字重 | 字体 |
|---|---|---|---|---|
| 引导页大标题 | `.largeTitle` | 34 / 41 | Regular | SF Pro |
| 页面大标题（书架/摘录/设置） | `.largeTitle` | 34 / 41 | Regular | SF Pro |
| 区块大标题（Key 页、进度页） | `.title2` | 28 / 34 | Semibold | SF Pro |
| 导航栏标题 | 系统导航栏 | 16 / — | Semibold | SF Pro |
| 书名 / 区块标题 | `.title3` | 20 / 25 | Semibold | SF Pro |
| 卡片标题 / 区块头 | `.headline` | 17 / 22 | Semibold | SF Pro |
| 正文 · 备注 · 按钮 | `.body` | 17 / 22 | Regular | SF Pro |
| 说明短句 | `.callout` | 16 / 21 | Regular | SF Pro |
| 次要说明 | `.subheadline` | 15 / 20 | Regular | SF Pro |
| 辅助说明 / 脚注 | `.footnote` | 13 / 18 | Regular | SF Pro |
| 时间戳 · 计数 · Tab 文字 | `.caption` | 12 / 16 | Regular | SF Pro |
| **列表内划线原文** | `.system(.body, design: .serif)` | 17 / 27 | Regular | New York |
| **详情划线原文** | `.system(.title3, design: .serif)` | 22 / 34 | Regular | New York |
| 备注编辑器内文 | `.subheadline` | 15 / 21 | Regular | SF Pro |
| 大数字（进度页） | `.largeTitle` + `.monospacedDigit()` | 46 / 52 | Regular | SF Pro |

规则：
- **衬线只用于两处**：划线原文、封面占位首字。界面其余全部 SF Pro，营造「正文是书、界面是纸」的阅读感。
- 所有数字（进度、计数、百分比、日期）加 `.monospacedDigit()`，滚动时不跳动。
- Dynamic Type 支持到 `.accessibility3`：列表行高随字号增长，划线原文不截断、不省略；到 `accessibility2` 及以上时，摘录列表去掉标签 chip 行与想法摘要，只保留原文 + 书名，避免拥挤。
- 行距用 `@ScaledMetric(relativeTo:)` 让附加行距随字号缩放，不要写死 `.lineSpacing(5)` 后忽略大字号。示例：

```swift
struct ZJQuoteText: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var extra: CGFloat = 10  // 17 → 27 的附加行距
    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .serif))
            .lineSpacing(extra)
            .foregroundStyle(ZJ.ink)
    }
}
```

---

## 4. 间距 · 圆角 · 触控 · 固定框架

**间距（4pt 基准）：4 / 8 / 12 / 16 / 24 / 32 / 48。**

| 位置 | 值 |
|---|---|
| 页面左右安全边距 | 24 |
| 顶部内容距导航栏 | 20（引导/大标题页）；8（详情页） |
| 大标题与其副标题 | 12 |
| 区块与区块之间 | 32 |
| 段落之间 | 16 |
| 列表行上下 padding | 16（摘录行）/ 11（书籍行） |
| 紧凑组内元素 | 8 或 12 |
| 说明块内 padding | 18 |
| 底部主操作区 padding | 上 12 / 左右 24 / 下 6（系统 Home 安全区之上） |

**圆角：** 按钮与输入框 12；说明块与设置分组 16；大面板与系统弹窗 20；书籍封面 8；chip 11；引用竖线宽 3（两端圆角 2）；进度条高 6（圆角 3）。

**触控：** 最小点击区 44 × 44。主按钮高 52；次按钮/描边按钮 48；紧凑按钮 44；chip 高 34（点击区补足到 44）；输入框高 54；搜索框高 38（外层点击区补足 44）。

**固定框架（系统绘制，不自定义）：** 状态栏 54；导航栏 44；底部 Tab 栏 62（顶部 1pt `border`）；Home Indicator 区域 22，不画横线以外的东西。引导/进度全屏页不带 Tab。

**禁止：** 任何 `.shadow()`、任何 `LinearGradient`、任何 `.ultraThinMaterial` 堆叠、任何彩色边框强调。

---

## 5. 导航与转场

```
fullScreenCover（引导流程，仅首次或断连后）
  01 连接介绍  →  push  02 Key 输入  →  fullScreenCover  03 同步进度
                                              ↓ 完成
TabView（3 项，主界面）
  书架 ─push→ 书籍详情 ─push→ 摘录详情（可按书筛选）
  摘录 ─push→ 摘录详情
  设置
```

- 引导流程（01 → 02 → 03）是独立 `fullScreenCover`，完成后 `.fullScreenCover` dismiss 进 `TabView`。02 的「返回」回 01；01 的「跳过」直接进未连接态的 `TabView`。
- `TabView` 恰好 3 项：**书架 / 摘录 / 设置**。SF Symbols `books.vertical` / `quote.bubble` / `gear`；图标 23pt、文字 `caption` 10pt；选中 `accent` + Semibold，未选 `ink3` + Regular。
- 书籍详情、摘录详情各为**一级 push**（`NavigationStack`），全 App 导航深度 ≤ 2，无更深层级。
- 同步进度为全屏 `fullScreenCover`；「停止导入」用系统 `.alert`（两个按钮：继续导入 / 停止导入，后者 `.destructive`）。
- 断开连接用系统 `.alert`，破坏性按钮 `error` 色。
- 备注编辑、添加标签、筛选书籍用系统 `.sheet`（`.presentationDetents([.medium, .large])`），不要自造弹层。
- **转场**：一律系统 push / sheet / fullScreenCover。若必须自定义过渡，统一 `0.28s easeInOut` 且只改 `opacity`；读 `@Environment(\.accessibilityReduceMotion)`，开启时关闭全部自定义动画。禁止弹簧、视差、共享元素转场、翻页效果。

---

## 6. 可复用组件清单

| 组件 | 结构与精确值 |
|---|---|
| 主按钮 | 高 52，圆角 12，填充 `accent`，文字 `.body` Semibold `onAccent`，全宽；禁用态填充 `surfaceAlt` + 文字 `ink3` |
| 描边次按钮 | 高 48，圆角 12，1pt `border`，文字 `ink`；用于「停止导入」 |
| 文字按钮 | `.subheadline` `accent`；最小点击区 44；用于「跳过 / 查看全部 / 清除筛选」 |
| 输入框 | 高 54，圆角 12，填充 `surfaceAlt`，左右 14，文字 `.body`，占位符 `ink3`；右侧眼睛图标 `ink2` |
| 说明块 | 圆角 16，填充 `surfaceAlt`，内 padding 18；标题 `.subheadline` Semibold `ink`，正文 `.caption`/14px `ink2`，行距 20 |
| 书籍行 | 上下 11；封面 56×80 圆角 8；书名 `.body` Semibold；作者 `.caption` `ink2`；计数 `.caption` `ink3`；右侧 `chevron.right` 17 `ink3`；行间**无**分割线 |
| 封面占位 | 填充 `accentSoft`，居中书名首字（衬线 22pt / 大封面 36pt）`accent`；无封面时填充 `surfaceAlt` + 首字 `ink3`；**不加载远程图片、不闪白**（异步图用 `.redacted` 而非空白） |
| 筛选 chip | 高 34，圆角 11，填充 `surfaceAlt`/文字 `ink2`；选中填充 `accentSoft`/文字 `accent` Semibold；内左右 12，字 13 |
| 搜索框 | 高 38，圆角 11，填充 `surfaceAlt`；`magnifyingglass` 16 `ink3` + 占位文字 `.subheadline` `ink3`；外层补足 44 点击区 |
| 引用块 | 左侧 3pt `bar` 竖线（圆角 2）+ 右侧 14 间距，衬线原文 `ink`；列表内 17/27 最多 3 行（`-webkit-line-clamp` 等效 SwiftUI `.lineLimit(3)`）；详情内 22/34 不截断 |
| 想法条 | `bubble.left` 14 `ink2` + `.subheadline` `ink2`，与引用块左对齐（缩进 17） |
| 标签 chip | 高 24，圆角 7，填充 `surfaceAlt`，字 12 `ink2`；「添加标签」为虚线 1pt `border` 描边 + `plus` 13 + 文字 `accent` |
| 备注编辑框 | 圆角 12，填充 `surfaceAlt`，内 padding 12，min-height 76，`.subheadline`/15/21 `ink2`；占位「写点备注…」 |
| 设置分组 | 圆角 16，填充 `surface`，行高 ≥48，内左右 16；行间 1pt `border`；分组标题 `.caption` `ink3`，左 16，上 16 |
| 进度条 | 高 6，圆角 3，轨道 `surfaceAlt`，填充 `accent`；上方左右各 `.caption` `ink3`（标签 / 百分比，`.monospacedDigit()`） |
| 状态点 | 8×8 圆，`success`（已连接）/ `ink3`（已断开）；必须配文字，不靠颜色单表意 |
| 大数字 | `.largeTitle` 46/52 Regular `ink` + `.monospacedDigit()`；单位 `.subheadline` 17 `ink2` 同行 |
| 提示横幅 | 圆角 12，填充 `accentSoft`，内 10/12，`.caption` 13 `accent` |
| 骨架 | 圆角 6，填充 `surfaceAlt`，仅占位矩形，无动画闪烁；用 `.redacted(reason: .placeholder)` |
| 空态 | 居中，顶部 padding 96；图标 44 `ink3`；标题 `.title3` Semibold；正文 `.subheadline` `ink2` 左右 24；下方一个文字按钮 |
| 加载 | 系统 `ProgressView`（`.circular`），配 `.subheadline` `ink2` 说明文字；长任务用进度条而非无限转圈 |
| 弹窗 | 系统 `.alert` / `.confirmationDialog`，不自定义样式 |

---

## 7. 八屏逐屏规范

每屏给出：目标 → 自上而下布局 → 组件 → 状态 → 文案 → 交互 → 可访问性。样图编号对应附件 PNG 与画廊。

### 7.1 连接介绍页（01-onboarding）

**目标**：讲清「做什么」和「需要自备 API Key」，不吓人，不承诺导入书签。

- 框架：状态栏 + 导航栏（右侧文字按钮「跳过」，`accent`）+ 全屏内容 + 底部主按钮；无 Tab。
- 自上而下（左右 24）：
  1. 顶部 20 后：眉标「纸 间」，`.caption` 12 Semibold，`accent`，字距 2。
  2. 10 后：大标题「把划过的线，收进纸间」，`.largeTitle` 34/41 Regular，两行。
  3. 12 后：副标题「让值得记住的文字，在纸间留下痕迹。」`.body` 17/24 `ink2`。
  4. 32 后：三条功能说明，每条 `frow`：图标 26 `accent` + 左间距 16；标题 `.body` 17/21 Semibold；描述 `.subheadline` 14/20 `ink2`；条间 padding 14 上下，**无分割线、无卡片**。
     - `quote.bubble`「收集划线与想法」→「把你在微信读书里划过的线、写过的想法，整理到一处。」
     - `iphone`「保存在这台设备」→「不需要账号，内容只留在本机，随时回看。」
     - `note.text`「可以慢慢整理」→「搜索、筛选，再补上备注、标签和收藏。」
  5. 24 后：说明块（圆角 16，`surfaceAlt`）：
     - 标题「连接需要一个 API Key」`.subheadline` Semibold。
     - 正文「纸间用它读取你自己的划线与想法。Key 由你在微信读书官方提供的技能接口中获取，以 wrk- 开头；只保存在这台设备的钥匙串里，不会写进代码；仅在请求微信读书接口时发送。下一步带你粘贴并验证。」14/20 `ink2`。
     - 说明块正文下 12pt 放 `Link("获取 API Key", destination: URL(string: "https://weread.qq.com/r/weread-skills")!)`，字号 15pt、`accent`、点击高度至少 44pt，辅助功能提示「打开微信读书官方获取页面」；不写「不会泄露」「绝对安全」等绝对化或吓人措辞；不写「导入书签」。
  6. 底部：全宽主按钮「开始连接」→ push 02。
- 可访问性：三条图标 `.accessibilityHidden(true)`（标题已完整表意）；「跳过」label「跳过连接介绍」。

### 7.2 API Key 输入页（02-key-input / 03 验证中 / 04 失败）

**目标**：粘贴 + 一次验证；验证中可见、失败可重试；Key 永不回显全量、永不进日志。

- 框架：导航栏左「返回」+ `chevron.left`，居中标题「连接微信读书」，右侧空；底部主按钮；无 Tab。
- 自上而下：
  1. 20 后：`.title2` 28/34 Semibold「粘贴你的 API Key」。
  2. 12 后：`.body` 17/24 `ink2`「以 wrk- 开头，粘贴后我们验证一次连接。」
  3. 32 后：输入框（54 高）。占位 `wrk-…`（`ink3`）；**输入用 `SecureField`**，右侧 `eye` / `eye.slash` 20 `ink2` 切换显隐；Key 用等宽 15、字距 0.6。失败/验证中态显示掩码 `wrk-7c2d••••3f9a`，**任何时候不显示完整 Key**。
  4. 12 后：`.footnote` 13/18 `ink3`「Key 只用于连接验证与读取；验证通过后存入本机钥匙串。」
  5. 底部主按钮，随状态变化：
     - **idle（02）**：禁用态「验证并连接」（`surfaceAlt`/`ink3`）；输入以 `wrk-` 开头且长度 > 4 才启用为 `accent`。
     - **verifying（03）**：禁用「验证中…」；输入行下方插入一行 `.callout` 16 `ink2` + 系统 `ProgressView`「正在连接微信读书，通常只需片刻。」；按钮与输入均不可交互；**禁止重复提交**。
     - **failed（04）**：输入框保持掩码，下方 12 后错误行（`xmark.circle` 17 + `.subheadline` 14/20 `error`）「没能连接上。请检查 Key 是否正确，或稍后重试。」；按钮改「重试验证」`accent`。
       - 若接口返回 `upgrade_info`，同一位置改显示其 `message` 原文；若是鉴权类错误，显示「Key 未通过验证，请重新粘贴。」；网络类「网络连接不上，请稍后重试。」；**其余错误在此处原样展示接口返回的中文提示**（Pluso 要求预留的文案位）。错误行不弹窗、不打断输入。
- 交互：验证通过才写 Keychain 并进 03 同步页；失败不落盘（开发侧已保证）。
- 可访问性：输入框 label「API Key」、hint「以 wrk- 开头」；显隐按钮 label「显示 API Key / 隐藏 API Key」；错误行 `.accessibilityLiveRegion(.polite)` 等价的 `.accessibilityAddTraits(.updatesFrequently)` 播报。

### 7.3 同步进度页（05 进行中 / 06 完成 / 07 停止确认 / 失败）

**目标**：几十本书的导入要有进度感、可中断、可恢复；主数字用**实际入库条数**。

- 框架：`fullScreenCover`；状态栏 + 导航栏（左空，右「完成」仅完成态出现）；无 Tab；底部一个按钮。
- 自上而下（左右 24）：
  1. 20 后：`.title2` 28/34 Semibold「正在整理」/「导入完成」。
  2. 28 后：大数字 46/52 `ink`（如 `1,284`）+ 单位「条」17 `ink2` + `.monospacedDigit()`。
  3. 6 后：`.footnote` 13/18 `ink3`「划线 1,102 条 · 想法 182 条」——**两个独立数字并列，不能只写一个「划线」**。
     - 若同屏需出现「笔记总数」（含书签），只能作为次级脚注并注明「含书签，书签内容无法导入」，**绝不作为主数字，也不与入库数混算**。
  4. 28 后：进度条（6 高，`accent` 填充），上方左「导入进度」`.caption` `ink3`、右百分比「62%」`.caption` `ink3` 等宽。
  5. 28 后：当前状态 `.body` 17 `ink2`「正在读取《置身事内》」；6 后 `.footnote` 13 `ink3`「第 18 / 42 本」。
  6. 16 后：`.footnote` 13/18 `ink3`「导入的是划线与想法；书签只有数量，内容无法读取。」（进行中）；完成态改为「下次同步只补新增内容，你写过的备注、标签和收藏都会保留。」
  7. 底部按钮：进行中「停止导入」（描边次按钮 + `xmark` 16）→ 触发系统 `.alert`；完成态「查看书架」主按钮。
- **停止确认（07）**：系统 alert，标题「停止这次导入？」，正文「已经整理好的 1,284 条会保留。下次可以从这里继续，不会重复导入。」，按钮「继续导入」/「停止导入」（destructive）。文案随实际数量动态填。
- **完成态（06）**：标题「导入完成」，大数字 2,064，进度 100%，当前状态改为 `checkmark.circle` 16 + `success`「全部 42 本已整理完」，导航栏右侧「完成」，底部「查看书架」。
- **失败态**（Pluso 四种状态之一）：标题「导入未完成」，保留已完成的大数字与进度条，隐藏当前书名行，改放一行 `.subheadline` `error`「导入停在了第 18 本」；下方**原样展示接口返回的中文提示**；底部两个按钮：主按钮「从中断处继续」+ 次按钮「返回书架」。不吞错误、不显示「已完成」。
- 交互：进度由 `AsyncStream<SyncProgress>` 驱动，主线程更新；百分比与书名每本书更新一次即可，**不要每条刷新**（避免跳动）。中途取消立即停。
- 可访问性：进度条 `.accessibilityValue("已完成 62%")`；大数字读「已整理 1,284 条」；书名行 `updatesFrequently` 但限制播报频率（每本一次）。

### 7.4 书架列表（08 / 09 空态 / 加载 / 失败）

**目标**：只列「**有笔记的书**」（`/user/notebooks` 结果），不灌全书架。

- 框架：Tab「书架」选中；导航栏居中无标题（大标题在内容区），右侧 `arrow.triangle.2.circlepath` 21 `accent`（重新同步）；底部 Tab。
- 自上而下：
  1. 20 后：`.largeTitle` 34/41 Regular「书架」。
  2. 6 后：`.footnote` 13 `ink3`「42 本有笔记的书」。
  3. 8 后：书籍行列表（每行上下 11，无分割线）：封面 56×80 圆角 8 + 16 间距 + 书名/作者/计数 + 右 `chevron.right` 17 `ink3`。
     - 计数行格式「划线 38 · 想法 6」——**两个独立数字**，不写「笔记 44 条」这种含书签的合并数。
     - 封面用 `accentSoft` + 书名首字占位；真实封面异步加载期间保持占位（`.redacted`），**不闪白**（验收第 5 条）。
  4. 点击行 → push 书籍详情。
- **空态（09）**：居中 padding 96，`books.vertical` 44 `ink3`；标题「书架还是空的」；正文「连接微信读书后，有划线或想法的书会出现在这里。」；底部主按钮「连接微信读书」→ 引导流程。
- **加载态**：大标题与计数行保留，列表位置放 5 行骨架（封面矩形 + 两条文字矩形，`surfaceAlt` 圆角 6），无闪烁。
- **失败态**：保留已缓存的书架，顶部插入提示横幅（`accentSoft`，`.caption` `accent`）「暂时没能同步，下面是上次整理好的内容。」+ 文字按钮「重试」；不整屏报错。
- 可访问性：每行合并为一个无障碍元素，label「置身事内，兰小欢，划线 38 条，想法 6 条」；封面装饰性隐藏。

### 7.5 书籍详情（10-book-detail）

**目标**：单本书的概览 + 本书摘录预览；`/book/info` 按需单本调。

- 框架：导航栏左「书架」+ `chevron.left`、居中「书籍详情」、右 `arrow.triangle.2.circlepath` 20；无 Tab（一级 push）；底部无按钮。
- 自上而下（左右 24，顶部 8）：
  1. 封面 96×136 圆角 8 + 20 间距 + 右侧：书名 `.title2` 22/28 Semibold（衬线可用于书名，见下）、作者 `.body` `ink2`、18 后「阅读进度 62%」`.caption` `ink3`、6 后进度条（宽 150，高 6，62%）。进度为 0–100 整数带 `%`。
     - 书名用 `.system(.title3, design: .serif)` 20/25 Semibold（与划线原文呼应）。
  2. 26 后：三列统计「38 划线 / 6 想法 / 3 书签」，数字 `.title3` 22/26 Semibold 等宽、标签 `.caption` 12 `ink3`；三列等宽、无分割线、无卡片。
     - 10 后：`.caption` 12/16 `ink3`「书签只有数量，内容无法导入。」**必须有这句**，避免用户误以为书签未导入是故障。
  3. 22 后：区块头「本书摘录」`.headline` Semibold + 右侧文字按钮「查看全部」→ 摘录列表（按本书筛选）。
  4. 摘录预览 3 条：引用块（3pt 竖线 + 衬线 17/27，`.lineLimit(3)`）+ 10 后 meta 行（收藏星标 14 `accent` / 日期 `.caption` `ink3`）+ 有想法时一行想法条「想法 2 条 · 读到这里时想起另一本书」。
     - **想法在这里折叠**（Pluso 一问）：列表只显示条数与首条摘要，详情才逐条展开。
- **空/失败态**：本书暂无可展示摘录 → 区块内一句 `.subheadline` `ink2`「这本书还没有可展示的摘录。」；`/book/info` 失败 → 保留书名作者（来自 notebooks），进度与统计位置显示「详情暂时读不到」+ 重试文字按钮，不整屏报错。
- 可访问性：三列统计各读「38 条划线」等完整单位；进度条读「阅读进度 62%」。

### 7.6 摘录列表（11 / 12 无结果 / 13 加载骨架 / 失败）

**目标**：全库浏览 + 搜索 + 筛选 + 排序；单手可达。

- 框架：Tab「摘录」选中；导航栏居中无标题，右 `arrow.up.arrow.down` 20 `accent`（排序）；底部 Tab。
- 自上而下（左右 24）：
  1. 20 后：`.largeTitle`「摘录」。
  2. 12 后：搜索框（38 高）+ `magnifyingglass`，占位「搜索划线、想法、备注或书名」。搜索范围包含划线原文、想法、备注、标签、书名；中文输入实时过滤不卡顿。
  3. 12 后：横向筛选 chip 行（可横滑，高 34）：「全部」（选中）/「已收藏」/「有想法」/「有备注」/「全部书籍 ▾」。选中态 `accentSoft` + `accent` Semibold。「全部书籍」点开 `.sheet` 选书。
     - chip 可多选叠加；选中非「全部」时，搜索框下方显示 `.caption` `ink3`「已按 2 个条件筛选」+ 文字按钮「清除」。
  4. 12 后：`.footnote` 13 `ink3`「共 1,284 条」（筛选后更新为命中数）。
  5. 摘录行列表（上下 padding 16，**行间无分割线**）：
     - 引用块（3pt `bar` + 衬线 17/27，`.lineLimit(3)`）
     - 10 后 meta `.caption` 12 `ink3`「置身事内 · 第一章」
     - 有关联想法 → 想法条（`bubble.left` 14 + `.subheadline` 15/21 `ink2`「想法：这段把「激励」讲透了」）——**折叠显示，只显首条 + 总数**。
     - 10 后标签行：标签 chip（高 24）+ 弹性间隔 + `note.text` 15 `ink3`（有备注）+ `star.fill` 15 `accent`（已收藏）。无备注/未收藏时不占位。
     - **独立想法条目**（整本书评 / 有 range 未配上）：不显示引用块，改为整行 `.subheadline` 15/21 `ink2` 的想法正文 + 10 后一行 `.caption` 12 `ink3`「独立想法 · 未关联划线 · 书名」。与有原文的条目在同一个列表里，同一套行高与间距。
       - **预留一行可切换的次级说明位**（默认隐藏）：若实测「有 range 但没配上」占比偏高，可在此处启用一句「这条想法对应的划线暂时没找到，可在下次同步后重试。」。两种来源（range 空 / range 有值未匹配）**视觉上先不区分**，与 Pluso 约定一致。
- **搜索无结果（12）**：padding 120 居中，`magnifyingglass` 42 `ink3`；标题「没有找到相关摘录」；正文「换个关键词，或清除筛选条件再试试。」；下方文字按钮「清除筛选」。
- **无数据空态**：标题「还没有摘录」；正文「连接微信读书后，划过的线和写过的想法会出现在这里。」；按钮「连接微信读书」。
- **加载骨架（13）**：3 行矩形骨架（两条 18 高 + 一条 14 高，`surfaceAlt` 圆角 6），计数行改「正在读取本地摘录…」；无闪烁动画。
- **失败态**：横幅「本地内容暂时读不到」+「重试」文字按钮；保留上次列表。
- 排序 sheet：`.subheadline` 列表「按导入时间（新→旧）/ 按导入时间（旧→新）/ 按书名 / 按划线时间」，选中 `checkmark` `accent`；默认新→旧。
- 可访问性：搜索框 label「搜索摘录」；chip 选中读「已收藏，已选中」；每个摘录行合并朗读，收藏读「已收藏」而非仅靠星形。

### 7.7 摘录详情（14 / 17 深色 / 独立想法版式）

**目标**：原文 + 多条关联想法 + 备注 + 标签 + 收藏，全部可编辑且同步不覆盖。

- 框架：导航栏左「返回」+ `chevron.left`、居中「摘录」、右 `star.fill` 21 `accent`（收藏切换，`star` 未收藏时用 `ink3` 描边）；一级 push；底部无按钮；`ScrollView`。
- 自上而下（左右 24，顶部 10）：
  1. `.caption` 12 `ink3`「置身事内 · 第一章 · 2026-10-12」。
  2. 22 后：引用块（3pt `bar` + 18 间距 + 衬线 **22/34** `ink`，**不截断**，长文完整滚动显示）。
  3. 30 后：区块头「想法 · 2 条」`.subheadline` 15 Semibold。
     - 每条：label「想法 1」`.caption` 12 Semibold `accent`；4 后正文 `.body` 16/23 `ink2`；4 后时间 `.caption` 12 `ink3`「2026-10-12 22:41」；条间 14。
     - **一条划线可挂多条想法，此处逐条全部展开**（与列表的折叠相反）。
     - 无关联想法时该区块显示 `.subheadline` `ink2`「这条划线还没有想法。」
  4. 28 后：区块头「备注」+ 6 后备注编辑框（圆角 12，`surfaceAlt`，min-height 76，`.subheadline` 15/21）。点击进入编辑、失焦即存；占位「写点备注…」。
  5. 22 后：区块头「标签」+ 标签 chip 行（可换行）+ 虚线「添加标签」chip。
  6. 底部留 32 空白，不塞按钮。
- **独立想法版式**：无原文区、无引用竖线；顶部 caption 改「独立想法 · 未关联划线 · 书名」；其后直接是想法正文（`.body` 17/23 `ink`，比关联想法更重，因为它本身就是主体）+ 时间；再往下同样是备注 / 标签 / 收藏。默认不显示解释性文案，预留一行 `.footnote` `ink3` 次级说明位（默认隐藏，见 7.6）。
- **状态**：加载用 `.redacted` 占位；保存失败在对应区块下显示 `.caption` `error`「没能保存，请重试。」并保留输入；保存成功不弹窗（原地生效），必要时一个 1.5s 的 `.caption` `success`「已保存」轻提示。
- 数据边界：备注 / 标签 / 收藏属于 `QuoteAnnotation`，同步只写 `Quote`；视觉上这三块独立于「原文 + 想法」，用 28/22 的区块间距明确隔开。
- 可访问性：收藏按钮 label「取消收藏 / 收藏」；引用竖线隐藏；备注框 label「备注，可编辑」；标签各读标签名。

### 7.8 设置 / 断开连接（15 / 已断开态）

**目标**：连接状态、Key、数据说明、断开连接；**本 App 的 signed-out 状态在这里**。

- 框架：Tab「设置」选中；导航栏居中无标题；`ScrollView`；底部 Tab。
- 自上而下（左右 24）：
  1. 20 后：`.largeTitle`「设置」。
  2. 20 后：**分组 1（圆角 16，`surface`）**
     - 行「微信读书」+ 8px 状态点（`success`）+ `ink3`「已连接」。
     - 行「API Key」+ 等宽 `ink3` 掩码「wrk-••••3f9a」+ `chevron.right` 16。**永不显示完整 Key**；点击进入 Key 输入页可替换。
     - 行「重新导入」+ `arrow.triangle.2.circlepath` 18 `ink3`。
  3. 18 后分组标题「数据」`.caption` `ink3` 左 16；6 后**分组 2**
     - 行「保存在这台设备」+ `lock` 19 `ink3`；行内次级文字 `.caption` 12 `ink3`「不需要账号；内容、备注、标签和收藏都留在本机。」
     - 行「已整理内容」+ 右 `ink3` 等宽「2,064 条」。
  4. 18 后分组标题「关于」；6 后**分组 3**
     - 行「纸间」+ 右 `ink3`「版本 1.0」。
     - 行「断开连接」文字 `error` 色（唯一破坏性动作）。
  5. 22 后：`MadeWithAirBuild()` 独占最后一块，居中、`.caption` 12 `ink3`，位于所有分组之后、页面最底部。它随 starter 自带，保留原样式与链接，不改写、不挪到主页/引导页。因为本页是 `ScrollView`（非 `Form`、无 footer），按 skill 用 **`.compact`** 变体。
     - 本页**不出现任何平台登录按钮**（无 Sign in with Apple、无第三方登录）。
     - 本页**不出现版本号 footer 在 credit 之后**（版本已作为分组行存在），避免 credit 与 footer 叠在一起。
- **断开连接确认（系统 alert）**：标题「断开微信读书连接？」；正文「只会清除这台设备上保存的 API Key。已经整理好的摘录、备注、标签和收藏都会保留，随时可以重新连接。」；按钮「取消」/「断开连接」（destructive，`error`）。确认后状态点变 `ink3`「已断开」，Key 行消失。
- **已断开 / signed-out 态**：分组 1 只保留一行「微信读书 · 已断开」+ 主按钮样式的文字按钮「连接微信读书」→ 引导流程；分组 2 仍显示「已整理内容 2,064 条」（**断连不删数据**）；分组 3 无「断开连接」行；`MadeWithAirBuild` 位置不变。书架/摘录两个 Tab 仍可正常浏览本地数据，只是不能同步。
- 可访问性：状态点配文字；「断开连接」读「断开连接，会清除 API Key 但保留摘录」；credit 保持其自带 label。

---

## 8. 状态矩阵（empty / loading / error / success）

| 屏 | 空 | 加载 | 错误 | 成功 |
|---|---|---|---|---|
| 连接介绍 | — | — | — | 「开始连接」→ 02 |
| Key 输入 | 输入框未填（按钮禁用） | 验证中：禁用 + ProgressView + 说明 | 内联错误行 + 原始提示位 +「重试验证」 | push 03 |
| 同步进度 | — | 进行中：大数字 + 进度条 + 当前书名 | 失败态：保留进度 + 原始提示 +「从中断处继续」 | 完成态：100% +「查看书架」 |
| 书架 | 「书架还是空的」+「连接微信读书」 | 5 行骨架 | 顶部横幅「暂时没能同步…」+ 重试（保留缓存） | 列表 +「42 本有笔记的书」 |
| 书籍详情 | 本书无摘录：一句说明 | 封面/统计 `.redacted` | 「详情暂时读不到」+ 重试（保留书名作者） | 三列统计 + 3 条预览 |
| 摘录列表 | 「还没有摘录」/「没有找到相关摘录」 | 3 行骨架 +「正在读取本地摘录…」 | 横幅 + 重试（保留上次列表） | 命中数 + 列表 |
| 摘录详情 | 无想法：一句说明 | `.redacted` | 区块下 `.caption` `error`「没能保存，请重试。」保留输入 | 原地生效，轻提示「已保存」 |
| 设置 | 已断开（signed-out）：显示「连接微信读书」 | — | 断连失败：alert 说明 + 重试 | 状态点「已连接」 |

统一规则：错误**不整屏覆盖**、**不清空已有内容**、**保留可重试入口**；加载用骨架或系统 ProgressView，不用无限转圈冒充进度；成功尽量原地生效，不弹打断式弹窗。

---

## 9. 文案总表（落地用，简体中文）

**引导**
- 眉标「纸 间」／大标题「把划过的线，收进纸间」／副标题「让值得记住的文字，在纸间留下痕迹。」
- 「收集划线与想法」「把你在微信读书里划过的线、写过的想法，整理到一处。」
- 「保存在这台设备」「不需要账号，内容只留在本机，随时回看。」
- 「可以慢慢整理」「搜索、筛选，再补上备注、标签和收藏。」
- 「连接需要一个 API Key」「纸间用它读取你自己的划线与想法。Key 由你在微信读书官方提供的技能接口中获取，以 wrk- 开头；只保存在这台设备的钥匙串里，不会写进代码；仅在请求微信读书接口时发送。下一步带你粘贴并验证。」
- 按钮／链接：「跳过」「开始连接」

**Key**
- 「连接微信读书」「粘贴你的 API Key」「以 wrk- 开头，粘贴后我们验证一次连接。」
- 「Key 只用于连接验证与读取；验证通过后存入本机钥匙串。」
- 「验证并连接」「验证中…」「重试验证」
- 「正在连接微信读书，通常只需片刻。」
- 「没能连接上。请检查 Key 是否正确，或稍后重试。」／「Key 未通过验证，请重新粘贴。」／「网络连接不上，请稍后重试。」／其余原样展示接口中文提示

**同步**
- 「正在整理」「导入完成」「导入未完成」「条」
- 「划线 1,102 条 · 想法 182 条」「导入进度」「正在读取《置身事内》」「第 18 / 42 本」
- 「导入的是划线与想法；书签只有数量，内容无法读取。」
- 「下次同步只补新增内容，你写过的备注、标签和收藏都会保留。」
- 「全部 42 本已整理完」「查看书架」「停止导入」「完成」「从中断处继续」「返回书架」
- 停止确认「停止这次导入？」「已经整理好的 1,284 条会保留。下次可以从这里继续，不会重复导入。」「继续导入」「停止导入」

**书架 / 详情 / 摘录**
- 「书架」「42 本有笔记的书」「划线 38 · 想法 6」
- 「书架还是空的」「连接微信读书后，有划线或想法的书会出现在这里。」「连接微信读书」
- 「暂时没能同步，下面是上次整理好的内容。」「重试」
- 「书籍详情」「阅读进度」「书签只有数量，内容无法导入。」「本书摘录」「查看全部」「想法 2 条 · …」
- 「这本书还没有可展示的摘录。」「详情暂时读不到」
- 「摘录」「搜索划线、想法、备注或书名」「全部」「已收藏」「有想法」「有备注」「全部书籍」「清除」「清除筛选」
- 「共 1,284 条」「正在读取本地摘录…」「已按 2 个条件筛选」
- 「没有找到相关摘录」「换个关键词，或清除筛选条件再试试。」「还没有摘录」「连接微信读书后，划过的线和写过的想法会出现在这里。」
- 「本地内容暂时读不到」「独立想法 · 未关联划线」「这条划线还没有想法。」「写点备注…」「添加标签」「想法 · 2 条」「想法 1」「备注」「标签」「没能保存，请重试。」「已保存」
- 排序「按导入时间（新→旧）」「按导入时间（旧→新）」「按书名」「按划线时间」
- 预留（默认隐藏）「这条想法对应的划线暂时没找到，可在下次同步后重试。」

**设置 / signed-out**
- 「设置」「微信读书」「已连接」「已断开」「API Key」「重新导入」「数据」「保存在这台设备」「不需要账号；内容、备注、标签和收藏都留在本机。」「已整理内容」「关于」「纸间」「版本 1.0」「断开连接」
- 断连确认「断开微信读书连接？」「只会清除这台设备上保存的 API Key。已经整理好的摘录、备注、标签和收藏都会保留，随时可以重新连接。」「取消」「断开连接」

**三条文案边界（不可越线）**
1. **不承诺「导入书签」**——书签只有数量、拿不到内容。
2. **不只写「划线」一个数字**——想法是独立数字，合并写会对不上。
3. **进度主数字 = 实际入库条数（划线 + 想法）**，笔记总数含书签，只能作次级说明、绝不当导入量。

---

## 10. 可访问性

- 所有纯图标按钮必须有中文 `accessibilityLabel`（见各屏）；SF Symbols 用 `.accessibilityLabel()` 覆盖默认英文名。
- 引用竖线、状态点、封面占位、骨架一律 `.accessibilityHidden(true)`；状态语义必须由文字承载。
- **颜色不单独表意**：收藏 = `star.fill` +「已收藏」；错误 = `xmark.circle` + 文字；连接状态 = 状态点 +「已连接/已断开」。
- 进度条 `.accessibilityValue("已完成 62%")`；大数字读完整单位「已整理 1,284 条」；统计读「38 条划线」。
- 列表行合并为一个无障碍元素，VoiceOver 焦点顺序自上而下、与视觉一致。
- Dynamic Type 到 `.accessibility3`：不截断任何原文/备注/计数；`accessibility2` 起摘录列表精简为原文 + 书名。
- `@Environment(\.accessibilityReduceMotion)`：关闭全部自定义动画（系统 push 保留）。
- `@Environment(\.accessibilityReduceTransparency)`：无材质使用，无需降级。
- 最小点击区 44 × 44；对比度全部 ≥ 4.5:1（第 2.2 节实测）。

---

## 11. SF Symbols 清单

| 用途 | Symbol | 尺寸 / 色 |
|---|---|---|
| 返回 / 进入 | `chevron.left` / `chevron.right` | 20 / 17，`accent` / `ink3` |
| 展开筛选 | `chevron.down` | 12，`ink2` |
| 搜索 | `magnifyingglass` | 16（框内）/ 42（空态），`ink3` |
| 收藏 | `star.fill` / `star` | 14–21，`accent` / `ink3` |
| 设置 Tab / 图标 | `gear` | 23，`accent` / `ink3` |
| 书架 Tab / 空态 | `books.vertical` | 23 / 44，`ink3` |
| 摘录 Tab | `quote.bubble` | 23 |
| 引导功能图标 | `quote.bubble`、`iphone`、`note.text` | 26，`accent` |
| 备注 / 有备注 | `note.text` | 15–19，`ink3` |
| 标签 | `tag` | 13–15，`ink2` |
| 添加 | `plus` | 13，`accent` |
| 重新同步 / 重新导入 | `arrow.triangle.2.circlepath` | 18–21，`accent` / `ink3` |
| 完成 | `checkmark.circle` | 16，`success` |
| 错误 | `xmark.circle` | 17，`error` |
| 关闭 / 停止 | `xmark` | 16，`ink` |
| 显隐 Key | `eye` / `eye.slash` | 20，`ink2` |
| 本地 / 隐私 | `lock` | 19，`ink3` |
| 筛选 / 排序 | `line.3.horizontal.decrease` / `arrow.up.arrow.down` | 20，`accent` |
| 想法 | `bubble.left` | 14，`ink2` |
| API Key | `key` | 17，`ink2` |
| 更多 | `ellipsis` | 20，`ink3` |
| 删除 | `trash` | 17，`error` |

样图里的图标是内联 SVG 示意；**SwiftUI 一律用上表 SF Symbols**，不用图片、不用自定义路径。

---

## 12. 与开发接口对齐（Pluso 五问 + 两条补充）

| 接口事实 | 设计决定 |
|---|---|
| 实际入库条数 vs 笔记总数（含书签） | 进度页主数字 = 入库条数；总数只可作带「含书签」说明的次级脚注，不同屏争夺主次 |
| 一条划线可挂多条想法 | 列表折叠（条数 + 首条摘要）；详情逐条展开「想法 1 / 想法 2…」 |
| 未关联想法两种（range 空 / 有 range 未匹配） | 同一套独立想法版式，统一标注「独立想法 · 未关联划线」，**暂不区分文案**；预留一行默认隐藏的次级说明位，实测第二种偏多再启用 |
| idle / 加载(进度) / 完成 / 失败 四态 | 同步页四态齐全，失败态留「原样展示接口中文提示」文案位 |
| 断连只清 Key、不删数据 | 系统 alert 确认，正文明确写「摘录、备注、标签、收藏都会保留」；确认后进 signed-out 态 |
| `Quote` / `QuoteAnnotation` 分离 | 视觉上「原文 + 想法」与「备注 / 标签 / 收藏」分成不同区块，同步不覆盖后者 |
| `/user/notebooks` 只有有笔记的书 | 书架只列这个集合，计数写「划线 N · 想法 N」，不写合并「笔记数」 |

---

## 13. 样图清单（393 × 852 pt）

| 文件 | 内容 | 模式 |
|---|---|---|
| 01-onboarding | 连接介绍页 | 浅 |
| 02-key-input | Key 输入 · idle | 浅 |
| 03-key-verifying | Key 输入 · 验证中 | 浅 |
| 04-key-failed | Key 输入 · 失败 | 浅 |
| 05-sync-running | 同步 · 进行中 | 浅 |
| 06-sync-done | 同步 · 完成 | 浅 |
| 07-sync-stop | 同步 · 停止确认 | 浅 |
| 08-shelf | 书架列表 | 浅 |
| 09-shelf-empty | 书架 · 空态 | 浅 |
| 10-book-detail | 书籍详情 | 浅 |
| 11-quote-list | 摘录列表 · 筛选搜索 | 浅 |
| 12-quote-noresult | 摘录 · 搜索无结果 | 浅 |
| 13-quote-loading | 摘录 · 加载骨架 | 浅 |
| 14-quote-detail | 摘录详情 | 浅 |
| 15-settings | 设置 / 断开连接 | 浅 |
| 16-shelf-dark | 书架（深色对照） | 深 |
| 17-quote-detail-dark | 摘录详情（深色对照） | 深 |

样图为设计示意，示例数据（书名、条数、日期、Key 掩码）均为占位，不代表真实接口返回；Key 掩码是虚构的，不含任何真实凭证。

---

## 14. 验收对照

- brief 第八节第 5 条：封面不闪烁 → 7.4 规定异步加载期间保持 `accentSoft` 首字占位 / `.redacted`，不闪白；列表滚动流畅 → 行内不用阴影/材质/渐层，行高固定、无离屏渲染负担。
- brief 第八节第 7 条：所有页面视觉语言一致 → 第 2/3/4 节单一色板、单一强调色、统一字阶、统一间距与圆角，17 张样图为基准。
- 中文搜索：7.6 搜索框 + 实时过滤，不卡顿由实现侧保证，视觉侧不加重组件层级。
- 详情阅读进度：7.5 用 0–100 整数带 `%`，与接口 `progress` 口径一致。
- 备注重新同步后仍在：7.7 把备注/标签/收藏独立成区块，对应 `QuoteAnnotation` 不被同步覆盖。

---

## 15. 参考与未决

- 风格依据：`brief.md` 第七节（用户原话）、`brief-addendum-ato.md`（Ato 对 `Tencent/WeChatReading` skills/ 的核实）。
- 参考研究：Apple 系统字阶与原生 `Form`/`NavigationStack`/`TabView` 行为、阅读类 App 的留白与衬线原文处理。样图未复用任何第三方素材。
- 未决（不挡实现）：官方获取入口已由 Ato 核实为 https://weread.qq.com/r/weread-skills；「有 range 未匹配」的次级说明是否启用待真实数据实测。
- 已知范围外：分享卡片、拍照 OCR（模型已预留 `QuoteSource.scan`，视觉未画）；iPad / 横屏 / 灵动岛适配不在本轮。


---

## 16. 拟物书架修订（2026-11-03）

本节取代第 1 节中书架页的“无渐变、无投影、无纹理”限制，以及第 7.4 节原列表版式。其余七屏仍遵守原限制。完整实现值见随稿附件 `bookshelf-v2.md`。整体浅色底更新为 `#F8F8F4`，surface `#FFFFFF`，surfaceAlt `#F0F0EC`，accentSoft `#EDE6DF`，border `#E4E4E0`；书架内容区改为代码绘制木质层板与真实封面正面陈列。
