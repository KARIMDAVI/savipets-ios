import Foundation
import FirebaseFirestore
import OSLog
import Combine
import CoreLocation

/// Payment Confirmation Service
/// Handles payment confirmation logic and triggers appropriate assignment method
/// - Payment Confirmed: Triggers AI Sitter Assignment
/// - Payment Declined/Issues: Triggers Admin Approval System
final class PaymentConfirmationService: ObservableObject {
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastConfirmationResult: PaymentConfirmationResult?
    
    private let db = Firestore.firestore()
    private let aiAssignmentService = AISitterAssignmentService()
    
    // MARK: - Payment Confirmation Result
    struct PaymentConfirmationResult {
        let bookingId: String
        let paymentStatus: PaymentStatus
        let assignmentTriggered: AssignmentTrigger
        let timestamp: Date
        let message: String
        
        
        enum AssignmentTrigger {
            case aiAssignment
            case adminApproval
            case none
        }
    }
    
    // MARK: - Payment Confirmation
    /// Confirms payment status and triggers appropriate assignment method
    func confirmPayment(for bookingId: String, paymentStatus: PaymentStatus, paymentDetails: PaymentDetails) async -> PaymentConfirmationResult {
        await MainActor.run { isProcessing = true }
        
        defer {
            Task { @MainActor in isProcessing = false }
        }
        
        do {
            // Update booking with payment status
            try await updateBookingPaymentStatus(
                bookingId: bookingId,
                paymentStatus: paymentStatus,
                paymentDetails: paymentDetails
            )
            
            let assignmentTrigger: PaymentConfirmationResult.AssignmentTrigger
            let message: String
            
            switch paymentStatus {
            case .confirmed:
                // Payment confirmed - trigger AI assignment
                assignmentTrigger = await triggerAIAssignment(for: bookingId)
                message = "Payment confirmed. AI assignment triggered."
                
            case .declined, .failed:
                // Payment issues - trigger admin approval
                assignmentTrigger = await triggerAdminApproval(for: bookingId)
                message = "Payment \(paymentStatus.rawValue). Manual admin approval required."
                
            case .pending:
                // Payment pending - no assignment yet
                assignmentTrigger = .none
                message = "Payment pending. Waiting for confirmation."
            }
            
            let result = PaymentConfirmationResult(
                bookingId: bookingId,
                paymentStatus: paymentStatus,
                assignmentTriggered: assignmentTrigger,
                timestamp: Date(),
                message: message
            )
            
            await MainActor.run { lastConfirmationResult = result }
            
            // Log payment confirmation for analytics
            try await logPaymentConfirmation(result: result, paymentDetails: paymentDetails)
            
            return result
            
        } catch {
            AppLogger.ui.error("Payment confirmation failed for booking \(bookingId): \(error.localizedDescription)")
            
            let errorResult = PaymentConfirmationResult(
                bookingId: bookingId,
                paymentStatus: .failed,
                assignmentTriggered: .adminApproval,
                timestamp: Date(),
                message: "Payment confirmation failed: \(error.localizedDescription)"
            )
            
            await MainActor.run { lastConfirmationResult = errorResult }
            return errorResult
        }
    }
    
