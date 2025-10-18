import Foundation
import FirebaseFunctions
import OSLog

/**
 * Square Payment Service
 * 
 * Handles all Square payment operations:
 * - Creating dynamic checkout links
 * - Processing refunds
 * - Managing subscriptions
 */
final class SquarePaymentService {
    private let functions = Functions.functions()
    
    // MARK: - Checkout Creation
    
    /// Create Square checkout link for a booking
    func createCheckout(
        bookingId: String,
        serviceType: String,
        price: Double,
        numberOfVisits: Int = 1,
        isRecurring: Bool = false,
        frequency: String = "once",
        pets: [String] = [],
        scheduledDate: Date? = nil
    ) async throws -> String {
        
        let dateFormatter = ISO8601DateFormatter()
        let scheduledDateString = scheduledDate != nil ? dateFormatter.string(from: scheduledDate!) : ""
        
        let data: [String: Any] = [
            "bookingId": bookingId,
            "serviceType": serviceType,
            "price": price,
            "numberOfVisits": numberOfVisits,
            "isRecurring": isRecurring,
            "frequency": frequency,
            "pets": pets,
            "scheduledDate": scheduledDateString
        ]
        
        AppLogger.data.info("Creating Square checkout for booking: \(bookingId)")
        AppLogger.data.info("Square checkout data: \(data)")
        
        do {
            let result = try await functions.httpsCallable("createSquareCheckout").call(data)
            
            AppLogger.data.info("Square checkout response: \(result.data as? NSObject)")
            
            guard let response = result.data as? [String: Any],
                  let success = response["success"] as? Bool,
                  success,
                  let checkoutUrl = response["checkoutUrl"] as? String else {
                AppLogger.data.error("Invalid Square checkout response: \(result.data as? NSObject)")
                throw SquarePaymentError.invalidResponse
            }
            
            AppLogger.data.info("✅ Square checkout created successfully: \(checkoutUrl)")
            
            return checkoutUrl
            
        } catch {
            AppLogger.data.error("❌ Failed to create Square checkout: \(error.localizedDescription)")
            AppLogger.data.error("❌ Error details: \(error)")
            throw SquarePaymentError.checkoutCreationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Refund Processing
    
    /// Process refund via Square API (called when booking canceled)
    func processRefund(
        bookingId: String,
        refundAmount: Double,
        reason: String = ""
    ) async throws {
        
        let data: [String: Any] = [
            "bookingId": bookingId,
            "refundAmount": refundAmount,
            "reason": reason.isEmpty ? "Booking canceled" : reason
        ]
        
        AppLogger.data.info("Processing Square refund for booking: \(bookingId), amount: \(refundAmount)")
        
        do {
            let result = try await functions.httpsCallable("processSquareRefund").call(data)
            
            guard let response = result.data as? [String: Any],
                  let success = response["success"] as? Bool,
                  success else {
                throw SquarePaymentError.refundFailed("Refund request failed")
            }
            
            AppLogger.data.info("Square refund processed successfully")
            
        } catch {
            AppLogger.data.error("Failed to process refund: \(error.localizedDescription)")
            throw SquarePaymentError.refundFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Subscription Management
    
    /// Create Square subscription for recurring bookings
    func createSubscription(
        seriesId: String,
        planId: String,
        customerId: String,
        cardId: String,
        startDate: Date
    ) async throws -> String {
        
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: startDate)
        
        let data: [String: Any] = [
            "seriesId": seriesId,
            "planId": planId,
            "customerId": customerId,
            "cardId": cardId,
            "startDate": startDateString
        ]
        
        AppLogger.data.info("Creating Square subscription for series: \(seriesId)")
        
        do {
            let result = try await functions.httpsCallable("createSquareSubscription").call(data)
            
            guard let response = result.data as? [String: Any],
                  let success = response["success"] as? Bool,
                  success,
                  let subscriptionId = response["subscriptionId"] as? String else {
                throw SquarePaymentError.subscriptionFailed("Failed to create subscription")
            }
            
            AppLogger.data.info("Square subscription created: \(subscriptionId)")
            
            return subscriptionId
            
        } catch {
            AppLogger.data.error("Failed to create subscription: \(error.localizedDescription)")
            throw SquarePaymentError.subscriptionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum SquarePaymentError: LocalizedError {
    case invalidResponse
    case checkoutCreationFailed(String)
    case refundFailed(String)
    case subscriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from payment service"
        case .checkoutCreationFailed(let message):
            return "Failed to create checkout: \(message)"
        case .refundFailed(let message):
            return "Refund failed: \(message)"
        case .subscriptionFailed(let message):
            return "Subscription creation failed: \(message)"
        }
    }
}

