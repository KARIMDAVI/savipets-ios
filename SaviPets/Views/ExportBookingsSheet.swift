import SwiftUI
import UniformTypeIdentifiers

struct ExportBookingsSheet: View {
    let bookings: [ServiceBooking]
    
    @State private var selectedFormat: ExportFormat = .csv
    @State private var selectedFields: Set<ExportField> = Set(ExportField.allCases)
    @State private var dateRange: DateRange = .all
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date().addingTimeInterval(86400) // +1 day
    @State private var isExporting: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var exportedData: Data? = nil
    @State private var exportFileName: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV"
        case json = "JSON"
        case excel = "Excel"
        
        var id: String { rawValue }
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            case .excel: return "xlsx"
            }
        }
        
        var utType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .json: return .json
            case .excel: return .spreadsheet
            }
        }
    }
    
    enum ExportField: String, CaseIterable, Identifiable {
        case bookingId = "Booking ID"
        case serviceType = "Service Type"
        case scheduledDate = "Scheduled Date"
        case scheduledTime = "Scheduled Time"
        case duration = "Duration"
        case status = "Status"
        case clientId = "Client ID"
        case clientName = "Client Name"
        case sitterId = "Sitter ID"
        case sitterName = "Sitter Name"
        case pets = "Pets"
        case price = "Price"
        case address = "Address"
        case specialInstructions = "Special Instructions"
        case createdAt = "Created At"
        case paymentStatus = "Payment Status"
        case isRecurring = "Is Recurring"
        case recurringSeriesId = "Recurring Series ID"
        case rescheduleHistory = "Reschedule History"
        
        var id: String { rawValue }
        
        var key: String {
            switch self {
            case .bookingId: return "id"
            case .serviceType: return "serviceType"
            case .scheduledDate: return "scheduledDate"
            case .scheduledTime: return "scheduledTime"
            case .duration: return "duration"
            case .status: return "status"
            case .clientId: return "clientId"
            case .clientName: return "clientName"
            case .sitterId: return "sitterId"
            case .sitterName: return "sitterName"
            case .pets: return "pets"
            case .price: return "price"
            case .address: return "address"
            case .specialInstructions: return "specialInstructions"
            case .createdAt: return "createdAt"
            case .paymentStatus: return "paymentStatus"
            case .isRecurring: return "isRecurring"
            case .recurringSeriesId: return "recurringSeriesId"
            case .rescheduleHistory: return "rescheduleHistory"
            }
        }
    }
    
    enum DateRange: String, CaseIterable, Identifiable {
        case all = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case custom = "Custom Range"
        
        var id: String { rawValue }
    }
    
    private var filteredBookings: [ServiceBooking] {
        let now = Date()
        let calendar = Calendar.current
        
        var filtered = bookings
        
        switch dateRange {
        case .all:
            break
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            filtered = bookings.filter { $0.scheduledDate >= start && $0.scheduledDate < end }
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
            filtered = bookings.filter { $0.scheduledDate >= start && $0.scheduledDate < end }
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            filtered = bookings.filter { $0.scheduledDate >= start && $0.scheduledDate < end }
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            filtered = bookings.filter { $0.scheduledDate >= monthStart && $0.scheduledDate < monthEnd }
        case .custom:
            filtered = bookings.filter { $0.scheduledDate >= customStartDate && $0.scheduledDate <= customEndDate }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Export format
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Date range
                Section("Date Range") {
                    Picker("Date Range", selection: $dateRange) {
                        ForEach(DateRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if dateRange == .custom {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                    }
                }
                
                // Fields selection
                Section("Fields to Export") {
                    ForEach(ExportField.allCases) { field in
                        HStack {
                            Text(field.rawValue)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { selectedFields.contains(field) },
                                set: { isOn in
                                    if isOn {
                                        selectedFields.insert(field)
                                    } else {
                                        selectedFields.remove(field)
                                    }
                                }
                            ))
                        }
                    }
                    
                    HStack {
                        Button("Select All") {
                            selectedFields = Set(ExportField.allCases)
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            selectedFields.removeAll()
                        }
                        .font(.caption)
                    }
                }
                
                // Preview
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(filteredBookings.count) booking\(filteredBookings.count == 1 ? "" : "s") will be exported")
                            .font(.subheadline)
                        
                        if !selectedFields.isEmpty {
                            Text("Fields: \(selectedFields.map { $0.rawValue }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Format: \(selectedFormat.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Export Bookings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportBookings()
                    }
                    .disabled(selectedFields.isEmpty || isExporting)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = exportedData, !exportFileName.isEmpty {
                ShareSheet(data: data, fileName: exportFileName, utType: selectedFormat.utType)
            }
        }
    }
    
    private func exportBookings() {
        isExporting = true
        
        Task {
            do {
                let data = try await generateExportData()
                
                await MainActor.run {
                    exportedData = data
                    exportFileName = generateFileName()
                    isExporting = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    // Handle error
                }
            }
        }
    }
    
    private func generateExportData() async throws -> Data {
        let bookingsToExport = filteredBookings
        let fieldsToExport = Array(selectedFields).sorted { $0.rawValue < $1.rawValue }
        
        switch selectedFormat {
        case .csv:
            return try generateCSVData(bookings: bookingsToExport, fields: fieldsToExport)
        case .json:
            return try generateJSONData(bookings: bookingsToExport, fields: fieldsToExport)
        case .excel:
            return try generateExcelData(bookings: bookingsToExport, fields: fieldsToExport)
        }
    }
    
    private func generateCSVData(bookings: [ServiceBooking], fields: [ExportField]) throws -> Data {
        var csvContent = ""
        
        // Header row
        let headers = fields.map { $0.rawValue }.joined(separator: ",")
        csvContent += headers + "\n"
        
        // Data rows
        for booking in bookings {
            let values = fields.map { field in
                getFieldValue(booking: booking, field: field).replacingOccurrences(of: ",", with: ";")
            }.joined(separator: ",")
            csvContent += values + "\n"
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    private func generateJSONData(bookings: [ServiceBooking], fields: [ExportField]) throws -> Data {
        let jsonArray = bookings.map { booking in
            var jsonObject: [String: Any] = [:]
            
            for field in fields {
                jsonObject[field.key] = getFieldValue(booking: booking, field: field)
            }
            
            return jsonObject
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
        return jsonData
    }
    
    private func generateExcelData(bookings: [ServiceBooking], fields: [ExportField]) throws -> Data {
        // For now, generate CSV data as Excel can handle CSV format
        // In a real implementation, you would use a library like SwiftExcel
        return try generateCSVData(bookings: bookings, fields: fields)
    }
    
    private func getFieldValue(booking: ServiceBooking, field: ExportField) -> String {
        switch field {
        case .bookingId:
            return booking.id
        case .serviceType:
            return booking.serviceType
        case .scheduledDate:
            return booking.scheduledDate.formatted(date: .abbreviated, time: .omitted)
        case .scheduledTime:
            return booking.scheduledTime
        case .duration:
            return "\(booking.duration)"
        case .status:
            return booking.status.displayName
        case .clientId:
            return booking.clientId
        case .clientName:
            return "" // Would need to be resolved separately
        case .sitterId:
            return booking.sitterId ?? ""
        case .sitterName:
            return booking.sitterName ?? ""
        case .pets:
            return booking.pets.joined(separator: "; ")
        case .price:
            return booking.price
        case .address:
            return booking.address ?? ""
        case .specialInstructions:
            return booking.specialInstructions ?? ""
        case .createdAt:
            return booking.createdAt.formatted(date: .abbreviated, time: .omitted)
        case .paymentStatus:
            return booking.paymentStatus?.rawValue ?? ""
        case .isRecurring:
            return booking.isRecurring ? "Yes" : "No"
        case .recurringSeriesId:
            return booking.recurringSeriesId ?? ""
        case .rescheduleHistory:
            return booking.rescheduleHistory.map { "\($0.originalDate.formatted(date: .abbreviated, time: .omitted)) -> \($0.newDate.formatted(date: .abbreviated, time: .omitted))" }.joined(separator: "; ")
        }
    }
    
    private func generateFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        return "bookings_export_\(dateString).\(selectedFormat.fileExtension)"
    }
}

// MARK: - Share Sheet
private struct ShareSheet: UIViewControllerRepresentable {
    let data: Data
    let fileName: String
    let utType: UTType
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
        } catch {
            // Handle error
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Error
enum ExportError: Error {
    case encodingFailed
    case fileGenerationFailed
    
    var localizedDescription: String {
        switch self {
        case .encodingFailed:
            return "Failed to encode export data"
        case .fileGenerationFailed:
            return "Failed to generate export file"
        }
    }
}

#Preview {
    ExportBookingsSheet(bookings: [])
}
