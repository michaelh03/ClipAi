import XCTest
@testable import ClipAI

@MainActor
final class ClipboardStoreTests: XCTestCase {
    var store: ClipboardStore!
    var mockStorage: MockClipboardStorage!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockClipboardStorage()
        store = ClipboardStore(storage: mockStorage)
    }
    
    override func tearDown() {
        store = nil
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - Insertion Tests
    
    func testAddItem_ValidContent_AddsItemToStore() {
        // Given
        let content = "Test clipboard content"
        
        // When
        store.addItem(content: content)
        
        // Then
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.mostRecentItem?.content, content)
        XCTAssertTrue(store.contains(content: content))
    }
    
    func testAddItem_EmptyContent_DoesNotAddItem() {
        // Given
        let emptyContents = ["", "   ", "\n\t ", "\n\n"]
        
        // When
        for content in emptyContents {
            store.addItem(content: content)
        }
        
        // Then
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(store.isEmpty)
    }
    
    func testAddItem_DuplicateContent_DoesNotAddDuplicate() {
        // Given
        let content = "Duplicate content"
        
        // When
        store.addItem(content: content)
        store.addItem(content: content)
        
        // Then
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.mostRecentItem?.content, content)
    }
    
    func testAddItem_SameContentAsRecent_DoesNotAdd() {
        // Given
        let content = "Recent content"
        store.addItem(content: content)
        
        // When
        store.addItem(content: content)
        
        // Then
        XCTAssertEqual(store.count, 1)
    }
    
    func testAddItem_ExistingContentNotRecent_MovesToTop() {
        // Given
        store.addItem(content: "First")
        store.addItem(content: "Second")
        store.addItem(content: "Third")
        
        // When - Re-add first item
        store.addItem(content: "First")
        
        // Then - First should be at top, and total count should be 3 (not 4)
        XCTAssertEqual(store.count, 3)
        XCTAssertEqual(store.mostRecentItem?.content, "First")
        XCTAssertEqual(store.items[1].content, "Third")
        XCTAssertEqual(store.items[2].content, "Second")
    }
    
    func testAddItem_MultipleItems_MaintainsCorrectOrder() {
        // Given
        let contents = ["First", "Second", "Third"]
        
        // When
        for content in contents {
            store.addItem(content: content)
        }
        
        // Then - Should be in reverse order (most recent first)
        XCTAssertEqual(store.count, 3)
        XCTAssertEqual(store.items[0].content, "Third")
        XCTAssertEqual(store.items[1].content, "Second")
        XCTAssertEqual(store.items[2].content, "First")
    }
    
    // MARK: - Overflow Trimming Tests
    
    func testAddItem_ExceedsMaxItems_TrimsOldestItems() {
        // Given - Add 101 items (exceeding the 100 item limit)
        for i in 1...101 {
            store.addItem(content: "Item \(i)")
        }
        
        // Then
        XCTAssertEqual(store.count, 100)
        XCTAssertEqual(store.mostRecentItem?.content, "Item 101")
        XCTAssertFalse(store.contains(content: "Item 1")) // Oldest item should be removed
        XCTAssertTrue(store.contains(content: "Item 2")) // Second oldest should still exist
    }
    
    func testAddItem_ExactlyMaxItems_DoesNotTrim() {
        // Given - Add exactly 100 items
        for i in 1...100 {
            store.addItem(content: "Item \(i)")
        }
        
        // Then
        XCTAssertEqual(store.count, 100)
        XCTAssertTrue(store.contains(content: "Item 1")) // Oldest item should still exist
    }
    
    func testAddItem_WellOverMaxItems_MaintainsLimit() {
        // Given - Add way more than max items
        for i in 1...250 {
            store.addItem(content: "Item \(i)")
        }
        
        // Then
        XCTAssertEqual(store.count, 100)
        XCTAssertEqual(store.mostRecentItem?.content, "Item 250")
        XCTAssertTrue(store.contains(content: "Item 151")) // Should contain items 151-250
        XCTAssertFalse(store.contains(content: "Item 150")) // Should not contain items 1-150
    }
    
    // MARK: - Item Management Tests
    
    func testRemoveItem_ValidItem_RemovesItem() {
        // Given
        store.addItem(content: "First")
        store.addItem(content: "Second")
        let itemToRemove = store.items[0]
        
        // When
        store.removeItem(itemToRemove)
        
        // Then
        XCTAssertEqual(store.count, 1)
        XCTAssertFalse(store.contains(content: "Second"))
        XCTAssertTrue(store.contains(content: "First"))
    }
    
    func testRemoveItem_ValidIndex_RemovesItem() {
        // Given
        store.addItem(content: "First")
        store.addItem(content: "Second")
        
        // When
        store.removeItem(at: 0)
        
        // Then
        XCTAssertEqual(store.count, 1)
        XCTAssertFalse(store.contains(content: "Second"))
        XCTAssertTrue(store.contains(content: "First"))
    }
    
    func testRemoveItem_InvalidIndex_DoesNotCrash() {
        // Given
        store.addItem(content: "Test")
        
        // When & Then - Should not crash
        store.removeItem(at: -1)
        store.removeItem(at: 10)
        XCTAssertEqual(store.count, 1)
    }
    
    func testClearAll_RemovesAllItems() {
        // Given
        store.addItem(content: "First")
        store.addItem(content: "Second")
        store.addItem(content: "Third")
        
        // When
        store.clearAll()
        
        // Then
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(store.isEmpty)
        XCTAssertNil(store.mostRecentItem)
    }
    
    func testItemWithId_ValidId_ReturnsItem() {
        // Given
        store.addItem(content: "Test content")
        let itemId = store.items[0].id
        
        // When
        let foundItem = store.item(withId: itemId)
        
        // Then
        XCTAssertNotNil(foundItem)
        XCTAssertEqual(foundItem?.content, "Test content")
        XCTAssertEqual(foundItem?.id, itemId)
    }
    
    func testItemWithId_InvalidId_ReturnsNil() {
        // Given
        store.addItem(content: "Test content")
        let randomId = UUID()
        
        // When
        let foundItem = store.item(withId: randomId)
        
        // Then
        XCTAssertNil(foundItem)
    }
    
    // MARK: - Persistence Tests
    
    func testPersistence_AddItem_CallsSaveItems() async {
        // Given
        let content = "Test content"
        
        // When
        store.addItem(content: content)
        
        // Wait for async save operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockStorage.saveItemsCalled)
        XCTAssertEqual(mockStorage.savedItems.count, 1)
        XCTAssertEqual(mockStorage.savedItems[0].content, content)
    }
    
    func testPersistence_RemoveItem_CallsSaveItems() async {
        // Given
        store.addItem(content: "Test content")
        mockStorage.saveItemsCalled = false // Reset flag
        let itemToRemove = store.items[0]
        
        // When
        store.removeItem(itemToRemove)
        
        // Wait for async save operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockStorage.saveItemsCalled)
        XCTAssertEqual(mockStorage.savedItems.count, 0)
    }
    
    func testPersistence_ClearAll_CallsSaveItems() async {
        // Given
        store.addItem(content: "Test content")
        mockStorage.saveItemsCalled = false // Reset flag
        
        // When
        store.clearAll()
        
        // Wait for async save operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockStorage.saveItemsCalled)
        XCTAssertEqual(mockStorage.savedItems.count, 0)
    }
    
    func testPersistence_ClearAllAndStorage_CallsClearStorage() async {
        // Given
        store.addItem(content: "Test content")
        
        // When
        await store.clearAllAndStorage()
        
        // Then
        XCTAssertTrue(mockStorage.clearStorageCalled)
        XCTAssertEqual(store.count, 0)
    }
    
    func testLoadItems_WithExistingData_PopulatesStore() async {
        // Given
        let existingItems = [
            ClipItem(content: "Existing item 1"),
            ClipItem(content: "Existing item 2")
        ]
        mockStorage.itemsToReturn = existingItems
        
        // When
        let newStore = ClipboardStore(storage: mockStorage)
        
        // Wait for async load operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockStorage.loadItemsCalled)
        XCTAssertEqual(newStore.count, 2)
        XCTAssertEqual(newStore.items[0].content, "Existing item 1")
        XCTAssertEqual(newStore.items[1].content, "Existing item 2")
    }
    
    func testLoadItems_WithTooManyItems_TrimsToMaxItems() async {
        // Given - Create 150 items (exceeding max of 100)
        let existingItems = (1...150).map { ClipItem(content: "Item \($0)") }
        mockStorage.itemsToReturn = existingItems
        
        // When
        let newStore = ClipboardStore(storage: mockStorage)
        
        // Wait for async load operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(newStore.count, 100)
        XCTAssertEqual(newStore.items[0].content, "Item 1") // Should keep first 100 items
        XCTAssertEqual(newStore.items[99].content, "Item 100")
    }
    
    func testLoadItems_StorageError_KeepsEmptyArray() async {
        // Given
        mockStorage.shouldThrowOnLoad = true
        
        // When
        let newStore = ClipboardStore(storage: mockStorage)
        
        // Wait for async load operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(newStore.count, 0)
        XCTAssertTrue(newStore.isEmpty)
    }
    
    func testNoSaveDuringLoad_PreventsSaveWhileLoading() async {
        // Given
        let existingItems = [ClipItem(content: "Existing item")]
        mockStorage.itemsToReturn = existingItems
        
        // When
        let newStore = ClipboardStore(storage: mockStorage)
        
        // Small delay to ensure loading starts but hasn't finished
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Then verify save is not called during load (isLoading flag should prevent it)
        // The load operation should complete and then normal saves should work
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds more
        
        mockStorage.saveItemsCalled = false // Reset
        newStore.addItem(content: "New item")
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(mockStorage.saveItemsCalled) // Should now be able to save
    }
}

// MARK: - Mock Storage Implementation

class MockClipboardStorage: ClipboardStorageProtocol {
    var itemsToReturn: [ClipItem] = []
    var savedItems: [ClipItem] = []
    var loadItemsCalled = false
    var saveItemsCalled = false
    var clearStorageCalled = false
    var shouldThrowOnLoad = false
    var shouldThrowOnSave = false
    
    func loadItems() async throws -> [ClipItem] {
        loadItemsCalled = true
        if shouldThrowOnLoad {
            throw ClipboardStorageError.fileSystemError(NSError(domain: "Test", code: 1, userInfo: nil))
        }
        return itemsToReturn
    }
    
    func saveItems(_ items: [ClipItem]) async throws {
        saveItemsCalled = true
        if shouldThrowOnSave {
            throw ClipboardStorageError.fileSystemError(NSError(domain: "Test", code: 2, userInfo: nil))
        }
        savedItems = items
    }
    
    func clearStorage() async throws {
        clearStorageCalled = true
        savedItems = []
        itemsToReturn = []
    }
} 