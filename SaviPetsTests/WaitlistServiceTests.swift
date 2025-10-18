import XCTest
@testable import SaviPets

/// Tests for Waitlist Service functionality
@MainActor
final class WaitlistServiceTests: XCTestCase {
    
    var waitlistService: WaitlistService!
    var mockBooking: ServiceBooking!
    
    override func setUp() {
        super.setUp()
        waitlistService = WaitlistService()
        mockBooking = createMockBooking()
    }
    
    override func tearDown() {
        waitlistService = nil
        mockBooking = nil
        super.tearDown()
    }
    
    // MARK: - Waitlist Entry Tests
    
    func testCreateWaitlistEntry() {
        // Given
        let entry = WaitlistEntry(
            id: "waitlist1",
            clientId: "client123",
            serviceType: "Dog Walking",
            preferredDate: Date(),
            preferredTime: "10:00 AM",
            duration: 60,
            pets: ["Buddy"],
            specialInstructions: "Test instructions",
            status: .waiting,
            priority: 1,
            createdAt: Date(),
            notifiedAt: nil
        )
        
        // When & Then
        XCTAssertEqual(entry.id, "waitlist1")
        XCTAssertEqual(entry.clientId, "client123")
        XCTAssertEqual(entry.serviceType, "Dog Walking")
        XCTAssertEqual(entry.status, .waiting)
        XCTAssertEqual(entry.priority, 1)
    }
    
    func testWaitlistEntryStatus() {
        // Given
        let waitingEntry = createWaitlistEntry(status: .waiting)
        let notifiedEntry = createWaitlistEntry(status: .notified)
        let bookedEntry = createWaitlistEntry(status: .booked)
        let expiredEntry = createWaitlistEntry(status: .expired)
        
        // When & Then
        XCTAssertEqual(waitingEntry.status, .waiting)
        XCTAssertEqual(notifiedEntry.status, .notified)
        XCTAssertEqual(bookedEntry.status, .booked)
        XCTAssertEqual(expiredEntry.status, .expired)
    }
    
    // MARK: - Add to Waitlist Tests
    
