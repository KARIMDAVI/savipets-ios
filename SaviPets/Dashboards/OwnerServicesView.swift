import SwiftUI
internal import os

struct OwnerServicesView: View {
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    @State private var selectedFilter: ServiceBooking.BookingStatus? = nil

    private var filtered: [ServiceBooking] {
        if let f = selectedFilter { return serviceBookings.userBookings.filter { $0.status == f } }
        return serviceBookings.userBookings
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "All", isSelected: selectedFilter == nil, count: serviceBookings.userBookings.count) {
                            selectedFilter = nil
                        }
                        ForEach(ServiceBooking.BookingStatus.allCases, id: \.rawValue) { status in
                            let count = serviceBookings.userBookings.filter { $0.status == status }.count
                            if count > 0 {
                                FilterChip(title: status.displayName, isSelected: selectedFilter == status, count: count, color: status.color) {
                                    selectedFilter = status
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                List {
                    ForEach(filtered) { b in
                        ServiceBookingFullCard(booking: b)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("My Services")
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("(\(count))").font(.caption)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1)))
            .foregroundColor(isSelected ? color : .primary)
            .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1))
        }
    }
}

private struct ServiceBookingFullCard: View {
    let booking: ServiceBooking
    @State private var showRescheduleSheet: Bool = false
    @State private var showCancelAlert: Bool = false
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    
    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.serviceType).font(.headline)
                        HStack(spacing: 8) {
                            Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                            Text("at \(booking.scheduledTime)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(booking.status.color).frame(width: 8, height: 8)
                        Text(booking.status.displayName)
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(booking.status.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(booking.status.color.opacity(0.1))
                    .cornerRadius(8)
                }

                if !booking.pets.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill").font(.caption).foregroundColor(.secondary)
                        Text("Pets: \(booking.pets.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if booking.status == .approved, let sitterName = booking.sitterName {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.caption).foregroundColor(.green)
                        Text("Sitter: \(sitterName)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if let note = booking.specialInstructions, !note.isEmpty {
                    Text("Note: \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Quick action buttons for eligible bookings
                if canModifyBooking() {
                    HStack(spacing: 12) {
                        Button("Reschedule") {
                            showRescheduleSheet = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                        
                        Button("Cancel") {
                            showCancelAlert = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showRescheduleSheet) {
            SimpleRescheduleSheet(booking: booking)
        }
        .alert("Cancel Booking", isPresented: $showCancelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm Cancel", role: .destructive) {
                Task {
                    await cancelBooking()
                }
            }
        } message: {
            Text("Are you sure you want to cancel this booking? You may be eligible for a refund based on our cancellation policy.")
        }
    }
    
    private func canModifyBooking() -> Bool {
        let now = Date()
        let hoursUntilVisit = booking.scheduledDate.timeIntervalSince(now) / 3600
        
        // Can modify if booking is pending or approved, and more than 2 hours before visit
        return (booking.status == .pending || booking.status == .approved) && 
               hoursUntilVisit > 2 && 
               booking.scheduledDate > now
    }
    
    private func cancelBooking() async {
        do {
            let result = try await serviceBookings.cancelBooking(bookingId: booking.id, reason: "Cancelled by client")
            AppLogger.ui.info("Booking cancelled: \(result.refundMessage)")
        } catch {
            AppLogger.ui.error("Failed to cancel booking: \(error.localizedDescription)")
        }
    }
}





