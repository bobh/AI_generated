import XCTest
// If SafeCircularBuffer is in a module named MorseTranslator, uncomment next line
// @testable import MorseTranslator // Or your actual app/module name

class SafeCircularBufferTests: XCTestCase {

    func testConcurrentPushes_ThenConcurrentPops() async throws {
        let capacity = 100
        let buffer = SafeCircularBuffer<Int>(capacity: capacity)
        let numberOfTasks = 10
        let itemsPerTask = capacity / numberOfTasks // Each task pushes 10 items

        // Phase 1: Concurrent Pushes
        var allPushedItems = Set<Int>()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<numberOfTasks {
                group.addTask {
                    for j in 0..<itemsPerTask {
                        let itemToPush = i * itemsPerTask + j // Unique items: 0-9, 10-19, ..., 90-99
                        // No direct way to add to allPushedItems from here due to actor isolation if allPushedItems is outside.
                        // We will reconstruct the set of pushed items based on this logic for assertion later.
                        _ = await buffer.push(itemToPush)
                    }
                }
            }
        }
        
        // Reconstruct the set of all items that should have been pushed
        for i in 0..<numberOfTasks {
            for j in 0..<itemsPerTask {
                allPushedItems.insert(i * itemsPerTask + j)
            }
        }

        XCTAssertEqual(await buffer.count, capacity, "Buffer count should be full after concurrent pushes.")
        XCTAssertTrue(await buffer.isFull, "Buffer should be full after concurrent pushes.")
        XCTAssertFalse(await buffer.isEmpty, "Buffer should not be empty after concurrent pushes.")

        // Phase 2: Concurrent Pops
        var allPoppedItems = Set<Int>()
        let poppedItemsLock = NSLock() // To safely add to allPoppedItems from concurrent tasks

        await withTaskGroup(of: [Int].self) { group in // Each task returns an array of items it popped
            for _ in 0..<numberOfTasks {
                group.addTask {
                    var taskPoppedItems = [Int]()
                    for _ in 0..<itemsPerTask {
                        if let poppedItem = await buffer.pop() {
                            taskPoppedItems.append(poppedItem)
                        }
                    }
                    return taskPoppedItems
                }
            }

            for await taskResult in group {
                poppedItemsLock.lock()
                for item in taskResult {
                    allPoppedItems.insert(item)
                }
                poppedItemsLock.unlock()
            }
        }

        XCTAssertEqual(await buffer.count, 0, "Buffer count should be zero after concurrent pops.")
        XCTAssertTrue(await buffer.isEmpty, "Buffer should be empty after concurrent pops.")
        XCTAssertFalse(await buffer.isFull, "Buffer should not be full after concurrent pops.")
        
