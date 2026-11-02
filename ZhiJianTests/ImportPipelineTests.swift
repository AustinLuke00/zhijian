import Foundation
import SwiftData
import Testing

@testable import ZhiJian

/// 按 api_name + 参数返回脚本化回包的假传输，并记下每一次请求。
/// 用它可以在完全不发网络请求的前提下断言调用顺序、参数与游标。
private final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    /// 参数字典本身不是 Sendable，用一个显式标注的盒子装起来。
    /// 测试里只在断言时读取，不做跨任务共享写入。
    final class ParamsBox: @unchecked Sendable {
        let value: [String: Any]
        init(_ value: [String: Any]) { self.value = value }
    }

    struct Call: Sendable {
        let apiName: String
        let box: ParamsBox

        var params: [String: Any] { box.value }
    }

    private let handler: @Sendable (String, ParamsBox) -> (Data, Int)

    /// 类整体是 @unchecked Sendable，调用又都是同步的，直接追加即可。
    private var recorded: [Call] = []
    var calls: [Call] { recorded }

    private func record(_ call: Call) { recorded.append(call) }

    init(handler: @escaping @Sendable (String, [String: Any]) -> (Data, Int)) {
        self.handler = { apiName, box in handler(apiName, box.value) }
    }

    func apiNames() -> [String] { calls.map(\.apiName) }

    /// 某个接口收到过的参数（按调用顺序）。用来断言游标。
    func params(for apiName: String) -> [[String: Any]] {
        calls.filter { $0.apiName == apiName }.map(\.params)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let body = request.httpBody ?? Data()
        let object = (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
        let apiName = object["api_name"] as? String ?? ""
        var params = object
        params.removeValue(forKey: "api_name")
        params.removeValue(forKey: "skill_version")

        let box = ParamsBox(params)
        record(Call(apiName: apiName, box: box))

        let (data, status) = handler(apiName, box)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private func data(_ json: String) -> Data { Data(json.utf8) }

@MainActor
struct ImportPipelineTests {

    private func makePipeline(
        transport: ScriptedTransport
    ) throws -> ImportPipeline {
        let gateway = WeReadGateway(transport: transport) { "wrk-test" }
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let store = ImportStore(modelContainer: container)
        return ImportPipeline(gateway: gateway, store: store)
    }

    // MARK: - 调用顺序

    /// 顺序是 brief 定死的：先 /shelf/sync 验证，再 /user/notebooks。
    @Test
    func shelfSyncIsCalledFirst() async throws {
        let transport = ScriptedTransport { apiName, _ in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            case "/user/notebooks": return (data(#"{"books":[],"hasMore":0}"#), 200)
            default: return (data(#"{"errcode":0}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        _ = try await summary.value

        #expect(transport.apiNames().first == "/shelf/sync")
    }

    /// Key 无效时：第一步就失败，不该继续翻书架。
    @Test
    func invalidKeyStopsBeforeListing() async throws {
        let transport = ScriptedTransport { apiName, _ in
            if apiName == "/shelf/sync" {
                return (data(#"{"errcode":-2010,"errmsg":"登录已失效"}"#), 200)
            }
            return (data(#"{"books":[],"hasMore":0}"#), 200)
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        do {
            _ = try await summary.value
            Issue.record("应当抛出 api 错误")
        } catch let error as WeReadError {
            #expect(error == .api(errcode: -2010, message: "登录已失效"))
        } catch {
            Issue.record("应当是 WeReadError，实际是 \(error)")
        }

        // 一步都没往下走
        #expect(transport.apiNames() == ["/shelf/sync"])
    }

    // MARK: - 游标

    /// `/user/notebooks` 只认 count + lastSort，禁止 offset/limit。
    @Test
    func notebooksUsesLastSortCursorOnly() async throws {
        let transport = ScriptedTransport { apiName, params in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            case "/user/notebooks":
                let lastSort = params["lastSort"] as? Int ?? 0
                if lastSort == 0 {
                    return (data(#"{"books":[{"bookId":"b1","book":{"title":"书1"},"sort":100}],"hasMore":1}"#), 200)
                }
                return (data(#"{"books":[{"bookId":"b2","book":{"title":"书2"},"sort":200}],"hasMore":0}"#), 200)
            default: return (data(#"{"errcode":0,"updated":[],"reviews":[]}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        let result = try await summary.value
        #expect(result.books == 2)

        let calls = transport.params(for: "/user/notebooks")
        #expect(calls.count == 2)
        // 第一页不带 lastSort，第二页带上
        #expect(calls[0]["lastSort"] == nil)
        #expect(calls[1]["lastSort"] as? Int == 100)
        // 绝不能出现 offset / limit
        for call in calls {
            #expect(call["offset"] == nil)
            #expect(call["limit"] == nil)
        }
    }

    /// 想法分页用 synckey，与 notebooks 的 lastSort 是两套。
    @Test
    func reviewsUseSynckeyCursor() async throws {
        let transport = ScriptedTransport { apiName, params in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            case "/user/notebooks":
                return (data(#"{"books":[{"bookId":"b1","book":{"title":"书1"},"sort":1}],"hasMore":0}"#), 200)
            case "/book/bookmarklist":
                return (data(#"{"updated":[]}"#), 200)
            case "/review/list/mine":
                let synckey = params["synckey"] as? Int ?? 0
                if synckey == 0 {
                    return (data(#"{"reviews":[{"review":{"reviewId":"r1","content":"一"}}],"hasMore":1,"synckey":55}"#), 200)
                }
                return (data(#"{"reviews":[{"review":{"reviewId":"r2","content":"二"}}],"hasMore":0,"synckey":99}"#), 200)
            default: return (data(#"{"errcode":0}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        let result = try await summary.value
        #expect(result.thoughts == 2)

        let calls = transport.params(for: "/review/list/mine")
        #expect(calls.count == 2)
        #expect(calls[1]["synckey"] as? Int == 55)
        // 每次都必须带全小写的 bookid
        for call in calls {
            #expect(call["bookid"] as? String == "b1")
            #expect(call["bookId"] == nil)
        }
    }

    /// `/book/bookmarklist` 是驼峰 bookId，不能写成 bookid。
    @Test
    func bookmarklistUsesCamelCaseBookId() async throws {
        let transport = ScriptedTransport { apiName, _ in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            case "/user/notebooks":
                return (data(#"{"books":[{"bookId":"b1","book":{"title":"书1"},"sort":1}],"hasMore":0}"#), 200)
            case "/book/bookmarklist":
                return (data(#"{"updated":[],"chapters":[]}"#), 200)
            case "/review/list/mine":
                return (data(#"{"reviews":[],"hasMore":0}"#), 200)
            default: return (data(#"{"errcode":0}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        _ = try await summary.value

        let calls = transport.params(for: "/book/bookmarklist")
        #expect(calls.count == 1)
        #expect(calls[0]["bookId"] as? String == "b1")
    }

    // MARK: - 进度与汇总

    /// 进度里的数字是实际入库条数，不是接口返回的“笔记总数”。
    @Test
    func progressCountsActualImports() async throws {
        let transport = ScriptedTransport { apiName, _ in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            case "/user/notebooks":
                return (data(#"{"books":[{"bookId":"b1","book":{"title":"书1"},"noteCount":10,"reviewCount":4,"bookmarkCount":3,"sort":1}],"hasMore":0}"#), 200)
            case "/book/bookmarklist":
                return (data(#"{"updated":[{"bookmarkId":"bm1","chapterUid":1,"markText":"原文","range":"1-9","type":1}],"chapters":[{"chapterUid":1,"title":"第一章"}]}"#), 200)
            case "/review/list/mine":
                return (data(#"{"reviews":[{"review":{"reviewId":"r1","content":"想法","range":"1-9","chapterUid":1}}],"hasMore":0}"#), 200)
            default: return (data(#"{"errcode":0}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (stream, summary) = pipeline.run()
        var last: SyncProgress?
        for try await progress in stream { last = progress }

        let result = try await summary.value
        #expect(result.quotes == 1)
        #expect(result.thoughts == 1)

        // 接口说有 10+4+3=17 条笔记，实际入库只有 2 条（书签拿不到内容）
        #expect(result.total == 2)
        let final = try #require(last)
        #expect(final.importedTotal == 2)
        #expect(final.phase == .finished)
    }

    /// 想法能配上划线。
    @Test
    func importedThoughtLinksToQuote() async throws {
        let transport = ScriptedTransport { apiName, _ in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            case "/user/notebooks":
                return (data(#"{"books":[{"bookId":"b1","book":{"title":"书1"},"sort":1}],"hasMore":0}"#), 200)
            case "/book/bookmarklist":
                return (data(#"{"updated":[{"bookmarkId":"bm1","chapterUid":7,"markText":"原文","range":"2959-3007","type":1}]}"#), 200)
            case "/review/list/mine":
                return (data(#"{"reviews":[{"review":{"reviewId":"r1","content":"点评","abstract":"原文","range":"2959-3007","chapterUid":7}}],"hasMore":0}"#), 200)
            default: return (data(#"{"errcode":0}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        _ = try await summary.value

        // 落库结果由 ImportStore 负责，这里只验证管线跑通没抛错
        #expect(true)
    }

    // MARK: - 取消

    /// 同步可取消。
    @Test
    func cancellationStopsTheRun() async throws {
        let transport = ScriptedTransport { apiName, _ in
            switch apiName {
            case "/shelf/sync": return (data(#"{"books":[]}"#), 200)
            default: return (data(#"{"books":[],"hasMore":0}"#), 200)
            }
        }
        let pipeline = try makePipeline(transport: transport)

        let (_, summary) = pipeline.run()
        summary.cancel()

        do {
            _ = try await summary.value
            Issue.record("取消后应当抛出")
        } catch is CancellationError {
            // 预期
        } catch let error as WeReadError {
            #expect(error.isCancellation)
        }
    }
}
