# 纸间（ZhiJian）— 项目 Brief

版本：v1（2026-11-03）
负责人：Jerry（项目协调）
实现：@developer（Pluso）
设计：@design（Colo）

---

## 一、目标与用户

一句话：帮读书人把微信读书里划过的线、写过的想法收集起来，整理、回看、做成卡片。

核心理念：让值得记住的文字，在纸间留下痕迹。

用户画像：本人（Jerry Martin），正在学 iOS 开发的个人开发者。既是使用者也是开发者。
这一点影响交付方式：每一步都要"先讲思路，再给代码"，关键技术和易错点要讲清楚，不要一次性倒出整个 App。

## 二、要解决的问题

微信读书的划线和想法锁在微信读书里，散落在几十上百本书里，没法统一管理、搜索、回顾。纸间把它们导出来，变成自己能整理、能搜索、能分享的资产。

## 三、本轮 MVP 范围（用户已确认：步骤 1–7）

只做微信读书导入 + 摘录浏览管理。

包含：
1. 网络层地基（统一网关、错误拦截）
2. API Key 输入 / 验证 / Keychain 存储 / 断开连接
3. SwiftData 模型层
4. 导入管线（书架 → 有笔记的书 → 划线 + 想法 → 关联 → 落库）
5. 书架列表与书籍详情
6. 摘录列表：筛选、搜索、关联想法、备注、标签、收藏、排序
7. Theme 视觉统一

不包含（后续阶段，但模型已预留）：
- 分享卡片（第三阶段）
- 纸质书拍照 OCR（第四阶段）— 模型已预留 `QuoteSource.scan`

## 四、技术选型

| 项 | 选择 |
|---|---|
| 最低系统 | iOS 17+（SwiftData 与 `@Attribute(.unique)` 均需 17） |
| 语言 / UI | Swift + SwiftUI |
| 持久化 | SwiftData |
| 并发 | Swift Concurrency（async/await、TaskGroup 分批限流） |
| 凭证存储 | Keychain（`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`） |
| 网络 | URLSession |
| 解析 | Codable |
| 依赖 | 无第三方依赖 |
| Bundle ID | `com.jerry.zhijian-k7m2` |
| 交付 | Simulator 演示 |

不需要账号体系（AirHost）、不需要 AI（AirRouter）、不需要后端。数据全在本地。

## 五、微信读书 API（已核实，勿凭记忆改动）

事实来源：腾讯官方仓库 `Tencent/WeChatReading` → `skills/`（version **1.0.5**）。
完整速查表在 Jerry 工作区 `notes/weread-api.md`，实现前必读。

入口：`POST https://i.weread.qq.com/api/agent/gateway`
鉴权：`Authorization: Bearer <wrk-xxxxxxxx>`

### 硬性规则
- 业务参数必须与 `api_name`、`skill_version` **平铺**在 body 顶层。包进 `params` 会让分页静默失效。
- 每次请求必带 `"skill_version": "1.0.5"`。
- 回包出现 `upgrade_info` → 立即暂停，按 `upgrade_info.message` 提示升级。
- `errcode` 非 0 即错误。**完整错误码表官方未提供，不要编造。**

### 使用到的接口
| 用途 | api_name | 参数 |
|---|---|---|
| 验证 Key + 书架 | `/shelf/sync` | 无 |
| 有笔记的书 | `/user/notebooks` | `count`、`lastSort`（游标） |
| 单书划线 | `/book/bookmarklist` | `bookId` |
| 单书想法 | `/review/list/mine` | **`bookid`（全小写）**、`synckey`、`count` |
| 书籍详情 | `/book/info` | `bookId` |

### 易错点（实现时对照检查）
- `/review/list/mine` 是 `bookid` 全小写，`/book/bookmarklist` 是 `bookId`。写错静默返回空。
- `/user/notebooks` 只认 `count` + `lastSort` 游标，禁止 `offset`/`limit`。
- `/review/list/mine` 分页用 `synckey`，与上者是两套游标。
- `noteCount` 只是划线条数，不是总笔记数。总数 = `reviewCount + noteCount + bookmarkCount`。
- `reviewCount` 已含个人点评，不要再额外加点评数。
- 书签只有数量、拿不到内容 → 产品文案不要承诺导入书签。
- `progress` 是 0–100 整数（1 = 1%），只有 100 且有 `finishTime` 才算读完。
- 时间戳统一在 DTO→Model 映射处转 `Date`；展示转 `YYYY-MM-DD`。
- 日志禁止出现 API Key；打印 error 只打 `errcode` 和 `api_name`。

### 导入流程（顺序不能改）
```
/shelf/sync        → 书架（同时验证 Key）
/user/notebooks    → 只拿「有笔记的书」，游标翻到 hasMore=0
对每一本：
  /book/bookmarklist → 划线
  /review/list/mine  → 想法
```
不要遍历整个书架逐本查笔记。书架可能几百本，有笔记的通常几十本。

## 六、数据模型（关键设计决定）

