import Foundation
import Testing
@testable import AnimeMemo

struct HomeScheduleBuilderTests {
    private var shanghaiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }

    private func date(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return try #require(formatter.date(from: string))
    }

    @Test
    func bangumiScheduleStartsTodayAndSortsByHeat() throws {
        let json = """
        [
          {"weekday":{"id":1,"cn":"星期一"},"items":[
            {"id":11,"name":"周一番","collection":{"doing":1}}
          ]},
          {"weekday":{"id":2,"cn":"星期二"},"items":[
            {"id":12,"name":"周二番","collection":{"doing":1}}
          ]},
          {"weekday":{"id":3,"cn":"星期三"},"items":[
            {"id":13,"name":"周三番","collection":{"doing":1}}
          ]},
          {"weekday":{"id":4,"cn":"星期四"},"items":[
            {"id":14,"name":"周四番","collection":{"doing":1}}
          ]},
          {"weekday":{"id":5,"cn":"星期五"},"items":[
            {"id":21,"name":"低热度","rating":{"score":9.0},"collection":{"doing":10}},
            {"id":22,"name":"高热度","rating":{"score":7.0},"collection":{"doing":300}},
            {"id":23,"name":"中热度","rating":{"score":8.5},"collection":{"doing":100}}
          ]},
          {"weekday":{"id":6,"cn":"星期六"},"items":[
            {"id":16,"name":"周六番","collection":{"doing":1}}
          ]},
          {"weekday":{"id":7,"cn":"星期日"},"items":[
            {"id":17,"name":"周日番","collection":{"doing":1}}
          ]}
        ]
        """

        let calendarDays = try JSONDecoder().decode(
            [BangumiCalendarDay].self,
            from: Data(json.utf8)
        )

        let result = HomeScheduleBuilder.days(
            from: calendarDays,
            now: try date("2026-10-23 12:00"),
            calendar: shanghaiCalendar,
            limitPerDay: 2
        )

        #expect(result.map(\.weekday) == [5, 6, 7, 1, 2, 3, 4])
        #expect(result.map(\.relativeOffset) == [0, 1, 2, 3, 4, 5, 6])
        #expect(result.first?.title == "今天")
        #expect(result.first?.dateLabel == "10/23")

        let friday = try #require(result.first)
        #expect(friday.items.map(\.title) == ["高热度", "中热度", "低热度"])
        #expect(friday.previewItems.map(\.title) == ["高热度", "中热度"])
        #expect(friday.totalCount == 3)
        #expect(friday.remainingCount == 1)
        #expect(friday.sheetTitle == "今天 · 周五")
    }

    @Test
    func tmdbScheduleGroupsByPremiereWeekday() throws {
        let json = """
        {
          "page": 1,
          "results": [
            {
              "id": 31,
              "name": "周五热番",
              "first_air_date": "2026-10-02",
              "genre_ids": [16],
              "vote_average": 8.4,
              "original_language": "ja"
            },
            {
              "id": 32,
              "name": "周一热番",
              "first_air_date": "2026-09-28",
              "genre_ids": [16],
              "vote_average": 8.1,
              "original_language": "ja"
            },
            {
              "id": 33,
              "name": "非动画",
              "first_air_date": "2026-10-01",
              "genre_ids": [18],
              "original_language": "ja"
            }
          ],
          "total_pages": 1,
          "total_results": 3
        }
        """

        let page = try JSONDecoder().decode(
            TMDBPage<TMDBMediaSummary>.self,
            from: Data(json.utf8)
        )

        let result = HomeScheduleBuilder.days(
            from: page.results,
            now: try date("2026-10-23 12:00"),
            calendar: shanghaiCalendar
        )

        #expect(result.map(\.weekday) == [5, 1])
        #expect(result.map(\.relativeOffset) == [0, 3])
        #expect(result.first?.items.first?.title == "周五热番")
        #expect(result.flatMap(\.items).contains { $0.title == "非动画" } == false)
    }

    @Test
    func calendarItemsDecodeDoingCount() throws {
        let json = """
        {
          "id": 400602,
          "name": "Sousou no Frieren",
          "name_cn": "葬送的芙莉莲",
          "rating": {"score": 8.8},
          "collection": {"wish": 10, "collect": 20, "doing": 321, "on_hold": 4, "dropped": 2},
          "rank": 12
        }
        """

        let subject = try JSONDecoder().decode(BangumiSubject.self, from: Data(json.utf8))
        #expect(subject.doingCount == 321)
        #expect(subject.rank == 12)
    }
}
