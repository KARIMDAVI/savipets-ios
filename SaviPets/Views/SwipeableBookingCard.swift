import SwiftUI
import OSLog

struct SwipeableBookingCard: View {
    let booking: ServiceBooking
    let clientName: String?
    let sitterName: String?
    let onReschedule: (ServiceBooking) -> Void
    let onCancel: (ServiceBooking) -> Void
    let onViewDetails: (ServiceBooking) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var showingActionSheet: Bool = false
    
    // Gesture thresholds
    private let swipeThreshold: CGFloat = 100
    private let maxDragDistance: CGFloat = 150
    
    var body: some View {
        ZStack {
            // Background actions
            HStack {
                // Cancel action (swipe left)
                if dragOffset.width < -swipeThreshold {
                    CancelActionView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                
                Spacer()
                
                // Reschedule action (swipe right)
                if dragOffset.width > swipeThreshold {
                    RescheduleActionView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            
            // Main card content
            BookingCardContent(
                booking: booking,
                clientName: clientName,
                sitterName: sitterName,
                dragOffset: dragOffset,
                isDragging: isDragging
            )
            .offset(dragOffset)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isDragging)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let translation = value.translation
                        
                        // Constrain horizontal movement
                        let constrainedX = max(-maxDragDistance, min(maxDragDistance, translation.width))
                        dragOffset = CGSize(width: constrainedX, height: 0)
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        let translation = value.translation
                        let velocity = value.velocity
                        
                        // Determine if swipe threshold was met
                        if abs(translation.width) > swipeThreshold || abs(velocity.width) > 500 {
                            if translation.width > 0 {
                                // Swipe right - Reschedule action
                                performRescheduleAction()
                            } else {
                                // Swipe left - Cancel action
                                performCancelAction()
                            }
                        } else {
                            // Snap back to center
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture {
                onViewDetails(booking)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Booking Actions"),
                message: Text("Choose an action for this booking"),
                buttons: [
                    .default(Text("Reschedule")) {
                        onReschedule(booking)
                    },
                    .destructive(Text("Cancel Booking")) {
                        onCancel(booking)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func performRescheduleAction() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
        
        // Small delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onReschedule(booking)
        }
    }
    
    private func performCancelAction() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
        
        // Small delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onCancel(booking)
        }
    }
}

// MARK: - Booking Card Content
private struct BookingCardContent: View {
    let booking: ServiceBooking
    let clientName: String?
    let sitterName: String?
    let dragOffset: CGSize
    let isDragging: Bool
    
    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status and time
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.serviceType)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                            Text("at \(booking.scheduledTime)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(status: booking.status)
                        
                        if booking.isRecurring {
                            HStack(spacing: 2) {
                                Image(systemName: "repeat")
                                    .font(.caption2)
                                Text("Recurring")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Client and Sitter info
                if let clientName = clientName {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                        Text("Client: \(clientName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if let sitterName = sitterName {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.green)
                        Text("Sitter: \(sitterName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                // Price and duration
                HStack {
                    Text("$\(booking.price)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(booking.duration) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Swipe hint (only show when not dragging)
                if !isDragging && abs(dragOffset.width) < 10 {
                    HStack {
                        Spacer()
                        Text("Swipe for actions")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(
            // Subtle border that changes color based on swipe direction
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    swipeBorderColor,
                    lineWidth: 2
                )
        )
    }
    
    private var swipeBorderColor: Color {
        if abs(dragOffset.width) < swipeThreshold {
            return Color.clear
        } else if dragOffset.width > 0 {
            return Color.blue.opacity(0.3) // Reschedule (right swipe)
        } else {
            return Color.red.opacity(0.3) // Cancel (left swipe)
        }
    }
    
    private let swipeThreshold: CGFloat = 50
}

// MARK: - Action Views
private struct RescheduleActionView: View {
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Reschedule")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(width: 80, height: 80)
        .background(Color.blue)
        .clipShape(Circle())
        .padding(.trailing, 20)
    }
}

private struct CancelActionView: View {
    var body: some View {
        VStack {
            Image(systemName: "xmark.circle")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Cancel")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(width: 80, height: 80)
        .background(Color.red)
        .clipShape(Circle())
        .padding(.leading, 20)
    }
}

// MARK: - Preview
#Preview {
    SwipeableBookingCard(
        booking: ServiceBooking(
            id: "preview-booking",
            clientId: "client123",
            serviceType: "Dog Walking",
            scheduledDate: Date(),
            scheduledTime: "2:00 PM",
            duration: 30,
            pets: ["Buddy"],
            specialInstructions: "Walk in the park",
            status: .approved,
            sitterId: "sitter123",
            sitterName: "John Doe",
            createdAt: Date(),
            address: "123 Main St",
            checkIn: nil,
            checkOut: nil,
            price: "25.00",
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: .confirmed,
            paymentTransactionId: "txn123",
            paymentAmount: 25.0,
            paymentMethod: "Credit Card",
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: nil,
            lastModifiedBy: nil,
            modificationReason: nil
        ),
        clientName: "Jane Smith",
        sitterName: "John Doe",
        onReschedule: { _ in },
        onCancel: { _ in },
        onViewDetails: { _ in }
    )
    .padding()
}
