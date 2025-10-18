import Foundation
import FirebaseAuth

struct ErrorMapper {
    static func userFriendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == AuthErrorDomain {
            if let authErrorCode = AuthErrorCode(_bridgedNSError: nsError) {
                switch authErrorCode.code {
                case .networkError:
                    return "Network connection failed. Please check your internet."
                case .userNotFound:
                    return "No account found with this email."
                case .wrongPassword:
                    return "Incorrect password. Please try again."
                case .invalidEmail:
                    return "Please enter a valid email address."
                case .emailAlreadyInUse:
                    return "This email is already registered."
                case .weakPassword:
                    return "Password is too weak. Please use a stronger password."
                case .tooManyRequests:
                    return "Too many attempts. Please try again later."
                default:
                    break
                }
            }
        }
        
        return error.localizedDescription
    }
}