        XCTAssertEqual(allPoppedItems.count, capacity, "Number of unique popped items should match capacity.")
        XCTAssertEqual(allPoppedItems, allPushedItems, "The set of popped items should be identical to the set of pushed items.")
    }

    func testMixedConcurrentPushAndPop() async throws {
        let capacity = 50
        let buffer = SafeCircularBuffer<Int>(capacity: capacity)
        let operationsPerTask = 100 // Number of operations each task will attempt
        let numberOfPushTasks = 5
        let numberOfPopTasks = 3

        // Atomic counters to track overall pushes and pops initiated by tasks
        // let totalPushesAttempted = ManagedAtomic<Int>(0) // SwiftNIO's atomic, or use an actor-based counter
        // let totalPopsAttempted = ManagedAtomic<Int>(0)
        
        // It's hard to get SwiftNIO's atomics easily into a typical Xcode project without adding the dependency.
        // For simplicity in a standard XCTest environment, we can use a simple actor for counting.
        actor Counter {
            var value = 0
            func increment() { value += 1 }
            func getValue() -> Int { return value }
        }
        let successfulPushes = Counter()
        let successfulPops = Counter()


        await withTaskGroup(of: Void.self) { group in
            // Push Tasks
            for i in 0..<numberOfPushTasks {
                group.addTask {
                    for pushAttempt in 0..<operationsPerTask {
                        let item = (i * operationsPerTask) + pushAttempt // Unique item for each push attempt across push tasks
                        _ = await buffer.push(item) // We are testing for stability and count, not specific item overwrite returns
                        await successfulPushes.increment()
                    }
                }
            }

            // Pop Tasks
            for _ in 0..<numberOfPopTasks {
                group.addTask {
                    for _ in 0..<operationsPerTask {
                        if await buffer.pop() != nil {
                            await successfulPops.increment()
                        }
                    }
                }
            }
        }

        let finalPushes = await successfulPushes.getValue()
        let finalPops = await successfulPops.getValue()
        let finalBufferCount = await buffer.count

        // The buffer's final count should be the number of successful pushes minus successful pops,
        // capped at the buffer's capacity and not less than 0.
        let expectedCount = max(0, min(capacity, finalPushes - finalPops))
        
        XCTAssertEqual(finalBufferCount, expectedCount, "Buffer count should match successful pushes minus successful pops, respecting capacity.")
        
        // Additional checks for stability:
        // If the buffer is full, count must be capacity.
        if await buffer.isFull {
            XCTAssertEqual(finalBufferCount, capacity, "If buffer is full, count must be capacity.")
        }
        // If the buffer is empty, count must be 0.
        if await buffer.isEmpty {
            XCTAssertEqual(finalBufferCount, 0, "If buffer is empty, count must be 0.")
        }
        
        // We can also check that count is within bounds.
        XCTAssertLessThanOrEqual(finalBufferCount, capacity, "Buffer count should not exceed capacity.")
        XCTAssertGreaterThanOrEqual(finalBufferCount, 0, "Buffer count should not be negative.")
        
        print("Mixed Test: Pushes Attempted by tasks = \(numberOfPushTasks * operationsPerTask), Pops Attempted by tasks = \(numberOfPopTasks * operationsPerTask)")
        print("Mixed Test: Successful Pushes = \(finalPushes), Successful Pops = \(finalPops), Final Buffer Count = \(finalBufferCount), Expected Count = \(expectedCount)")
    }

    func testConcurrentPushToFullBufferAndPopFromEmptyBuffer() async throws {
        let capacity = 10
        let buffer = SafeCircularBuffer<Int>(capacity: capacity)
        let numberOfOperations = 50 // More operations than capacity to ensure boundary conditions are hit

        // Scenario 1: Concurrent pushes to a full buffer
        // Fill the buffer first
        for i in 0..<capacity {
            _ = await buffer.push(i)
        }
        XCTAssertTrue(await buffer.isFull, "Buffer should be full before concurrent push test.")
        XCTAssertEqual(await buffer.count, capacity, "Buffer count should be capacity before concurrent push test.")

        // Keep track of overwritten items returned by push
        actor OverwrittenItemsCollector {
            var items: [Int] = []
            func add(_ item: Int?) {
                if let item = item { items.append(item) }
            }
            func getItems() -> [Int] { return items }
        }
        let overwrittenCollector = OverwrittenItemsCollector()

        await withTaskGroup(of: Void.self) { group in
            for taskID in 0..<5 { // 5 tasks trying to push
                group.addTask {
                    for i in 0..<numberOfOperations {
                        // Items being pushed are distinct for each task to avoid confusion if we were checking specific overwritten values per task
                        let itemToPush = (taskID * numberOfOperations) + i + capacity // Ensure these items are different from initially filled items
                        let overwritten = await buffer.push(itemToPush)
                        await overwrittenCollector.add(overwritten)
                    }
                }
            }
        }

        XCTAssertTrue(await buffer.isFull, "Buffer should remain full after attempting to push to it.")
        XCTAssertEqual(await buffer.count, capacity, "Buffer count should remain at capacity.")
        
        let collectedOverwrittenItems = await overwrittenCollector.getItems()
        // Each push to a full buffer should return an overwritten item.
        // Total operations = 5 tasks * 50 operations/task = 250 pushes.
        XCTAssertEqual(collectedOverwrittenItems.count, 5 * numberOfOperations, "Should have collected one overwritten item for each push attempt on the full buffer.")


        // Scenario 2: Concurrent pops from an empty buffer
        // Clear the buffer first
        await buffer.clear()
        XCTAssertTrue(await buffer.isEmpty, "Buffer should be empty before concurrent pop test.")
        XCTAssertEqual(await buffer.count, 0, "Buffer count should be zero before concurrent pop test.")

        actor PoppedNilCounter {
            var nilPops = 0
            func incrementNilPops() { nilPops += 1 }
            func getNilPops() -> Int { return nilPops }
        }
        let nilPopCounter = PoppedNilCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 { // 5 tasks trying to pop
                group.addTask {
                    for _ in 0..<numberOfOperations {
                        if await buffer.pop() == nil {
                            await nilPopCounter.incrementNilPops()
                        }
                    }
                }
            }
        }

        XCTAssertTrue(await buffer.isEmpty, "Buffer should remain empty after attempting to pop from it.")
        XCTAssertEqual(await buffer.count, 0, "Buffer count should remain zero.")
        XCTAssertEqual(await nilPopCounter.getNilPops(), 5 * numberOfOperations, "All pop attempts on empty buffer should return nil.")
    }
}
