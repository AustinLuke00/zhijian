import Foundation

/// 网络传输的抽象。
///
/// 存在的唯一理由：让 `WeReadGateway` 能在测试里用假回包跑完整条链路
/// —— 参数平铺、错误拦截顺序、errcode 判定 —— 而不需要真网络和真 Key。
/// 真机/模拟器上换回 `URLSessionTransport` 即可。
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// 真实的 URLSession 传输。
struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