### 决定 1：网络数据 与 用户自有数据 必须分离
备注、标签、收藏**不能**挂在会被同步覆盖的模型上，否则下一次同步就冲掉了。

```
Quote（网络数据：markText / range / chapterUid / createTime …）
   ↓ 一对一
QuoteAnnotation（纯本地：note / tags / isFavorite）
```
同步只写 `Quote`，永不触碰 `QuoteAnnotation`。

### 决定 2：唯一约束保证同步幂等
- `Book.bookId` → unique
- `Quote.bookmarkId` → unique
- `Thought.reviewId` → unique
注意：unique 约束下撞 ID 会抛错，`context.save()` 必须捕获处理，不能无脑 save。

### 决定 3：预留来源字段
```swift
enum QuoteSource: Codable { case weread, scan }
```
第四阶段拍照 OCR 不用迁移整张表。

### 决定 4：级联删除
Book → Quote 用 `.cascade`；Quote → Book 用 `.nullify`。

### 决定 5：划线 ↔ 想法关联
用 `(bookId, chapterUid, range)` 三元组匹配。划线 `updated[].range` 与想法 `review.range` 格式相同（如 `"2959-3007"`）。
`abstract` / `range` 是**条件字段**（整本书评可能为空），匹配不上的想法 `quoteId = nil` 单独展示，不丢弃。

### 决定 6：页面状态用枚举
不用 `isLoading/isError/isEmpty` 多个 Bool（会出现矛盾组合）。
```swift
enum LoadState { case idle, loading(progress: SyncProgress), loaded, failed(WeReadError) }
```

### 决定 7：并发
- 逐本串行太慢 → `TaskGroup` + 分批限流（每批 4–6 本，批内并发）。不要无界并发，会被限流。
- 同步可取消：每本书之间 `Task.checkCancellation()`。
- JSON 解析不要放 MainActor；DTO→Model 映射放后台 context。
- 进度用 `AsyncStream<SyncProgress>` 吐出，ViewModel 订阅后主线程更新 UI。Service 不直接改 `@Published`。

## 七、设计要求（用户给定，@design 细化为可执行 spec）

风格：简洁、温暖、安静、有阅读氛围。
- Apple 原生设计语言、极简主义
- 温暖米白背景，深灰/暖黑文字
- 低饱和棕色作为强调色
- 留白充足，字体层级精致
- 柔和圆角，克制用图标
- 流畅自然的页面转场

避免：页面拥挤、过多卡片和分割线、滥用渐变阴影、装饰元素过多、复杂导航层级、后台管理系统风格。

所有页面统一设计语言，优先 iPhone 单手操作。

## 八、功能验收标准

| # | 验收项 |
|---|---|
| 1 | 请求 `/shelf/sync` 能正确解析；错误 Key 返回明确鉴权错误；日志无 Key 泄漏 |
| 2 | 错误 Key 不落盘；正确 Key 保存后杀 App 重进仍是已连接；断开后 Key 确实从 Keychain 消失 |
| 3 | 连续插入相同 `bookmarkId` 不产生重复；删 Book 后其 Quote/Thought 一并消失 |
| 4 | 几十本有笔记的书能完整导入，条数与微信读书端一致；中断后重跑不产生重复；中途取消立刻停 |
| 5 | 封面不闪烁、列表滚动流畅；详情正确显示阅读进度（0–100 整数带 %） |
| 6 | 中文搜索无卡顿；编辑备注后重新同步备注还在；关联想法正确挂在对应划线下 |
| 7 | 所有页面视觉语言一致 |

## 九、风险与未确认项

1. **第三方 App 直连该网关的授权问题（最大未确认项）**。官方 skill 文档是给 Agent/服务端场景写的（curl + 环境变量），文档没有任何条款说明是否允许第三方 iOS App 直接调用。技术上可行，MVP 直连是最简单路径。**上 App Store 前必须确认，或改为自有服务端转发。**
2. `errcode` 完整错误码表不存在 → 错误分类只能按可观察行为做：鉴权类（提示重输 Key）、网络类（提示重试）、`upgrade_info`（提示升级）、其余（展示原始中文提示）。
3. 书籍正文版权边界：划线原文是用户自产片段且量小，通常没问题。`/book/bestbookmarks`（热门划线）是他人公开内容，性质不同，本轮不做。
4. App 依赖用户自备 API Key → 上架时需提供审核备注说明与演示路径。

## 十、协作要求（用户明确要求）

每一步交付前说明：本次目标、涉及文件、实现方案、关键技术选择。
每一步交付后提供：完整代码、每个文件的准确路径、关键代码与设计原因的解释、与现有项目的兼容性检查、运行与测试步骤、已知问题与下一步计划。

修改时：先定位根因并解释，再给最小必要修改；不要未经说明重写整个项目；不要删除已实现的功能。

代码质量：避免强制解包；正确使用 async/await 与 MainActor；不空 catch；网络/文件/Keychain 不用 `try!`；不用模拟数据冒充真实 API 数据；不重复定义已有模型和服务；不用过时 SwiftUI API。

沟通语言：中文。
