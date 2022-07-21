@testable import Boutique
import Combine
import XCTest

final class BoutiqueTests: XCTestCase {

    private var store: Store<BoutiqueItem>!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        store = Store<BoutiqueItem>(
            storagePath: FileManager.Directory.temporary(appendingPath: "Tests").url,
            cacheIdentifier: \.merchantID
        )

        try await store.removeAll()
    }

    @MainActor
    func testAddingItem() async throws {
        try await store.add(Self.coat)
        XCTAssert(store.items.contains(Self.coat))
    }

    @MainActor
    func testAddingItems() async throws {
        try await store.add([Self.coat, Self.sweater, Self.sweater, Self.purse])
        XCTAssert(store.items.contains(Self.coat))
        XCTAssert(store.items.contains(Self.sweater))
        XCTAssert(store.items.contains(Self.purse))
    }

    @MainActor
    func testAddingDuplicateItems() async throws {
        XCTAssert(store.items.isEmpty)
        try await store.add(Self.allObjects)
        XCTAssert(store.items.count == 4)
    }

    @MainActor
    func testReadingItems() async throws {
        try await store.add(Self.allObjects)

        XCTAssert(store.items[0] == Self.coat)
        XCTAssert(store.items[1] == Self.sweater)
        XCTAssert(store.items[2] == Self.purse)
        XCTAssert(store.items[3] == Self.belt)

        XCTAssert(store.items.count == 4)
    }

    @MainActor
    func testRemovingItems() async throws {
        try await store.add(Self.allObjects)
        try await store.remove(Self.coat)

        XCTAssertFalse(store.items.contains(Self.coat))

        XCTAssert(store.items.contains(Self.sweater))
        XCTAssert(store.items.contains(Self.purse))

        try await store.remove([Self.sweater, Self.purse])
        XCTAssertFalse(store.items.contains(Self.sweater))
        XCTAssertFalse(store.items.contains(Self.purse))
    }

    @MainActor
    func testRemoveAll() async throws {
        try await store.add(Self.coat)
        XCTAssert(store.items.count == 1)
        try await store.removeAll()

        try await store.add(Self.uniqueObjects)
        XCTAssert(store.items.count == 4)
        try await store.removeAll()
        XCTAssert(store.items.isEmpty)
    }

    @MainActor
    func testRemoveNoneItemRemovalStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)

        try await store.add(BoutiqueTests.allObjects, removingExistingItems: nil)
        XCTAssert(store.items.contains(gloves))
    }

    @MainActor
    func testRemoveItemsItemRemovalStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssert(store.items.contains(gloves))

        let duplicateGloves = BoutiqueItem(merchantID: "1000", value: "Gloves")
        try await store.add(duplicateGloves, removingExistingItems: .items([gloves]))

        XCTAssertFalse(store.items.contains(where: { $0.merchantID == "999" }))

        XCTAssert(store.items.contains(where: { $0.merchantID == "1000" }))
    }

    @MainActor
    func testRemoveWhereItemRemovalStrategy() async throws {
        try await store.add([Self.belt, Self.coat])

        try await store.add(Self.belt, removingExistingItems: .items(where: { $0.merchantID == Self.coat.merchantID }))
        XCTAssertTrue(store.items.contains(Self.belt))
        XCTAssertFalse(store.items.contains(Self.coat))
    }

    @MainActor
    func testCustomItemRemovalStrategy() async throws {
        try await store.add(Self.uniqueObjects)
        XCTAssertEqual(store.items, Self.uniqueObjects)

        // A new array that is distinctly missing coat and sweater
        let sunglasses = BoutiqueItem(merchantID: "5", value: "Sunglasses")
        let accessories = [Self.belt, Self.purse, sunglasses]
        let allAvailableItems = Self.uniqueObjects + [sunglasses]

        // Add those accessories into the Store
        try await store.add(accessories)
        XCTAssertEqual(store.items, allAvailableItems)

        // Add those those accessories into the Store again, this time using
        // a custom removal policy we created below
        try await store.add(accessories, removingExistingItems: .removeWinterClothes)

        // Confirm that the winter items are indeed gone
        XCTAssertTrue(store.items.contains(Self.belt))
        XCTAssertTrue(store.items.contains(Self.purse))
        XCTAssertFalse(store.items.contains(Self.sweater))
        XCTAssertFalse(store.items.contains(Self.coat))
    }

    @MainActor
    func testRemoveAllItemRemovalStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssert(store.items.contains(gloves))

        try await store.add(BoutiqueTests.allObjects, removingExistingItems: .all)
        XCTAssertFalse(store.items.contains(gloves))
    }

    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueObjects = Self.uniqueObjects
        let expectation = XCTestExpectation(description: "uniqueObjects is published and read")

        store.$items
            .dropFirst()
            .sink(receiveValue: { items in
                XCTAssertTrue(items == uniqueObjects)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        XCTAssert(store.items.isEmpty)

        // Sets items under the hood
        try await store.add(uniqueObjects)
        wait(for: [expectation], timeout: 1)
    }

}

private struct BoutiqueItem: Codable, Equatable {
    let merchantID: String
    let value: String
}

private extension BoutiqueTests {

    static let coat = BoutiqueItem(
        merchantID: "1",
        value: "Coat"
    )

    static let sweater = BoutiqueItem(
        merchantID: "2",
        value: "Sweater"
    )

    static let purse = BoutiqueItem(
        merchantID: "3",
        value: "Purse"
    )

    static let belt = BoutiqueItem(
        merchantID: "4",
        value: "Belt"
    )

    static let duplicateBelt = BoutiqueItem(
        merchantID: "4",
        value: "Belt"
    )

    static let allObjects = [
        BoutiqueTests.coat,
        BoutiqueTests.sweater,
        BoutiqueTests.purse,
        BoutiqueTests.belt,
        BoutiqueTests.duplicateBelt
    ]

    static let uniqueObjects = [
        BoutiqueTests.coat,
        BoutiqueTests.sweater,
        BoutiqueTests.purse,
        BoutiqueTests.belt,
    ]

}

private extension Store.ItemRemovalStrategy {

    static var removeWinterClothes: Store.ItemRemovalStrategy<BoutiqueItem> {
        return .init { items in
            items.filter({ $0.merchantID != BoutiqueTests.coat.merchantID && $0.merchantID != BoutiqueTests.sweater.merchantID })
        }
    }

}
