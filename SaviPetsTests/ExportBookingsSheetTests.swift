import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Export Bookings Sheet functionality
@MainActor
final class ExportBookingsSheetTests: XCTestCase {
    
    var mockBookings: [ServiceBooking]!
    
    override func setUp() {
        super.setUp()
        mockBookings = createMockBookings()
    }
    
    override func tearDown() {
        mockBookings = nil
        super.tearDown()
    }
    
    // MARK: - CSV Export Tests
    
    func testCSVExportBasic() {
        // Given
        let bookings = Array(mockBookings.prefix(3))
        
        // When
        let csvData = generateCSVData(bookings: bookings)
        
        // Then
        XCTAssertFalse(csvData.isEmpty)
        XCTAssertTrue(csvData.contains("ID,Client ID,Service Type"))
    }
    
    func testCSVExportHeaders() {
        // Given
        let bookings = Array(mockBookings.prefix(1))
        
        // When
        let csvData = generateCSVData(bookings: bookings)
        let lines = csvData.components(separatedBy: .newlines)
        let headerLine = lines.first ?? ""
        
        // Then
        let expectedHeaders = [
            "ID", "Client ID", "Service Type", "Status",
            "Scheduled Date", "Scheduled Time", "Duration",
            "Sitter Name", "Price", "Address", "Created At"
        ]
        
        for header in expectedHeaders {
            XCTAssertTrue(headerLine.contains(header), "Header should contain: \(header)")
        }
    }
    
    func testCSVExportDataRows() {
        // Given
        let bookings = Array(mockBookings.prefix(2))
        
        // When
        let csvData = generateCSVData(bookings: bookings)
        let lines = csvData.components(separatedBy: .newlines)
        
        // Then
        XCTAssertGreaterThan(lines.count, 2) // Header + 2 data rows + empty line
        
        // Check that each booking data is in the CSV
        for booking in bookings {
            XCTAssertTrue(csvData.contains(booking.id))
            XCTAssertTrue(csvData.contains(booking.clientId))
            XCTAssertTrue(csvData.contains(booking.serviceType))
            XCTAssertTrue(csvData.contains(booking.status.rawValue))
            XCTAssertTrue(csvData.contains(booking.price))
        }
    }
    
    func testCSVExportEmptyBookings() {
        // Given
        let emptyBookings: [ServiceBooking] = []
        
        // When
        let csvData = generateCSVData(bookings: emptyBookings)
        
        // Then
        XCTAssertFalse(csvData.isEmpty) // Should still have headers
        let lines = csvData.components(separatedBy: .newlines)
        XCTAssertEqual(lines.count, 2) // Header + empty line
    }
    
    func testCSVExportSingleBooking() {
        // Given
        let singleBooking = [mockBookings.first!]
        
        // When
        let csvData = generateCSVData(bookings: singleBooking)
        
        // Then
        XCTAssertFalse(csvData.isEmpty)
        let lines = csvData.components(separatedBy: .newlines)
        XCTAssertEqual(lines.count, 3) // Header + data row + empty line
    }
    
    // MARK: - Data Escaping Tests
    
    func testCSVExportWithCommasInData() {
        // Given
        let bookingWithCommas = createMockBooking(
            serviceType: "Dog Walking, Pet Sitting",
            specialInstructions: "Special, instructions with, commas",
            address: "123 Main St, Apt 4B, City, State"
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithCommas])
        
