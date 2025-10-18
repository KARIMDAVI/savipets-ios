import SwiftUI

struct StatusBadge: View {
    let status: ServiceBooking.BookingStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .pending)
        StatusBadge(status: .approved)
        StatusBadge(status: .inAdventure)
        StatusBadge(status: .completed)
        StatusBadge(status: .cancelled)
    }
    .padding()
}
