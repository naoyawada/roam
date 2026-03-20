import XCTest
import SwiftData
@testable import Roam

@MainActor
final class CityColorServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([NightLog.self, CityColor.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    // MARK: - Tests

    func testAssignMissingColors_newCities() {
        let log1 = NightLog(date: noonUTC(2026, 3, 10), city: "Atlanta", state: "GA", country: "US")
        let log2 = NightLog(date: noonUTC(2026, 3, 11), city: "Asheville", state: "NC", country: "US")
        context.insert(log1)
        context.insert(log2)
        try! context.save()

        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>(sortBy: [SortDescriptor(\.colorIndex)]))
        XCTAssertEqual(colors.count, 2)
        XCTAssertEqual(colors[0].colorIndex, 0)
        XCTAssertEqual(colors[1].colorIndex, 1)

        let keys = Set(colors.map(\.cityKey))
        XCTAssertTrue(keys.contains(CityDisplayFormatter.cityKey(city: "Atlanta", state: "GA", country: "US")))
        XCTAssertTrue(keys.contains(CityDisplayFormatter.cityKey(city: "Asheville", state: "NC", country: "US")))
    }

    func testAssignMissingColors_existingColorsPreserved() {
        let existingKey = CityDisplayFormatter.cityKey(city: "Atlanta", state: "GA", country: "US")
        let existing = CityColor(cityKey: existingKey, colorIndex: 0)
        context.insert(existing)

        let log = NightLog(date: noonUTC(2026, 3, 12), city: "Asheville", state: "NC", country: "US")
        context.insert(log)
        try! context.save()

        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>(sortBy: [SortDescriptor(\.colorIndex)]))
        XCTAssertEqual(colors.count, 2)

        let atlantaColor = colors.first { $0.cityKey == existingKey }
        XCTAssertNotNil(atlantaColor)
        XCTAssertEqual(atlantaColor?.colorIndex, 0)

        let newKey = CityDisplayFormatter.cityKey(city: "Asheville", state: "NC", country: "US")
        let ashevilleColor = colors.first { $0.cityKey == newKey }
        XCTAssertNotNil(ashevilleColor)
        XCTAssertEqual(ashevilleColor?.colorIndex, 1)
    }

    func testAssignMissingColors_duplicateCitiesGetOneColor() {
        let log1 = NightLog(date: noonUTC(2026, 3, 10), city: "Atlanta", state: "GA", country: "US")
        let log2 = NightLog(date: noonUTC(2026, 3, 11), city: "Atlanta", state: "GA", country: "US")
        let log3 = NightLog(date: noonUTC(2026, 3, 12), city: "Atlanta", state: "GA", country: "US")
        context.insert(log1)
        context.insert(log2)
        context.insert(log3)
        try! context.save()

        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>())
        XCTAssertEqual(colors.count, 1)
        XCTAssertEqual(colors[0].cityKey, CityDisplayFormatter.cityKey(city: "Atlanta", state: "GA", country: "US"))
        XCTAssertEqual(colors[0].colorIndex, 0)
    }

    func testAssignMissingColors_nilCitySkipped() {
        let log = NightLog(date: noonUTC(2026, 3, 10), status: .unresolved)
        context.insert(log)
        try! context.save()

        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>())
        XCTAssertEqual(colors.count, 0)
    }

    func testAssignMissingColors_alreadyAssigned_noNewColors() {
        let key = CityDisplayFormatter.cityKey(city: "Atlanta", state: "GA", country: "US")
        let existing = CityColor(cityKey: key, colorIndex: 0)
        context.insert(existing)

        let log = NightLog(date: noonUTC(2026, 3, 10), city: "Atlanta", state: "GA", country: "US")
        context.insert(log)
        try! context.save()

        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>())
        XCTAssertEqual(colors.count, 1)
        XCTAssertEqual(colors[0].cityKey, key)
        XCTAssertEqual(colors[0].colorIndex, 0)
    }

    func testAssignMissingColors_emptyDatabase() {
        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>())
        XCTAssertEqual(colors.count, 0)
    }

    func testAssignMissingColors_colorIndexContinuesFromMax() {
        let color1 = CityColor(cityKey: CityDisplayFormatter.cityKey(city: "Atlanta", state: "GA", country: "US"), colorIndex: 0)
        let color2 = CityColor(cityKey: CityDisplayFormatter.cityKey(city: "Asheville", state: "NC", country: "US"), colorIndex: 5)
        context.insert(color1)
        context.insert(color2)

        let log = NightLog(date: noonUTC(2026, 3, 15), city: "Denver", state: "CO", country: "US")
        context.insert(log)
        try! context.save()

        CityColorService.assignMissingColors(context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>(sortBy: [SortDescriptor(\.colorIndex)]))
        XCTAssertEqual(colors.count, 3)

        let newKey = CityDisplayFormatter.cityKey(city: "Denver", state: "CO", country: "US")
        let denverColor = colors.first { $0.cityKey == newKey }
        XCTAssertNotNil(denverColor)
        XCTAssertEqual(denverColor?.colorIndex, 6)
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