        // Then
        XCTAssertTrue(csvData.contains("\"Dog Walking, Pet Sitting\""))
        XCTAssertTrue(csvData.contains("\"Special, instructions with, commas\""))
        XCTAssertTrue(csvData.contains("\"123 Main St, Apt 4B, City, State\""))
    }
    
    func testCSVExportWithQuotesInData() {
        // Given
        let bookingWithQuotes = createMockBooking(
            serviceType: "Dog \"Walking\" Service",
            specialInstructions: "Instructions with \"quotes\" inside",
            address: "123 \"Main\" Street"
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithQuotes])
        
        // Then
        XCTAssertTrue(csvData.contains("\"Dog \"\"Walking\"\" Service\""))
        XCTAssertTrue(csvData.contains("\"Instructions with \"\"quotes\"\" inside\""))
        XCTAssertTrue(csvData.contains("\"123 \"\"Main\"\" Street\""))
    }
    
    func testCSVExportWithNewlinesInData() {
        // Given
        let bookingWithNewlines = createMockBooking(
            specialInstructions: "Line 1\nLine 2\nLine 3"
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithNewlines])
        
        // Then
        XCTAssertTrue(csvData.contains("\"Line 1\\nLine 2\\nLine 3\""))
    }
    
    func testCSVExportWithSpecialCharacters() {
        // Given
        let bookingWithSpecialChars = createMockBooking(
            serviceType: "Dog Walking & Pet Care",
            specialInstructions: "Instructions with émojis 🐕 and symbols @#$%",
            address: "123 Main St. #4B"
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithSpecialChars])
        
        // Then
        XCTAssertTrue(csvData.contains("\"Dog Walking & Pet Care\""))
        XCTAssertTrue(csvData.contains("\"Instructions with émojis 🐕 and symbols @#$%\""))
        XCTAssertTrue(csvData.contains("\"123 Main St. #4B\""))
    }
    
    // MARK: - Date Formatting Tests
    
    func testCSVExportDateFormatting() {
        // Given
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let booking = createMockBooking(
            scheduledDate: testDate,
            createdAt: testDate
        )
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        let formatter = DateFormatter.csvDateFormatter
        let expectedDateString = formatter.string(from: testDate)
        
        // Then
        XCTAssertTrue(csvData.contains(expectedDateString))
    }
    
    func testCSVExportTimeFormatting() {
        // Given
        let booking = createMockBooking(scheduledTime: "2:30 PM")
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("2:30 PM"))
    }
    
    // MARK: - Optional Fields Tests
    
    func testCSVExportWithNilSitterName() {
        // Given
        let booking = createMockBooking(sitterName: nil)
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("\"\"")) // Should contain empty quoted field
    }
    
    func testCSVExportWithNilAddress() {
        // Given
        let booking = createMockBooking(address: nil)
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("\"\"")) // Should contain empty quoted field
    }
    
    func testCSVExportWithNilSpecialInstructions() {
        // Given
        let booking = createMockBooking(specialInstructions: nil)
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("\"\"")) // Should contain empty quoted field
    }
    
    func testCSVExportWithEmptyStringFields() {
        // Given
        let booking = createMockBooking(
            sitterName: "",
            address: "",
            specialInstructions: ""
        )
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("\"\"")) // Should contain empty quoted fields
    }
    
    // MARK: - Payment Information Tests
    
    func testCSVExportWithPaymentInformation() {
        // Given
        let booking = createMockBooking(
            paymentStatus: .confirmed,
            paymentTransactionId: "txn_123456789",
            paymentAmount: 75.50,
            paymentMethod: "Credit Card"
        )
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("confirmed"))
        XCTAssertTrue(csvData.contains("txn_123456789"))
        XCTAssertTrue(csvData.contains("75.50"))
        XCTAssertTrue(csvData.contains("Credit Card"))
    }
    
    func testCSVExportWithNilPaymentInformation() {
        // Given
        let booking = createMockBooking(
            paymentStatus: nil,
            paymentTransactionId: nil,
            paymentAmount: nil,
            paymentMethod: nil
        )
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("\"\"")) // Should contain empty quoted fields
    }
    
    // MARK: - Reschedule Information Tests
    
    func testCSVExportWithRescheduleInformation() {
        // Given
        let originalDate = Date()
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: originalDate)!
        let rescheduleEntry = RescheduleEntry(
            id: "reschedule1",
            originalDate: originalDate,
            newDate: newDate,
            reason: "Client requested change",
            requestedBy: "client123",
            requestedAt: Date(),
            approvedBy: "admin123",
            approvedAt: Date(),
            status: .approved
        )
        
        let booking = createMockBooking(
            rescheduledFrom: originalDate,
            rescheduledAt: Date(),
            rescheduledBy: "admin123",
            rescheduleReason: "Client requested change",
            rescheduleHistory: [rescheduleEntry]
        )
        
        // When
        let csvData = generateCSVData(bookings: [booking])
        
        // Then
        XCTAssertTrue(csvData.contains("Client requested change"))
        XCTAssertTrue(csvData.contains("admin123"))
    }
    
    // MARK: - Performance Tests
    
    func testCSVExportPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index)",
                specialInstructions: "Instructions with some text \(index)"
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let csvData = generateCSVData(bookings: largeDataset)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
        XCTAssertFalse(csvData.isEmpty)
        
        let lines = csvData.components(separatedBy: .newlines)
        XCTAssertEqual(lines.count, 1002) // Header + 1000 data rows + empty line
    }
    
    func testCSVExportLargeDataPerformance() {
        // Given - Create a very large dataset
        let veryLargeDataset = (0..<5000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index)",
                specialInstructions: "Instructions with some text \(index)"
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let csvData = generateCSVData(bookings: veryLargeDataset)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 5.0) // Should complete in less than 5 seconds
        XCTAssertFalse(csvData.isEmpty)
        
        let lines = csvData.components(separatedBy: .newlines)
        XCTAssertEqual(lines.count, 5002) // Header + 5000 data rows + empty line
    }
    
    // MARK: - File Format Tests
    
    func testCSVExportFileFormat() {
        // Given
        let bookings = Array(mockBookings.prefix(5))
        
        // When
        let csvData = generateCSVData(bookings: bookings)
        
        // Then
        // Check for proper CSV structure
        XCTAssertTrue(csvData.hasPrefix("ID,Client ID,Service Type"))
        XCTAssertTrue(csvData.contains("\n"))
        
        // Check that each line has the correct number of fields
        let lines = csvData.components(separatedBy: .newlines)
        let headerLine = lines.first ?? ""
        let headerFieldCount = headerLine.components(separatedBy: ",").count
        
        for line in lines.dropFirst() {
            if !line.isEmpty {
                let fieldCount = line.components(separatedBy: ",").count
                XCTAssertEqual(fieldCount, headerFieldCount, "Line should have same number of fields as header")
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testCSVExportWithUnicodeCharacters() {
        // Given
        let bookingWithUnicode = createMockBooking(
            serviceType: "犬の散歩", // Japanese
            specialInstructions: "Instructions with 中文 characters", // Chinese
            address: "Calle de la Montaña, 123" // Spanish
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithUnicode])
        
        // Then
        XCTAssertTrue(csvData.contains("\"犬の散歩\""))
        XCTAssertTrue(csvData.contains("\"Instructions with 中文 characters\""))
        XCTAssertTrue(csvData.contains("\"Calle de la Montaña, 123\""))
    }
    
    func testCSVExportWithVeryLongText() {
        // Given
        let longText = String(repeating: "This is a very long text. ", count: 100)
        let bookingWithLongText = createMockBooking(
            specialInstructions: longText
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithLongText])
        
        // Then
        XCTAssertTrue(csvData.contains("\"\(longText)\""))
    }
    
    func testCSVExportWithZeroValues() {
        // Given
        let bookingWithZeroValues = createMockBooking(
            duration: 0,
            paymentAmount: 0.0,
            price: "0.00"
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithZeroValues])
        
        // Then
        XCTAssertTrue(csvData.contains("0"))
        XCTAssertTrue(csvData.contains("0.0"))
        XCTAssertTrue(csvData.contains("0.00"))
    }
    
    // MARK: - Helper Methods
    
    private func createMockBookings() -> [ServiceBooking] {
        let statuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure, .completed, .cancelled]
        let services = ["Dog Walking", "Cat Sitting", "Pet Grooming", "Pet Training"]
        let sitters = ["Jane Doe", "John Smith", "Alice Johnson", "Bob Wilson"]
        let addresses = ["123 Main St", "456 Oak Ave", "789 Pine Rd", "321 Elm St"]
        
        return (0..<20).map { index in
            createMockBooking(
                id: "booking\(index)",
                clientId: "client\(index)",
                serviceType: services[index % services.count],
                scheduledDate: Calendar.current.date(byAdding: .day, value: index, to: Date())!,
                status: statuses[index % statuses.count],
                sitterId: index % 2 == 0 ? "sitter\(index % sitters.count)" : nil,
                sitterName: index % 2 == 0 ? sitters[index % sitters.count] : nil,
                address: addresses[index % addresses.count],
                price: "\(50 + index * 5).00"
            )
        }
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
    
    private func generateCSVData(bookings: [ServiceBooking]) -> String {
        let headers = [
            "ID", "Client ID", "Service Type", "Status",
            "Scheduled Date", "Scheduled Time", "Duration",
            "Sitter Name", "Price", "Address", "Created At",
            "Payment Status", "Payment Amount", "Payment Method",
            "Reschedule Reason", "Rescheduled By"
        ]
        
        var csvData = headers.joined(separator: ",") + "\n"
        
        for booking in bookings {
            let row = [
                booking.id,
                booking.clientId,
                escapeCSVField(booking.serviceType),
                booking.status.rawValue,
                DateFormatter.csvDateFormatter.string(from: booking.scheduledDate),
                booking.scheduledTime,
                "\(booking.duration)",
                escapeCSVField(booking.sitterName ?? ""),
                booking.price,
                escapeCSVField(booking.address ?? ""),
                DateFormatter.csvDateFormatter.string(from: booking.createdAt),
                booking.paymentStatus?.rawValue ?? "",
                "\(booking.paymentAmount ?? 0.0)",
                escapeCSVField(booking.paymentMethod ?? ""),
                escapeCSVField(booking.rescheduleReason ?? ""),
                escapeCSVField(booking.rescheduledBy ?? "")
            ]
            
            csvData += row.joined(separator: ",") + "\n"
        }
        
        return csvData
    }
    
    private func escapeCSVField(_ field: String) -> String {
        // Escape quotes by doubling them and wrap in quotes if contains comma, quote, or newline
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