    // MARK: - Update Booking Payment Status
    private func updateBookingPaymentStatus(
        bookingId: String,
        paymentStatus: PaymentStatus,
        paymentDetails: PaymentDetails
    ) async throws {
        var updateData: [String: Any] = [
            "paymentStatus": paymentStatus.rawValue,
            "paymentConfirmedAt": paymentStatus == .confirmed ? FieldValue.serverTimestamp() : FieldValue.delete(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        // Add payment details if provided
        if let transactionId = paymentDetails.transactionId {
            updateData["paymentTransactionId"] = transactionId
        }
        
        if let amount = paymentDetails.amount {
            updateData["paymentAmount"] = amount
        }
        
        if let method = paymentDetails.paymentMethod {
            updateData["paymentMethod"] = method
        }
        
        try await db.collection("serviceBookings").document(bookingId).setData(updateData, merge: true)
    }
    
    // MARK: - Trigger AI Assignment
    private func triggerAIAssignment(for bookingId: String) async -> PaymentConfirmationResult.AssignmentTrigger {
        do {
            // Fetch booking details
            let bookingDoc = try await db.collection("serviceBookings").document(bookingId).getDocument()
            
            guard let bookingData = bookingDoc.data() else {
                AppLogger.ui.error("Booking not found for AI assignment: \(bookingId)")
                return .adminApproval // Fallback to admin approval
            }
            
            // Create assignment criteria
            let criteria = createAssignmentCriteria(from: bookingData, bookingId: bookingId)
            
            // Trigger AI assignment
            let assignmentResult = await aiAssignmentService.assignBestSitter(for: criteria)
            
            if assignmentResult.assignmentMethod != .failed {
                AppLogger.ui.info("AI assignment successful for booking \(bookingId)")
                return .aiAssignment
            } else {
                AppLogger.ui.warning("AI assignment failed for booking \(bookingId), falling back to admin approval")
                return .adminApproval
            }
            
        } catch {
            AppLogger.ui.error("Failed to trigger AI assignment for booking \(bookingId): \(error.localizedDescription)")
            return .adminApproval
        }
    }
    
    // MARK: - Trigger Admin Approval
    private func triggerAdminApproval(for bookingId: String) async -> PaymentConfirmationResult.AssignmentTrigger {
        do {
            // Update booking status to require admin approval
            try await db.collection("serviceBookings").document(bookingId).setData([
                "status": "pendingAdminApproval",
                "requiresAdminApproval": true,
                "approvalReason": "Payment issue requires manual review",
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Create admin notification
            try await createAdminNotification(for: bookingId, reason: "Payment issue requires manual review")
            
            AppLogger.ui.info("Admin approval triggered for booking \(bookingId)")
            return .adminApproval
            
        } catch {
            AppLogger.ui.error("Failed to trigger admin approval for booking \(bookingId): \(error.localizedDescription)")
            return .none
        }
    }
    
    // MARK: - Create Assignment Criteria
    private func createAssignmentCriteria(from bookingData: [String: Any], bookingId: String) -> AISitterAssignmentService.AssignmentCriteria {
        let clientId = bookingData["clientId"] as? String ?? ""
        let serviceType = bookingData["serviceType"] as? String ?? ""
        let scheduledDate = (bookingData["scheduledDate"] as? Timestamp)?.dateValue() ?? Date()
        let duration = bookingData["duration"] as? Int ?? 60
        let pets = bookingData["pets"] as? [String] ?? []
        let specialInstructions = bookingData["specialInstructions"] as? String ?? ""
        let preferredSitterId = bookingData["preferredSitterId"] as? String
        
        // Parse location if available
        var location: CLLocation?
        if let lat = bookingData["latitude"] as? Double,
           let lng = bookingData["longitude"] as? Double {
            location = CLLocation(latitude: lat, longitude: lng)
        }
        
        // Parse special requirements
        let specialRequirements = specialInstructions.isEmpty ? [] : [specialInstructions]
        
        return AISitterAssignmentService.AssignmentCriteria(
            bookingId: bookingId,
            clientId: clientId,
            bookingLocation: location,
            petTypes: pets,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            duration: duration,
            specialRequirements: specialRequirements,
            preferredSitterId: preferredSitterId
        )
    }
    
    // MARK: - Create Admin Notification
    private func createAdminNotification(for bookingId: String, reason: String) async throws {
        let notificationData: [String: Any] = [
            "type": "bookingApprovalRequired",
            "bookingId": bookingId,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "unread",
            "priority": "high"
        ]
        
        try await db.collection("adminNotifications").addDocument(data: notificationData)
    }
    
    // MARK: - Log Payment Confirmation
    private func logPaymentConfirmation(
        result: PaymentConfirmationResult,
        paymentDetails: PaymentDetails
    ) async throws {
        let logData: [String: Any] = [
            "bookingId": result.bookingId,
            "paymentStatus": result.paymentStatus.rawValue,
            "assignmentTriggered": result.assignmentTriggered.rawValue,
            "timestamp": result.timestamp,
            "transactionId": paymentDetails.transactionId ?? "",
            "amount": paymentDetails.amount ?? 0,
            "paymentMethod": paymentDetails.paymentMethod ?? ""
        ]
        
        try await db.collection("paymentConfirmations").addDocument(data: logData)
    }
    
    // MARK: - Handle Payment Webhook (for external payment processors)
    func handlePaymentWebhook(webhookData: [String: Any]) async -> PaymentConfirmationResult? {
        guard let bookingId = webhookData["bookingId"] as? String else {
            AppLogger.ui.error("Payment webhook missing bookingId")
            return nil
        }
        
                guard let paymentStatusString = webhookData["paymentStatus"] as? String,
                      let paymentStatus = PaymentStatus(rawValue: paymentStatusString) else {
            AppLogger.ui.error("Payment webhook missing or invalid paymentStatus")
            return nil
        }
        
        let paymentDetails = PaymentDetails(
            transactionId: webhookData["transactionId"] as? String,
            amount: webhookData["amount"] as? Double,
            paymentMethod: webhookData["paymentMethod"] as? String
        )
        
        return await confirmPayment(
            for: bookingId,
            paymentStatus: paymentStatus,
            paymentDetails: paymentDetails
        )
    }
    
    // MARK: - Retry Failed Assignment
    func retryAssignment(for bookingId: String) async -> PaymentConfirmationResult {
        do {
            // Check if payment is confirmed
            let bookingDoc = try await db.collection("serviceBookings").document(bookingId).getDocument()
            
            guard let bookingData = bookingDoc.data(),
                  let paymentStatusString = bookingData["paymentStatus"] as? String,
                  let paymentStatus = PaymentStatus(rawValue: paymentStatusString) else {
                throw NSError(domain: "PaymentConfirmation", code: 404, userInfo: [NSLocalizedDescriptionKey: "Booking not found"])
            }
            
            if paymentStatus == .confirmed {
                // Retry AI assignment
                let assignmentTrigger = await triggerAIAssignment(for: bookingId)
                
                let result = PaymentConfirmationResult(
                    bookingId: bookingId,
                    paymentStatus: paymentStatus,
                    assignmentTriggered: assignmentTrigger,
                    timestamp: Date(),
                    message: "Assignment retry completed"
                )
                
                await MainActor.run { lastConfirmationResult = result }
                return result
            } else {
                throw NSError(domain: "PaymentConfirmation", code: 400, userInfo: [NSLocalizedDescriptionKey: "Payment not confirmed, cannot retry assignment"])
            }
            
        } catch {
            AppLogger.ui.error("Failed to retry assignment for booking \(bookingId): \(error.localizedDescription)")
            
            let errorResult = PaymentConfirmationResult(
                bookingId: bookingId,
                paymentStatus: .failed,
                assignmentTriggered: .adminApproval,
                timestamp: Date(),
                message: "Assignment retry failed: \(error.localizedDescription)"
            )
            
            await MainActor.run { lastConfirmationResult = errorResult }
            return errorResult
        }
    }
}

// MARK: - Supporting Types
struct PaymentDetails {
    let transactionId: String?
    let amount: Double?
    let paymentMethod: String?
}

// MARK: - Extensions
extension PaymentStatus {
    var rawValue: String {
        switch self {
        case .confirmed: return "confirmed"
        case .declined: return "declined"
        case .failed: return "failed"
        case .pending: return "pending"
        }
    }
}

extension PaymentConfirmationService.PaymentConfirmationResult.AssignmentTrigger {
    var rawValue: String {
        switch self {
        case .aiAssignment: return "aiAssignment"
        case .adminApproval: return "adminApproval"
        case .none: return "none"
        }
    }
}
