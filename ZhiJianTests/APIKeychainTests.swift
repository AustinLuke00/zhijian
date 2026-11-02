import Foundation
import Testing

@testable import ZhiJian

struct APIKeychainTests {

    @Test
    func acceptsPrefixedKey() {
        #expect(APIKeychain.looksLikeKey("wrk-abcdefg"))
    }

    @Test
    func trimsSurroundingWhitespace() {
        // 从微信读书页面复制出来经常带空白，不该因此判为非法
        #expect(APIKeychain.looksLikeKey("  wrk-abcdefg \n"))
    }

    @Test
    func rejectsWrongPrefix() {
        #expect(!APIKeychain.looksLikeKey("sk-abcdefg"))
        #expect(!APIKeychain.looksLikeKey("abcdefg"))
    }

    @Test
    func rejectsPrefixOnly() {
        #expect(!APIKeychain.looksLikeKey("wrk-"))
        #expect(!APIKeychain.looksLikeKey("wrk-   "))
    }

    @Test
    func rejectsEmpty() {
        #expect(!APIKeychain.looksLikeKey(""))
        #expect(!APIKeychain.looksLikeKey("   "))
    }
}