    func testAddEntryToWaitlist() {
        // Given
        let entry = createWaitlistEntry()
        
        // When
        let result = waitlistService.addEntryToWaitlist(entry)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testAddEntryToWaitlistWithDuplicate() {
        // Given
        let entry = createWaitlistEntry(id: "duplicate")
        
        // When
        let result1 = waitlistService.addEntryToWaitlist(entry)
        let result2 = waitlistService.addEntryToWaitlist(entry) // Try to add duplicate
        
        // Then
        XCTAssertTrue(result1)
        XCTAssertFalse(result2) // Should fail for duplicate
    }
    
    func testAddEntryToWaitlistWithInvalidData() {
        // Given
        let invalidEntry = WaitlistEntry(
            id: "",
            clientId: "",
            serviceType: "",
            preferredDate: Date(),
            preferredTime: "",
            duration: 0,
            pets: [],
            specialInstructions: nil,
            status: .waiting,
            priority: 0,
            createdAt: Date(),
            notifiedAt: nil
        )
        
        // When
        let result = waitlistService.addEntryToWaitlist(invalidEntry)
        
        // Then
        XCTAssertFalse(result) // Should fail for invalid data
    }
    
    // MARK: - Remove from Waitlist Tests
    
    func testRemoveEntryFromWaitlist() {
        // Given
        let entry = createWaitlistEntry()
        waitlistService.addEntryToWaitlist(entry)
        
        // When
        let result = waitlistService.removeEntryFromWaitlist(entry.id)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testRemoveNonExistentEntry() {
        // Given
        let nonExistentId = "non-existent"
        
        // When
        let result = waitlistService.removeEntryFromWaitlist(nonExistentId)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Get Waitlist Entries Tests
    
    func testGetWaitlistEntries() {
        // Given
        let entry1 = createWaitlistEntry(id: "entry1", serviceType: "Dog Walking")
        let entry2 = createWaitlistEntry(id: "entry2", serviceType: "Cat Sitting")
        
        waitlistService.addEntryToWaitlist(entry1)
        waitlistService.addEntryToWaitlist(entry2)
        
        // When
        let entries = waitlistService.getWaitlistEntries()
        
        // Then
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.id == "entry1" })
        XCTAssertTrue(entries.contains { $0.id == "entry2" })
    }
    
    func testGetWaitlistEntriesByServiceType() {
        // Given
        let dogWalkingEntry = createWaitlistEntry(id: "entry1", serviceType: "Dog Walking")
        let catSittingEntry = createWaitlistEntry(id: "entry2", serviceType: "Cat Sitting")
        
        waitlistService.addEntryToWaitlist(dogWalkingEntry)
        waitlistService.addEntryToWaitlist(catSittingEntry)
        
        // When
        let dogWalkingEntries = waitlistService.getWaitlistEntries(for: "Dog Walking")
        
        // Then
        XCTAssertEqual(dogWalkingEntries.count, 1)
        XCTAssertEqual(dogWalkingEntries.first?.serviceType, "Dog Walking")
    }
    
    func testGetWaitlistEntriesByStatus() {
        // Given
        let waitingEntry = createWaitlistEntry(id: "entry1", status: .waiting)
        let notifiedEntry = createWaitlistEntry(id: "entry2", status: .notified)
        
        waitlistService.addEntryToWaitlist(waitingEntry)
        waitlistService.addEntryToWaitlist(notifiedEntry)
        
        // When
        let waitingEntries = waitlistService.getWaitlistEntries(status: .waiting)
        
        // Then
        XCTAssertEqual(waitingEntries.count, 1)
        XCTAssertEqual(waitingEntries.first?.status, .waiting)
    }
    
    // MARK: - Priority Calculation Tests
    
    func testCalculatePriority() {
        // Given
        let entry1 = createWaitlistEntry(id: "entry1", priority: 1)
        let entry2 = createWaitlistEntry(id: "entry2", priority: 2)
        let entry3 = createWaitlistEntry(id: "entry3", priority: 3)
        
        // When
        let priority1 = waitlistService.calculatePriority(for: entry1)
        let priority2 = waitlistService.calculatePriority(for: entry2)
        let priority3 = waitlistService.calculatePriority(for: entry3)
        
        // Then
        XCTAssertEqual(priority1, 1)
        XCTAssertEqual(priority2, 2)
        XCTAssertEqual(priority3, 3)
    }
    
    func testPriorityOrdering() {
        // Given
        let entries = [
            createWaitlistEntry(id: "entry1", priority: 3),
            createWaitlistEntry(id: "entry2", priority: 1),
            createWaitlistEntry(id: "entry3", priority: 2)
        ]
        
        // When
        let sortedEntries = entries.sorted { $0.priority < $1.priority }
        
        // Then
        XCTAssertEqual(sortedEntries[0].id, "entry2")
        XCTAssertEqual(sortedEntries[1].id, "entry3")
        XCTAssertEqual(sortedEntries[2].id, "entry1")
    }
    
    // MARK: - Matching Bookings Tests
    
    func testFindMatchingBookings() {
        // Given
        let entry = createWaitlistEntry(
            serviceType: "Dog Walking",
            preferredDate: Date(),
            preferredTime: "10:00 AM",
            duration: 60
        )
        
        let matchingBooking = createMockBooking(
            serviceType: "Dog Walking",
            scheduledDate: Date(),
            scheduledTime: "10:00 AM",
            duration: 60
        )
        
        // When
        let matches = waitlistService.findMatchingBookings(for: entry)
        
        // Then
        XCTAssertFalse(matches.isEmpty)
    }
    
    func testFindMatchingBookingsWithDifferentServiceType() {
        // Given
        let entry = createWaitlistEntry(
            serviceType: "Dog Walking",
            preferredDate: Date(),
            preferredTime: "10:00 AM",
            duration: 60
        )
        
        let nonMatchingBooking = createMockBooking(
            serviceType: "Cat Sitting",
            scheduledDate: Date(),
            scheduledTime: "10:00 AM",
            duration: 60
        )
        
        // When
        let matches = waitlistService.findMatchingBookings(for: entry)
        
        // Then
        XCTAssertTrue(matches.isEmpty) // Should not match different service type
    }
    
    func testFindMatchingBookingsWithDifferentTime() {
        // Given
        let entry = createWaitlistEntry(
            serviceType: "Dog Walking",
            preferredDate: Date(),
            preferredTime: "10:00 AM",
            duration: 60
        )
        
        let nonMatchingBooking = createMockBooking(
            serviceType: "Dog Walking",
            scheduledDate: Date(),
            scheduledTime: "2:00 PM",
            duration: 60
        )
        
        // When
        let matches = waitlistService.findMatchingBookings(for: entry)
        
        // Then
        XCTAssertTrue(matches.isEmpty) // Should not match different time
    }
    
    // MARK: - Notification Tests
    
    func testSendWaitlistConfirmation() {
        // Given
        let entry = createWaitlistEntry()
        
        // When
        let result = waitlistService.sendWaitlistConfirmation(for: entry)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testSendWaitlistPromotionNotification() {
        // Given
        let entry = createWaitlistEntry()
        let availableBooking = createMockBooking()
        
        // When
        let result = waitlistService.sendWaitlistPromotionNotification(for: entry, availableBooking: availableBooking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Booking Creation Tests
    
    func testCreateBookingFromWaitlist() {
        // Given
        let entry = createWaitlistEntry()
        let availableBooking = createMockBooking()
        
        // When
        let result = waitlistService.createBookingFromWaitlist(entry: entry, availableBooking: availableBooking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testCreateBookingFromWaitlistWithInvalidEntry() {
        // Given
        let invalidEntry = WaitlistEntry(
            id: "",
            clientId: "",
            serviceType: "",
            preferredDate: Date(),
            preferredTime: "",
            duration: 0,
            pets: [],
            specialInstructions: nil,
            status: .waiting,
            priority: 0,
            createdAt: Date(),
            notifiedAt: nil
        )
        
        let availableBooking = createMockBooking()
        
        // When
        let result = waitlistService.createBookingFromWaitlist(entry: invalidEntry, availableBooking: availableBooking)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Status Update Tests
    
    func testUpdateWaitlistEntryStatus() {
        // Given
        let entry = createWaitlistEntry(status: .waiting)
        waitlistService.addEntryToWaitlist(entry)
        
        // When
        let result = waitlistService.updateWaitlistEntryStatus(entry.id, to: .notified)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testUpdateNonExistentEntryStatus() {
        // Given
        let nonExistentId = "non-existent"
        
        // When
        let result = waitlistService.updateWaitlistEntryStatus(nonExistentId, to: .notified)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Expiration Tests
    
    func testExpireOldEntries() {
        // Given
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let oldEntry = createWaitlistEntry(id: "old_entry", createdAt: oldDate)
        
        waitlistService.addEntryToWaitlist(oldEntry)
        
        // When
        let result = waitlistService.expireOldEntries()
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testExpireOldEntriesWithRecentEntry() {
        // Given
        let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let recentEntry = createWaitlistEntry(id: "recent_entry", createdAt: recentDate)
        
        waitlistService.addEntryToWaitlist(recentEntry)
        
        // When
        let result = waitlistService.expireOldEntries()
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Performance Tests
    
    func testWaitlistOperationsPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createWaitlistEntry(id: "entry\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for entry in largeDataset {
            waitlistService.addEntryToWaitlist(entry)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
    }
    
    func testWaitlistSearchPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createWaitlistEntry(id: "entry\(index)", serviceType: "Service Type \(index % 10)")
        }
        
        for entry in largeDataset {
            waitlistService.addEntryToWaitlist(entry)
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let entries = waitlistService.getWaitlistEntries(for: "Service Type 1")
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertFalse(entries.isEmpty)
    }
    
    // MARK: - Edge Cases Tests
    
    func testWaitlistWithEmptyEntries() {
        // Given
        let entries = waitlistService.getWaitlistEntries()
        
        // When & Then
        XCTAssertTrue(entries.isEmpty)
    }
    
    func testWaitlistWithInvalidServiceType() {
        // Given
        let entry = createWaitlistEntry(serviceType: "")
        
        // When
        let result = waitlistService.addEntryToWaitlist(entry)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testWaitlistWithInvalidDate() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = createWaitlistEntry(preferredDate: pastDate)
        
        // When
        let result = waitlistService.addEntryToWaitlist(entry)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testWaitlistWithZeroDuration() {
        // Given
        let entry = createWaitlistEntry(duration: 0)
        
        // When
        let result = waitlistService.addEntryToWaitlist(entry)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Helper Methods
    
    private func createWaitlistEntry(
        id: String = "waitlist1",
        clientId: String = "client123",
        serviceType: String = "Dog Walking",
        preferredDate: Date = Date(),
        preferredTime: String = "10:00 AM",
        duration: Int = 60,
        pets: [String] = ["Buddy"],
        specialInstructions: String? = "Test instructions",
        status: WaitlistStatus = .waiting,
        priority: Int = 1,
        createdAt: Date = Date(),
        notifiedAt: Date? = nil
    ) -> WaitlistEntry {
        return WaitlistEntry(
            id: id,
            clientId: clientId,
            serviceType: serviceType,
            preferredDate: preferredDate,
            preferredTime: preferredTime,
            duration: duration,
            pets: pets,
            specialInstructions: specialInstructions,
            status: status,
            priority: priority,
            createdAt: createdAt,
            notifiedAt: notifiedAt
        )
    }
    
    private func createMockBooking(
        id: String = "booking123",
        clientId: String = "client123",
        serviceType: String = "Dog Walking",
        scheduledDate: Date = Date(),
        scheduledTime: String = "10:00 AM",
        duration: Int = 60,
        pets: [String] = ["Buddy"],
        specialInstructions: String? = "Test instructions",
        status: ServiceBooking.BookingStatus = .approved,
        sitterId: String? = "sitter123",
        sitterName: String? = "Jane Doe",
        createdAt: Date = Date(),
        address: String? = "123 Main St",
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        price: String = "50.00",
        recurringSeriesId: String? = nil,
        visitNumber: Int? = nil,
        isRecurring: Bool = false,
        paymentStatus: PaymentStatus? = .confirmed,
        paymentTransactionId: String? = "txn123",
        paymentAmount: Double? = 50.0,
        paymentMethod: String? = "Credit Card",
        rescheduledFrom: Date? = nil,
        rescheduledAt: Date? = nil,
        rescheduledBy: String? = nil,
        rescheduleReason: String? = nil,
        rescheduleHistory: [RescheduleEntry] = [],
        lastModified: Date? = nil,
        lastModifiedBy: String? = nil,
        modificationReason: String? = nil
    ) -> ServiceBooking {
        return ServiceBooking(
            id: id,
            clientId: clientId,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            duration: duration,
            pets: pets,
            specialInstructions: specialInstructions,
            status: status,
            sitterId: sitterId,
            sitterName: sitterName,
            createdAt: createdAt,
            address: address,
            checkIn: checkIn,
            checkOut: checkOut,
            price: price,
            recurringSeriesId: recurringSeriesId,
            visitNumber: visitNumber,
            isRecurring: isRecurring,
            paymentStatus: paymentStatus,
            paymentTransactionId: paymentTransactionId,
            paymentAmount: paymentAmount,
            paymentMethod: paymentMethod,
            rescheduledFrom: rescheduledFrom,
            rescheduledAt: rescheduledAt,
            rescheduledBy: rescheduledBy,
            rescheduleReason: rescheduleReason,
            rescheduleHistory: rescheduleHistory,
            lastModified: lastModified ?? Date(),
            lastModifiedBy: lastModifiedBy ?? "system",
            modificationReason: modificationReason ?? "Initial booking"
        )
    }
}
