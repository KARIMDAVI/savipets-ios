import Foundation
import OSLog
import Combine
import FirebaseFirestore

struct SitterProfile: Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let specialties: [String]
    let rating: Double
    let totalVisits: Int
    let isActive: Bool
    let profileImage: String?
}

@MainActor
final class SitterDataService: ObservableObject {
    @Published var availableSitters: [SitterProfile] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func listenToActiveSitters() {
        isLoading = true
        error = nil
        
        // Source of truth: users collection with role == "petSitter"
        listener = db.collection("users")
            .whereField("role", isEqualTo: SPDesignSystem.Roles.petSitter)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error
                        AppLogger.data.error("Error fetching sitters: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.availableSitters = documents.map { doc in
                        let data = doc.data()
                        return SitterProfile(
                            id: doc.documentID,
                            name: self.extractName(from: data),
                            email: data["email"] as? String ?? "",
                            phone: data["phone"] as? String,
                            specialties: data["specialties"] as? [String] ?? [],
                            rating: data["rating"] as? Double ?? 0.0,
                            totalVisits: data["totalVisits"] as? Int ?? 0,
                            isActive: data["isActive"] as? Bool ?? true,
                            profileImage: data["photoURL"] as? String
                        )
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    private func extractName(from data: [String: Any]) -> String {
        if let displayName = data["displayName"] as? String {
            return displayName
        }
        
        if let name = data["name"] as? String {
            return name
        }
        
        if let email = data["email"] as? String,
           let username = email.components(separatedBy: "@").first {
            return username
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
        
        return "Sitter"
    }
    
    deinit {
        listener?.remove()
    }
}





