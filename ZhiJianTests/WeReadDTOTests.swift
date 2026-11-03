import Foundation
import Testing

@testable import ZhiJian

struct WeReadDTOTests {
    @Test
    func bookmarkListSkipsMalformedItemsAndDecodesNumericStrings() throws {
        let json = #"""
        {
          "updated": [
            {"bookmarkId":"ok-1","chapterUid":"101","markText":"first","createTime":"1700000000","colorStyle":"2","type":"1"},
            {"bookmarkId":202,"chapterUid":102,"markText":"second","createTime":1700000001,"colorStyle":3,"type":1},
            {"chapterUid":103,"markText":"missing id"},
            {"bookmarkId":"bad-chapter","chapterUid":"not-a-number"},
            "not an object"
          ],
          "chapters": [
            {"chapterUid":"101","chapterIdx":"7","title":"One"},
            {"chapterUid":102,"chapterIdx":8,"title":"Two"},
            {"chapterIdx":9,"title":"missing uid"},
            {"chapterUid":"invalid","title":"bad uid"},
            null
          ]
        }
        """#

        let dto = try JSONDecoder().decode(BookmarkListDTO.self, from: Data(json.utf8))

        #expect(dto.updated?.count == 2)
        #expect(dto.updated?[0].bookmarkId == "ok-1")
        #expect(dto.updated?[0].chapterUid == 101)
        #expect(dto.updated?[0].createTime == 1_700_000_000)
        #expect(dto.updated?[0].colorStyle == 2)
        #expect(dto.updated?[0].type == 1)
        #expect(dto.updated?[1].bookmarkId == "202")
        #expect(dto.chapters?.count == 2)
        #expect(dto.chapters?[0].chapterUid == 101)
        #expect(dto.chapters?[0].chapterIdx == 7)
    }

    @Test
    func malformedOptionalFieldsDoNotDropOtherwiseValidItems() throws {
        let json = #"{"updated":[{"bookmarkId":"id","chapterUid":"5","markText":12,"createTime":"bad","range":{},"colorStyle":false,"type":[]}],"chapters":[{"chapterUid":"5","chapterIdx":"bad","title":9}]}"#
        let dto = try JSONDecoder().decode(BookmarkListDTO.self, from: Data(json.utf8))

        #expect(dto.updated?.count == 1)
        #expect(dto.updated?[0].markText == nil)
        #expect(dto.updated?[0].createTime == nil)
        #expect(dto.updated?[0].range == nil)
        #expect(dto.chapters?.count == 1)
        #expect(dto.chapters?[0].chapterIdx == nil)
        #expect(dto.chapters?[0].title == nil)
    }

    @Test
    func nonObjectTopLevelStillFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(BookmarkListDTO.self, from: Data(#"[]"#.utf8))
        }
    }
}
